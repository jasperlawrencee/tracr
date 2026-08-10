
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:tracr/features/auth/data/auth_repository.dart';

class AuthDialog extends ConsumerStatefulWidget {
  const AuthDialog({super.key});

  @override
  ConsumerState<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends ConsumerState<AuthDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authRepo = ref.read(authRepositoryProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_isSignUp) {
        await authRepo.signUpWithEmail(email, password);
      } else {
        await authRepo.signInWithEmail(email, password);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll(RegExp(r'\[.*\]'), '').trim();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;

    // Google sign-in on web completes via a stream event rather than an
    // awaitable call, so close the dialog once Firebase reports a user.
    ref.listen(authStateChangesProvider, (previous, next) {
      if (next.value != null && mounted) {
        Navigator.of(context).maybePop();
      }
    });

    return ShadDialog(
      title: Text(_isSignUp ? 'Create a tracr Account' : 'Welcome to tracr', style: textTheme.h4),
      description: Text(_isSignUp ? 'Enter your details below to sign up.' : 'Sign in to access your dashboard.'),
      child: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: textTheme.small.copyWith(color: Colors.redAccent)),
              const Gap(12),
            ],
            ShadInput(
              controller: _emailController,
              placeholder: const Text('Email address'),
              keyboardType: TextInputType.emailAddress,
            ),
            const Gap(12),
            ShadInput(
              controller: _passwordController,
              placeholder: const Text('Password'),
              obscureText: true,
            ),
            const Gap(20),
            ShadButton(
              width: double.infinity,
              onPressed: _isLoading ? null : _submit,
              child: Text(_isLoading ? 'Loading...' : (_isSignUp ? 'Register' : 'Log In')),
            ),
            const Gap(12),
            Center(
              child: SizedBox(
                child: google_web.renderButton(
                  configuration: google_web.GSIButtonConfiguration(
                    minimumWidth: 320,
                    theme: google_web.GSIButtonTheme.outline,
                    size: google_web.GSIButtonSize.large,
                    shape: google_web.GSIButtonShape.rectangular,
                    text: google_web.GSIButtonText.continueWith,
                    logoAlignment: google_web.GSIButtonLogoAlignment.left,
                  ),
                ),
              ),
            ),
            const Gap(12),
            const Divider(),
            Center(
              child: ShadButton.ghost(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(_isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Sign Up"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}