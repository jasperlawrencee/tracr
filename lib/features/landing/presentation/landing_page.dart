import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:tracr/features/auth/data/auth_repository.dart';
import 'package:tracr/features/auth/presentation/auth_dialog.dart';

class LandingPage extends ConsumerWidget {
  const LandingPage({super.key});

  void _showAuthModal(BuildContext context) {
    showShadDialog(
      context: context,
      builder: (context) => const AuthDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = ShadTheme.of(context).textTheme;

    // A signed-in user briefly sits here while the router's redirect logic
    // resolves email-verification/profile state — show a spinner instead of
    // flashing the logged-out hero.
    final isSignedIn = ref.watch(authStateChangesProvider).value != null;
    if (isSignedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('tracr 📦', style: textTheme.h3),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          ShadButton.ghost(
            onPressed: () => _showAuthModal(context),
            child: const Text('Log In'),
          ),
          const Gap(8),
          ShadButton(
            onPressed: () => _showAuthModal(context),
            child: const Text('Get Started'),
          ),
          const Gap(16),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
          child: Center(
            child: Column(
              children: [
                Text(
                  'Stop losing track of your stash.',
                  style: textTheme.h1,
                  textAlign: TextAlign.center,
                ),
                const Gap(16),
                Text(
                  'Track seller stashes, packages in transit, and your vaulted collection in one clear dashboard.',
                  style: textTheme.lead,
                  textAlign: TextAlign.center,
                ),
                const Gap(32),
                ShadButton(
                  size: ShadButtonSize.lg,
                  onPressed: () => _showAuthModal(context),
                  child: const Text('Start Tracking Free'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}