import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';

/// RIDER landing page. Assigned deliveries and live tracking arrive in Phase 5.
class RiderHomeScreen extends ConsumerWidget {
  const RiderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.riderTitle),
        actions: [
          IconButton(
            tooltip: l10n.account,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(Routes.account),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.riderComingSoon, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
