import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/router/app_router.dart';
import 'auth_controller.dart';

/// Step 2: 6-digit code. Shown at /login/otp. On success goes to the home for the user's role.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({required this.args, super.key});

  final OtpRouteArgs args;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  late int _resendIn;
  String? _debugCode;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCooldown(widget.args.request.resendAfterSeconds);
    _applyDebugCode(widget.args.request.debugCode);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  /// Dev backends echo the code; prefill it outside production for emulator testing.
  void _applyDebugCode(String? code) {
    if (code == null || ref.read(envConfigProvider).isProduction) return;
    _debugCode = code;
    _code.text = code;
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    _resendIn = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (_code.text.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // On success the router's auth listener navigates: the role's home, then `returnTo`
      // for customers. (OTP is only reachable while logged out, so login always changes the user.)
      ref.read(pendingReturnToProvider.notifier).set(widget.args.returnTo);
      await ref.read(authControllerProvider.notifier).verifyOtp(widget.args.phone, _code.text);
    } on Object catch (error) {
      ref.read(pendingReturnToProvider.notifier).set(null);
      if (mounted) setState(() => _error = errorMessage(context.l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(authControllerProvider.notifier).requestOtp(widget.args.phone);
      _code.clear();
      _applyDebugCode(result.debugCode);
      _startCooldown(result.resendAfterSeconds);
    } on Object catch (error) {
      if (mounted) setState(() => _error = errorMessage(context.l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.otpTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(l10n.otpSubtitle(widget.args.phone), style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            TextField(
              key: const Key('otpField'),
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 12),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              decoration: InputDecoration(border: const OutlineInputBorder(), counterText: '', errorText: _error),
              onChanged: (value) {
                if (_error != null) setState(() => _error = null);
                if (value.length == 6) _verify();
              },
            ),
            if (_debugCode != null) ...[
              const SizedBox(height: 8),
              Text(l10n.devOtpHint(_debugCode!), style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('verifyButton'),
              onPressed: _busy ? null : _verify,
              child: _busy
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.verify),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton(onPressed: () => context.pop(), child: Text(l10n.changeNumber)),
                TextButton(
                  onPressed: _resendIn > 0 || _busy ? null : _resend,
                  child: Text(_resendIn > 0 ? l10n.resendIn(_resendIn) : l10n.resend),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
