import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../api/admin_api.dart';
import '../auth/session.dart';

/// Email → 6-digit code from Gmail → logged in for 90 days.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiError catch (e) {
      setState(() => _error = e.display);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    if (!_email.text.contains('@')) throw const ApiError('EMAIL', 'Enter your email address.');
    await ref.read(sessionProvider.notifier).requestCode(_email.text);
    setState(() => _codeSent = true);
  });

  Future<void> _verify() => _run(() => ref.read(sessionProvider.notifier).verify(_email.text, _code.text));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            Icon(Icons.storefront, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Shop Admin', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Shop subscriptions, in one place', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 40),
            TextField(
              key: const Key('emailField'),
              controller: _email,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Your email', border: OutlineInputBorder()),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 16),
              Text('A 6-digit code is on its way to ${_email.text.trim()}. Check Gmail (and Spam).'),
              const SizedBox(height: 12),
              TextField(
                key: const Key('codeField'),
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: const InputDecoration(labelText: '6-digit code', border: OutlineInputBorder()),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, key: const Key('loginError'), style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('loginButton'),
              onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
              child: Text(_codeSent ? 'Log in' : 'Send me a login code'),
            ),
            if (_codeSent)
              TextButton(
                onPressed: _busy ? null : () => setState(() {
                  _codeSent = false;
                  _code.clear();
                  _error = null;
                }),
                child: const Text('Use another email or get a new code'),
              ),
          ],
        ),
      ),
    );
  }
}
