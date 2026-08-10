import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/verify_email_page.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/landing/presentation/landing_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/collectibles/presentation/dashboard_page.dart';
import '../../features/wishlist/presentation/wishlist_page.dart';
import '../../features/stash/presentation/stash_page.dart';
import '../../features/tracking/presentation/tracking_page.dart';
import '../../features/inhand/presentation/inhand_page.dart';
import '../../features/inhand/presentation/container_detail_page.dart';

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateChangesProvider, (_, _) => notifyListeners());
    ref.listen(currentUserProfileProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateChangesProvider);
      if (auth.isLoading) return null;

      final user = auth.value;
      final loc = state.matchedLocation;

      if (user == null) return loc == '/' ? null : '/';
      if (!user.emailVerified) return loc == '/verify-email' ? null : '/verify-email';

      final profile = ref.read(currentUserProfileProvider);
      if (profile.isLoading) return null;
      final onboardingComplete = profile.value?.isOnboardingComplete ?? false;
      if (!onboardingComplete) return loc == '/onboarding' ? null : '/onboarding';

      if (loc == '/' || loc == '/onboarding' || loc == '/verify-email') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: '/wishlist',
        builder: (context, state) => const WishlistPage(),
      ),
      GoRoute(
        path: '/stash',
        builder: (context, state) => const StashPage(),
      ),
      GoRoute(
        path: '/tracking',
        builder: (context, state) => const TrackingPage(),
      ),
      GoRoute(
        path: '/in-hand',
        builder: (context, state) => const InHandPage(),
      ),
      GoRoute(
        path: '/in-hand/:containerId',
        builder: (context, state) =>
            ContainerDetailPage(containerId: state.pathParameters['containerId']!),
      ),
    ],
  );
});
