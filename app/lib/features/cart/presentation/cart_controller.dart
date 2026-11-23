import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../catalog/domain/catalog_models.dart';
import '../data/cart_store.dart';
import '../domain/cart.dart';

final cartStoreProvider = Provider<CartStore>((ref) => CartStore(ref.watch(sharedPreferencesProvider)));

/// The cart. Updates are synchronous (instant UI) and saved in the background.
class CartController extends Notifier<Cart> {
  @override
  Cart build() => ref.watch(cartStoreProvider).read();

  void _set(Cart cart) {
    state = cart;
    ref.read(cartStoreProvider).write(cart);
  }

  void add(Product product, Variant variant) {
    final current = state.qtyOf(variant.id);
    if (current == 0) {
      _set(Cart([...state.lines, CartLine.of(product, variant, 1)]));
    } else {
      setQty(variant.id, current + 1);
    }
  }

  void increment(String variantId) => setQty(variantId, state.qtyOf(variantId) + 1);
  void decrement(String variantId) => setQty(variantId, state.qtyOf(variantId) - 1);

  /// 0 removes the line; values above [Cart.maxQty] are capped.
  void setQty(String variantId, int qty) {
    final capped = qty.clamp(0, Cart.maxQty);
    _set(
      Cart([
        for (final line in state.lines)
          if (line.variantId != variantId) line else if (capped > 0) line.withQty(capped),
      ]),
    );
  }

  void clear() => _set(const Cart());
}

final cartProvider = NotifierProvider<CartController, Cart>(CartController.new);
