import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../cart/presentation/widgets/cart_bar.dart';
import 'catalog_providers.dart';
import 'widgets/product_grid.dart';

/// Instant search: queries the server 300 ms after the user stops typing.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  static const debounce = Duration(milliseconds: 300);
  static const minLength = 2;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(SearchScreen.debounce, () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = _query.length >= SearchScreen.minLength;
    return Scaffold(
      bottomNavigationBar: const CartBar(),
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          key: const Key('searchField'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (value) {
            _debounce?.cancel();
            setState(() => _query = value.trim());
          },
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          cursorColor: Theme.of(context).colorScheme.onPrimary,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: ready
          ? CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ProductGridSliver(ProductFilter(query: _query)),
              ],
            )
          : Center(
              child: Padding(padding: const EdgeInsets.all(32), child: Text(l10n.searchPrompt, textAlign: TextAlign.center)),
            ),
    );
  }
}
