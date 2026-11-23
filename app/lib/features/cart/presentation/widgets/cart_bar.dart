import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/money.dart';
import '../cart_controller.dart';

/// Sticky bottom bar on browsing screens while the cart has items.
class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    if (cart.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Material(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: const Key('cartBar'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push(Routes.cart),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.shopping_basket_outlined, color: scheme.onPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // a bottom bar gets the whole screen height as its limit
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.cartItems(cart.itemCount), style: TextStyle(color: scheme.onPrimary)),
                        Text(
                          formatPaise(cart.estimatedTotalPaise),
                          style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Text(l10n.viewCart, style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.bold)),
                  Icon(Icons.chevron_right, color: scheme.onPrimary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
