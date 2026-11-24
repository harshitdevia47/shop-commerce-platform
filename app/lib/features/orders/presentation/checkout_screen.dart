import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/shop_settings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/ids.dart';
import '../../../core/utils/money.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../cart/presentation/cart_quote.dart';
import '../../private_media/presentation/private_media.dart';
import '../domain/order_models.dart';
import 'address_sheet.dart';
import 'orders_providers.dart';
import 'widgets/bill_summary.dart';
import 'widgets/slot_picker.dart';

/// Address, delivery time, photos, payment method, note, place order.
///
/// [listMode]: order with a photo of a handwritten list / prescription instead of the cart;
/// the shop sets the amount when it accepts the order.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({this.listMode = false, super.key});

  final bool listMode;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  /// Same key for every retry of this checkout: a timed-out request that actually
  /// succeeded is returned instead of creating a second order.
  final _idempotencyKey = uuidV4();
  final _note = TextEditingController();
  String? _addressId;
  PaymentMethod? _method;
  DateTime? _slotStart;
  List<PickedAttachment> _lists = const [];
  List<PickedAttachment> _prescriptions = const [];
  bool _placing = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _addAddress() async {
    final address = await AddressSheet.show(context);
    if (address != null) setState(() => _addressId = address.id);
  }

  Future<void> _place(Quote? quote, Fulfillment fulfillment, PaymentMethod method, String? addressId, bool useSlots) async {
    setState(() => _placing = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final (order, _) = await ref.read(ordersRepositoryProvider).place(
        PlaceOrderRequest(
          items: widget.listMode ? const [] : ref.read(cartProvider).toRequestItems(),
          fulfillment: fulfillment,
          paymentMethod: method,
          idempotencyKey: _idempotencyKey,
          addressId: fulfillment == Fulfillment.delivery ? addressId : null,
          note: _note.text.trim(),
          expectedTotalPaise: quote?.totalPaise,
          slotStart: useSlots ? _slotStart : null,
          attachmentIds: [for (final p in [..._lists, ..._prescriptions]) p.attachment.id],
        ),
      );
      if (!widget.listMode) ref.read(cartProvider.notifier).clear();
      ref.invalidate(myOrdersProvider);
      if (!mounted) return;
      // Home underneath, so back from the order goes to the shop, not to an empty checkout.
      context.go(Routes.home);
      unawaited(context.push('${Routes.order(order.id)}?placed=1'));
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
      if (error.code.startsWith('SLOT_')) {
        ref.invalidate(deliverySlotsProvider);
        setState(() => _slotStart = null);
      }
      if (const {'CART_CHANGED', 'PRICE_CHANGED', 'OUT_OF_STOCK', 'BELOW_MINIMUM_ORDER'}.contains(error.code)) {
        ref.invalidate(cartQuoteProvider);
        if (mounted) context.pop(); // back to the cart, which shows what changed
      }
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);
    final settings = ref.watch(shopSettingsProvider).value;
    final fulfillment = ref.watch(fulfillmentProvider);
    final listMode = widget.listMode;
    final quote = listMode ? null : ref.watch(cartQuoteProvider).value;
    final isDelivery = fulfillment == Fulfillment.delivery;
    final useSlots = isDelivery && (settings?.isEnabled(Feature.deliverySlots) ?? false);
    final slots = useSlots ? ref.watch(deliverySlotsProvider) : null;
    final takesLists = settings?.isEnabled(Feature.handwrittenListUpload) ?? false;
    final takesPrescriptions = settings?.isEnabled(Feature.prescriptionUpload) ?? false;
    final photos = _lists.length + _prescriptions.length;
    final addresses = isDelivery ? ref.watch(addressesProvider) : null;

    final methods = [
      if (settings?.payments.cod ?? true) PaymentMethod.cod,
      if (settings?.payments.upiEnabled ?? false) PaymentMethod.upi,
    ];
    final method = _method ?? methods.firstOrNull;
    final addressList = addresses?.value ?? const <Address>[];
    final addressId = _addressId ?? addressList.where((a) => a.isDefault).firstOrNull?.id ?? addressList.firstOrNull?.id;
    final ready =
        (listMode ? photos > 0 : quote != null && quote.canPlace) &&
        method != null &&
        (!isDelivery || addressId != null) &&
        (!useSlots || _slotStart != null) &&
        !_placing;

    return Scaffold(
      appBar: AppBar(title: Text(listMode ? l10n.listOrderTitle : l10n.checkoutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (listMode) ...[
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: ListTile(leading: const Icon(Icons.receipt_long_outlined), title: Text(l10n.listOrderHint)),
            ),
            const SizedBox(height: 8),
          ],
          if (listMode && (settings?.delivery.enabled ?? false) && (settings?.isEnabled(Feature.storePickup) ?? false)) ...[
            SegmentedButton<Fulfillment>(
              segments: [
                ButtonSegment(value: Fulfillment.delivery, label: Text(l10n.deliveryOption), icon: const Icon(Icons.delivery_dining_outlined)),
                ButtonSegment(value: Fulfillment.pickup, label: Text(l10n.pickupOption), icon: const Icon(Icons.storefront_outlined)),
              ],
              selected: {fulfillment},
              onSelectionChanged: (s) => ref.read(fulfillmentProvider.notifier).set(s.first),
            ),
            const SizedBox(height: 12),
          ],
          if (listMode && takesLists) ...[
            AttachmentField(
              key: const Key('listPhotos'),
              kind: AttachmentKind.handwrittenList,
              label: l10n.listPhotoLabel,
              value: _lists,
              onChanged: (v) => setState(() => _lists = v),
            ),
            const SizedBox(height: 16),
          ],
          if (takesPrescriptions) ...[
            AttachmentField(
              key: const Key('prescriptionPhotos'),
              kind: AttachmentKind.prescription,
              label: l10n.prescriptionLabel,
              value: _prescriptions,
              onChanged: (v) => setState(() => _prescriptions = v),
            ),
            const SizedBox(height: 16),
          ],
          Text(isDelivery ? l10n.deliverTo : l10n.pickupFrom, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (!isDelivery)
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(settings?.shop.localizedName(locale) ?? ''),
                subtitle: Text(settings?.shop.address ?? ''),
              ),
            )
          else if (addresses!.isLoading && !addresses.hasValue)
            const Center(child: CircularProgressIndicator())
          else
            Card(
              child: RadioGroup<String>(
                groupValue: addressId,
                onChanged: (id) => setState(() => _addressId = id),
                child: Column(
                  children: [
                    if (addressList.isEmpty)
                      ListTile(leading: const Icon(Icons.location_off_outlined), title: Text(l10n.noAddresses)),
                    for (final address in addressList)
                      RadioListTile<String>(
                        key: ValueKey('address-${address.id}'),
                        value: address.id,
                        title: Text(switch (address.label) {
                          'work' => l10n.addressWork,
                          'other' => l10n.addressOther,
                          _ => l10n.addressHome,
                        }),
                        subtitle: Text(address.summary),
                      ),
                    ListTile(
                      key: const Key('addAddressButton'),
                      leading: const Icon(Icons.add_location_alt_outlined),
                      title: Text(l10n.addAddress),
                      onTap: _addAddress,
                    ),
                  ],
                ),
              ),
            ),
          if (slots != null) ...[
            const SizedBox(height: 16),
            Text(l10n.deliveryTimeTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: switch (slots) {
                AsyncValue(:final value?) => SlotPicker(
                  slots: value,
                  selected: _slotStart,
                  onSelected: (start) => setState(() => _slotStart = start),
                ),
                AsyncValue(:final error?) => ListTile(
                  title: Text(errorMessage(l10n, error)),
                  trailing: TextButton(onPressed: () => ref.invalidate(deliverySlotsProvider), child: Text(l10n.retry)),
                ),
                _ => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              },
            ),
          ],
          const SizedBox(height: 16),
          Text(l10n.paymentMethodTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: RadioGroup<PaymentMethod>(
              groupValue: method,
              onChanged: (m) => setState(() => _method = m),
              child: Column(
                children: [
                  for (final m in methods)
                    RadioListTile<PaymentMethod>(
                      key: ValueKey('method-${m.wire}'),
                      value: m,
                      secondary: Icon(m == PaymentMethod.cod ? Icons.payments_outlined : Icons.qr_code_2),
                      title: Text(m == PaymentMethod.cod ? l10n.paymentCod : l10n.paymentUpi),
                    ),
                ],
              ),
            ),
          ),
          if (settings?.isEnabled(Feature.orderNotes) ?? false) ...[
            const SizedBox(height: 16),
            TextField(
              key: const Key('noteField'),
              controller: _note,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(labelText: l10n.noteLabel, border: const OutlineInputBorder()),
            ),
          ],
          const SizedBox(height: 8),
          if (quote != null)
            BillSummary(
              subtotalPaise: quote.subtotalPaise,
              deliveryFeePaise: quote.deliveryFeePaise,
              totalPaise: quote.totalPaise,
              savingsPaise: quote.savingsPaise,
              showDelivery: isDelivery,
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            key: const Key('placeOrderButton'),
            onPressed: ready ? () => _place(quote, fulfillment, method, addressId, useSlots) : null,
            child: _placing
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(listMode ? l10n.sendListOrder : l10n.placeOrder(formatPaise(quote?.totalPaise ?? 0))),
          ),
        ),
      ),
    );
  }
}
