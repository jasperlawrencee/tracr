import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/theme_provider.dart';

const _sidebarCollapsedKey = 'sidebarCollapsed';

class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_sidebarCollapsedKey) ?? false;

  Future<void> toggle() async {
    state = !state;
    await ref.read(sharedPreferencesProvider).setBool(_sidebarCollapsedKey, state);
  }
}

final sidebarCollapsedProvider = NotifierProvider<SidebarCollapsedNotifier, bool>(
  SidebarCollapsedNotifier.new,
);
