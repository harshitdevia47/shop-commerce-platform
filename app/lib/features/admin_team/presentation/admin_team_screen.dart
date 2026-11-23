import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/error_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../delivery/domain/delivery_models.dart';
import '../../delivery/presentation/delivery_providers.dart';

String roleLabel(AppLocalizations l10n, String role) => switch (role) {
  'OWNER' => l10n.roleOwner,
  'RIDER' => l10n.roleRider,
  _ => l10n.roleStaff,
};

/// Owner only: riders and staff. Adding a phone number lets that person log in with OTP
/// into the rider or shop area; removing makes them a normal customer again.
class AdminTeamScreen extends ConsumerWidget {
  const AdminTeamScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final input = await showDialog<_NewMember>(context: context, builder: (_) => const _AddMemberDialog());
    if (input == null || !context.mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(teamRepositoryProvider).add(phone: input.phone, role: input.role, name: input.name);
      messenger.showSnackBar(SnackBar(content: Text(l10n.teamAdded)));
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
    }
    ref
      ..invalidate(teamProvider)
      ..invalidate(ridersProvider);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, TeamMember member) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.teamRemoveConfirm(member.name ?? member.phone)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(key: const Key('confirmRemoveButton'), onPressed: () => Navigator.pop(context, true), child: Text(l10n.teamRemove)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(teamRepositoryProvider).remove(member.id);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, error))));
    }
    ref
      ..invalidate(teamProvider)
      ..invalidate(ridersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final team = ref.watch(teamProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminTeam)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addMemberButton'),
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.person_add_alt_outlined),
        label: Text(l10n.teamAdd),
      ),
      body: switch (team) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(teamProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              if (value.every((m) => m.role == 'OWNER'))
                Padding(padding: const EdgeInsets.all(24), child: Text(l10n.teamEmpty, textAlign: TextAlign.center)),
              for (final member in value)
                Card(
                  child: ListTile(
                    key: ValueKey('member-${member.id}'),
                    leading: Icon(member.role == 'RIDER' ? Icons.two_wheeler_outlined : Icons.badge_outlined),
                    title: Text(member.name ?? member.phone),
                    subtitle: Text([if (member.name != null) member.phone, roleLabel(l10n, member.role)].join(' · ')),
                    trailing: member.role == 'OWNER'
                        ? null
                        : IconButton(
                            tooltip: l10n.teamRemove,
                            icon: const Icon(Icons.person_remove_outlined),
                            onPressed: () => _remove(context, ref, member),
                          ),
                  ),
                ),
            ],
          ),
        ),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(teamProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _NewMember {
  const _NewMember(this.phone, this.role, this.name);
  final String phone;
  final String role;
  final String? name;
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _phone = TextEditingController();
  final _name = TextEditingController();
  String _role = 'RIDER';

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _phone.text.length == 10;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.teamAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'RIDER', label: Text(l10n.roleRider), icon: const Icon(Icons.two_wheeler_outlined)),
                ButtonSegment(value: 'STAFF', label: Text(l10n.roleStaff), icon: const Icon(Icons.badge_outlined)),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            TextField(
              key: const Key('memberPhoneField'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              decoration: InputDecoration(labelText: l10n.phoneLabel, prefixText: '+91 '),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              key: const Key('memberNameField'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.nameOptional),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        TextButton(
          key: const Key('saveMemberButton'),
          onPressed: _valid
              ? () => Navigator.pop(
                  context,
                  _NewMember('+91${_phone.text}', _role, _name.text.trim().isEmpty ? null : _name.text.trim()),
                )
              : null,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
