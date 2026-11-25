import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/legal_links.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/language_menu.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';

/// Profile: name, language, logout, and (customers) account deletion. Shared by every role.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  late final TextEditingController _name;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(authControllerProvider).value?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(name: name);
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final error = Theme.of(context).colorScheme.error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAccountTitle),
        content: Text(l10n.deleteAccountBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            key: const Key('confirmDeleteAccount'),
            style: TextButton.styleFrom(foregroundColor: error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteAccountConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAccountDone)));
    } on Object catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, e)), duration: const Duration(seconds: 6)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink(); // router redirects to login
    return Scaffold(
      appBar: AppBar(title: Text(l10n.account), actions: const [LanguageMenu()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(user.phone),
            subtitle: Text(user.role.label(l10n)),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('nameField'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 60,
            decoration: InputDecoration(labelText: l10n.nameLabel, border: const OutlineInputBorder()),
          ),
          FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.save)),
          if (user.role == UserRole.customer) ...[
            const SizedBox(height: 16),
            ListTile(
              key: const Key('accountOrdersTile'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l10n.ordersTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.orders),
            ),
          ],
          const SizedBox(height: 32),
          OutlinedButton.icon(
            key: const Key('logoutButton'),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: Text(l10n.logout),
          ),
          const SizedBox(height: 16),
          const LegalLinks(),
          if (user.role == UserRole.customer) ...[
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                key: const Key('deleteAccountButton'),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: _saving ? null : _deleteAccount,
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.deleteAccount),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
