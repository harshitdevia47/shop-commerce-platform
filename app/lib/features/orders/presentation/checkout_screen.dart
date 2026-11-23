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
import '../domain/order_models.dart';
import 'address_sheet.dart';
import 'orders_providers.dart';
import 'widgets/bill_summary.dart';

/// Address, payment method, note, place order.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

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

  Future<void> _place(Quote quote, Fulfillment fulfillment, PaymentMethod method, String? addressId) async {
    setState(() => _placing = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final (order, _) = await ref.read(ordersRepositoryProvider).place(
        PlaceOrderRequest(
          items: ref.read(cartProvider).toRequestItems(),
          fulfillment: fulfillment,
          paymentMethod: method,
          idempotencyKey: _idempotencyKey,
          addressId: fulfillment == Fulfillment.delivery ? addressId : null,
          note: _note.text.trim(),
          expectedTotalPaise: quote.totalPaise,
        ),
      );
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(myOrdersProvider);
      if (!mounted) return;
      // Home underneath, so back from the order goes to the shop, not to an empty checkout.
      context.go(Routes.home);
      unawaited(context.push('${Routes.order(order.id)}?placed=1'));
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
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
    final quote = ref.watch(cartQuoteProvider).value;
    final isDelivery = fulfillment == Fulfillment.delivery;
    final addresses = isDelivery ? ref.watch(addressesProvider) : null;

    final methods = [
      if (settings?.payments.cod ?? true) PaymentMethod.cod,
      if (settings?.payments.upiEnabled ?? false) PaymentMethod.upi,
    ];
    final method = _method ?? methods.firstOrNull;
    final addressList = addresses?.value ?? const <Address>[];
    final addressId = _addressId ?? addressList.where((a) => a.isDefault).firstOrNull?.id ?? addressList.firstOrNull?.id;
    final ready = quote != null && quote.canPlace && method != null && (!isDelivery || addressId != null) && !_placing;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkoutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
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
            onPressed: ready ? () => _place(quote, fulfillment, method, addressId) : null,
            child: _placing
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.placeOrder(formatPaise(quote?.totalPaise ?? 0))),
          ),
        ),
      ),
    );
  }
}
