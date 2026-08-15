import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:tracr/core/presentation/widgets/suggesting_input.dart';
import 'package:tracr/features/items/data/item_repository.dart';
import 'package:tracr/features/items/domain/item.dart';
import 'package:tracr/features/items/presentation/add_item_sheet.dart';
import 'package:tracr/features/sellers/data/seller_repository.dart';
import 'package:tracr/features/sellers/domain/seller.dart';

final _items = [
  Item(
    id: '1',
    userId: 'u1',
    name: 'Charizard VMAX',
    category: 'Graded Slab',
    stage: ItemStage.inHand,
    tags: const ['grail', 'holo'],
    attributes: const [ItemAttribute(label: 'Set Name', value: 'Base Set')],
    createdAt: DateTime(2026, 1, 1),
  ),
  Item(
    id: '2',
    userId: 'u1',
    name: 'Pikachu Illustrator',
    category: 'Sealed',
    stage: ItemStage.wishlist,
    tags: const ['vintage'],
    attributes: const [ItemAttribute(label: 'Set Name', value: 'Promo')],
    createdAt: DateTime(2026, 1, 2),
  ),
];

const _sellers = [
  Seller(id: 's1', name: 'CardKing', platform: 'Whatnot'),
  Seller(id: 's2', name: 'SlabHouse', platform: 'Shopee'),
];

Future<void> _pumpSheet(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userItemsStreamProvider.overrideWith((ref) => Stream.value(_items)),
        userSellersStreamProvider.overrideWith((ref) => Stream.value(_sellers)),
      ],
      child: ShadApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ShadButton(
              onPressed: () => showShadSheet(
                context: context,
                side: ShadSheetSide.right,
                builder: (_) => const AddItemSheet(),
              ),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('open sheet'));
  await tester.pumpAndSettle();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _option(String label) => find.widgetWithText(ShadButton, label);

Finder _field(String placeholder) => find.byWidgetPredicate(
      (w) =>
          w is SuggestingInput &&
          w.placeholder is Text &&
          (w.placeholder! as Text).data == placeholder,
    );

const _namePlaceholder = 'e.g., Charizard VMAX #074';
const _categoryPlaceholder = 'Card, Sealed, Figure...';
const _tagsPlaceholder = 'vintage, grail, holo';
const _sellerPlaceholder = 'e.g., @CardKing on Whatnot';
const _platformPlaceholder = 'Facebook, Shopee, Carousell, IG...';

String _textOf(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    )
    .controller
    .text;

void main() {
  testWidgets('item name suggests names already logged', (tester) async {
    await _pumpSheet(tester);

    await tester.tap(_field(_namePlaceholder));
    await _settle(tester);

    expect(_option('Charizard VMAX'), findsOneWidget);
    expect(_option('Pikachu Illustrator'), findsOneWidget);
  });

  testWidgets('category suggests categories already used', (tester) async {
    await _pumpSheet(tester);

    await tester.enterText(_field(_categoryPlaceholder), 'seal');
    await _settle(tester);

    expect(_option('Sealed'), findsOneWidget);
    expect(_option('Graded Slab'), findsNothing);
  });

  testWidgets('tags complete one at a time from existing tags', (tester) async {
    await _pumpSheet(tester);

    final tagsField = _field(_tagsPlaceholder);
    await tester.enterText(tagsField, 'gr');
    await _settle(tester);

    expect(_option('grail'), findsOneWidget);

    await tester.tap(_option('grail'));
    await _settle(tester);

    expect(_textOf(tester, tagsField), 'grail, ');
  });

  group('seller', () {
    Future<void> chooseStashed(WidgetTester tester) async {
      await tester.tap(find.text('💭 Wishlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('⏳ Already bought (Stashed)').last);
      await tester.pumpAndSettle();
    }

    testWidgets('is a free-text field suggesting saved sellers', (tester) async {
      await _pumpSheet(tester);
      await chooseStashed(tester);

      final sellerField = _field(_sellerPlaceholder);
      expect(sellerField, findsOneWidget);

      await tester.enterText(sellerField, 'card');
      await _settle(tester);
      expect(_option('CardKing'), findsOneWidget);
    });

    testWidgets('picking a saved seller fills in its platform', (tester) async {
      await _pumpSheet(tester);
      await chooseStashed(tester);

      await tester.enterText(_field(_sellerPlaceholder), 'card');
      await _settle(tester);
      await tester.tap(_option('CardKing'));
      await _settle(tester);

      expect(_textOf(tester, _field(_platformPlaceholder)), 'Whatnot');
      expect(
        find.text('Matches a saved seller — this purchase will be added to them.'),
        findsOneWidget,
      );
    });

    testWidgets('an unknown seller name is kept as a new seller', (tester) async {
      await _pumpSheet(tester);
      await chooseStashed(tester);

      await tester.enterText(_field(_sellerPlaceholder), 'Brand New Shop');
      await _settle(tester);

      expect(find.text('Type a new name to create a seller.'), findsOneWidget);
    });
  });
}
