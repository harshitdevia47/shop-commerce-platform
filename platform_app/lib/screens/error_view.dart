import 'package:material_ui/material_ui.dart';

import '../api/admin_api.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48),
          const SizedBox(height: 12),
          Text(error is ApiError ? (error as ApiError).display : 'Something went wrong. Try again.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(key: const Key('retryButton'), onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ],
      ),
    ),
  );
}
