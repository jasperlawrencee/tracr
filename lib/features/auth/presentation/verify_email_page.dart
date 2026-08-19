import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:tracr/features/auth/data/auth_repository.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  bool _isChecking = false;
  bool _isResending = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkVerified());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    if (_isChecking) return;
    _isChecking = true;
    final verified = await ref.read(authRepositoryProvider).refreshEmailVerified();
    _isChecking = false;
    if (verified && mounted) {
      ref.invalidate(authStateChangesProvider);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _message = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendVerificationEmail();
      if (!mounted) return;
      setState(() => _message = 'Verification email sent.');
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString().replaceAll(RegExp(r'\[.*\]'), '').trim());
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldownSeconds--);
      if (_cooldownSeconds <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;
    final email = ref.watch(authStateChangesProvider).value?.email ?? 'your email';

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Verify your email', style: textTheme.h3, textAlign: TextAlign.center),
                const Gap(12),
                Text(
                  "We sent a verification link to $email. Click it, then come back here — "
                  "this page updates automatically once you're verified.",
                  style: textTheme.p,
                  textAlign: TextAlign.center,
                ),
                const Gap(24),
                if (_message != null) ...[
                  Text(_message!, style: textTheme.small),
                  const Gap(12),
                ],
                ShadButton(
                  width: double.infinity,
                  onPressed: _checkVerified,
                  child: const Text("I've verified"),
                ),
                const Gap(12),
                ShadButton.outline(
                  width: double.infinity,
                  onPressed: (_isResending || _cooldownSeconds > 0) ? null : _resend,
                  child: Text(
                    _cooldownSeconds > 0
                        ? 'Resend email (${_cooldownSeconds}s)'
                        : (_isResending ? 'Sending...' : 'Resend email'),
                  ),
                ),
                const Gap(12),
                ShadButton.ghost(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  child: const Text('Use a different account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
