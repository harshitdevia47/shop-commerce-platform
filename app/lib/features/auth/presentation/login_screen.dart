import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/legal_links.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import 'auth_controller.dart';

/// Step 1: phone number. Shown at /login.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({this.returnTo, super.key});

  /// Where a customer continues after logging in (e.g. `/checkout`).
  final String? returnTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  bool _sending = false;
  String? _error;

  bool get _valid => RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text);

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_valid || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final phone = '+91${_phone.text}';
    try {
      final result = await ref.read(authControllerProvider.notifier).requestOtp(phone);
      if (!mounted) return;
      await context.push(
        Routes.otp,
        extra: OtpRouteArgs(phone: phone, request: result, returnTo: widget.returnTo),
      );
    } on Object catch (error) {
      if (mounted) setState(() => _error = errorMessage(context.l10n, error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final client = ref.watch(clientConfigProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.login)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  client.logoAsset,
                  width: 88,
                  height: 88,
                  errorBuilder: (_, _, _) => const SizedBox.square(dimension: 88),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(l10n.loginTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(l10n.loginSubtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            TextField(
              key: const Key('phoneField'),
              controller: _phone,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              decoration: InputDecoration(
                labelText: l10n.phoneLabel,
                prefixText: '+91 ',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _send(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('sendOtpButton'),
              onPressed: _valid && !_sending ? _send : null,
              child: _sending
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.sendOtp),
            ),
            const SizedBox(height: 16),
            LegalLinks(prefix: l10n.legalAgree),
          ],
        ),
      ),
    );
  }
}
