import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tracr/core/theme/theme_provider.dart';
import 'package:tracr/features/collectibles/presentation/dashboard_page.dart';
import 'package:tracr/features/items/data/item_repository.dart';
import 'package:tracr/features/items/domain/item.dart';
import 'package:tracr/features/profile/data/profile_repository.dart';

Item _item(String name, ItemStage stage) => Item(
      id: name,
      userId: 'u1',
      name: name,
      category: 'Cards',
      stage: stage,
      marketValue: 100,
      createdAt: DateTime(2026, 1, 1),
    );

final _items = [
  for (final stage in ItemStage.values)
    for (var i = 0; i < 3; i++) _item('${stage.name}-$i', stage),
];

Future<void> _pumpDashboard(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // The shell's sidebar reads prefs and the signed-in profile; both reach
  // Firebase, so they are stubbed to keep the test on the layout.
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userItemsStreamProvider.overrideWith((ref) => Stream.value(_items)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserProfileProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: const ShadApp(home: DashboardPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Regression: the mobile board used to put an Expanded inside a
  // SingleChildScrollView, so the whole page failed to lay out and rendered
  // nothing but an error box.
  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    testWidgets('renders the pipeline at ${size.width.toInt()}px wide', (tester) async {
      await _pumpDashboard(tester, size);

      expect(tester.takeException(), isNull);
      expect(find.text('Overview'), findsOneWidget);
      // One stage shown at a time, chosen from the stage tabs.
      expect(find.textContaining('⏳ Stashed'), findsWidgets);
      expect(find.text('stashed-0'), findsOneWidget);
    });
  }

  testWidgets('switching stage tabs swaps the visible column', (tester) async {
    await _pumpDashboard(tester, const Size(390, 844));

    // Wishlist is the leftmost tab, so it is on-screen without scrolling the
    // strip. Stashed is the default selection.
    expect(find.text('stashed-0'), findsOneWidget);

    await tester.tap(find.textContaining('💭 Wishlist'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('wishlist-0'), findsOneWidget);
    expect(find.text('stashed-0'), findsNothing);
  });

  testWidgets('renders all four columns at desktop width', (tester) async {
    await _pumpDashboard(tester, const Size(1440, 900));

    expect(tester.takeException(), isNull);
    for (final name in ['wishlist-0', 'stashed-0', 'inTransit-0', 'inHand-0']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('board scrolls horizontally at tablet width', (tester) async {
    await _pumpDashboard(tester, const Size(900, 800));

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.text('wishlist-0'), findsOneWidget);
  });
}
