import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

import 'core/router/router.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/data/auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await GoogleSignIn.instance.initialize();
  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const TracrApp(),
  ));
}

class TracrApp extends ConsumerWidget {
  const TracrApp({super.key}); 

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the repository alive for the app's lifetime so its Google
    // sign-in event listener is registered before the button is used.
    ref.watch(authRepositoryProvider);
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return ShadApp.router(
      title: 'tracr',
      routerConfig: router,
      themeMode: themeMode,
      theme: ShadThemeData(
        textTheme: ShadTextTheme(
          family: 'Noto'
        ),
        brightness: Brightness.light,
        colorScheme: const ShadSlateColorScheme.light(),
      ),
      darkTheme: ShadThemeData(
        textTheme: ShadTextTheme(
          family: 'Noto'
        ),
        brightness: Brightness.dark,
        colorScheme: const ShadSlateColorScheme.dark(),
      ),
    );
  }
}