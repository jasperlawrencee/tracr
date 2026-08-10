import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:tracr/features/items/domain/item.dart';

// Import your main app entry point
import 'package:tracr/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('tracr App End-to-End Pipeline Tests', () {
    testWidgets('Add a wishlist item, mark it bought, filter the dashboard, then delete it',
        (tester) async {
      // 1. Launch the application
      app.main();
      await tester.pumpAndSettle();

      // Note: If testing from a fresh launch, perform login actions here
      // e.g., finder for Email/Password fields -> tester.enterText(...) -> tester.tap(Login)

      // Verify Dashboard App Bar exists
      expect(find.text('tracr 📦'), findsOneWidget);

      // -----------------------------------------------------------------------
      // 2. Open "Add Item" Sheet and create a wishlist item
      // -----------------------------------------------------------------------
      final addItemButton = find.widgetWithText(ShadButton, 'Add Item');
      expect(addItemButton, findsOneWidget);
      await tester.tap(addItemButton);
      await tester.pumpAndSettle();

      // Enter Item Name
      final nameInput = find.byWidgetPredicate(
        (widget) =>
            widget is ShadInput &&
            widget.placeholder is Text &&
            (widget.placeholder as Text).data!.contains('Charizard'),
      );
      expect(nameInput, findsOneWidget);
      await tester.enterText(nameInput, 'Eevee Heroes Special Art');

      // Starting Stage defaults to Wishlist — leave as-is and submit.
      final saveButton = find.widgetWithText(ShadButton, 'Save Item');
      await tester.tap(saveButton);
      await tester.pumpAndSettle(const Duration(seconds: 2)); // Allow Firestore write

      // Verify created item appears on the dashboard's Wishlist column.
      expect(find.text('Eevee Heroes Special Art'), findsOneWidget);

      // -----------------------------------------------------------------------
      // 3. Test Pipeline Filtering Dropdown
      // -----------------------------------------------------------------------
      final filterSelect = find.byType(ShadSelect<ItemStage?>);
      expect(filterSelect, findsOneWidget);

      // Open Dropdown
      await tester.tap(filterSelect);
      await tester.pumpAndSettle();

      // Select '🚚 In Transit' filter option using ValueKey
      final inTransitOption = find.byKey(const ValueKey('inTransit'));
      expect(inTransitOption, findsOneWidget);
      await tester.tap(inTransitOption);
      await tester.pumpAndSettle();

      // Since our newly added item is on the Wishlist, it should now be hidden under 'In Transit'.
      expect(find.text('Eevee Heroes Special Art'), findsNothing);

      // Reset filter back to the Wishlist column.
      await tester.tap(filterSelect);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wishlist')));
      await tester.pumpAndSettle();

      // Item should be visible again
      expect(find.text('Eevee Heroes Special Art'), findsOneWidget);

      // -----------------------------------------------------------------------
      // 4. Mark Bought — creates a new seller and moves the item to Stashed
      // -----------------------------------------------------------------------
      final markBoughtBtn = find.widgetWithText(ShadButton, 'Mark Bought');
      expect(markBoughtBtn, findsOneWidget);
      await tester.tap(markBoughtBtn);
      await tester.pumpAndSettle();

      final newSellerNameInput = find.byWidgetPredicate(
        (widget) =>
            widget is ShadInput &&
            widget.placeholder is Text &&
            (widget.placeholder as Text).data!.contains('CardShopPH'),
      );
      expect(newSellerNameInput, findsOneWidget);
      await tester.enterText(newSellerNameInput, 'EeveeVault');

      final priceInput = find.byWidgetPredicate(
        (widget) =>
            widget is ShadInput &&
            widget.placeholder is Text &&
            (widget.placeholder as Text).data == '0.00',
      );
      expect(priceInput, findsOneWidget);
      await tester.enterText(priceInput, '150.00');

      final confirmBoughtBtn = find.widgetWithText(ShadButton, 'Confirm');
      await tester.tap(confirmBoughtBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify the item now shows its seller and a "Mark Shipped" action.
      expect(find.textContaining('EeveeVault'), findsOneWidget);
      expect(find.widgetWithText(ShadButton, 'Mark Shipped'), findsOneWidget);

      // -----------------------------------------------------------------------
      // 5. Delete Item
      // -----------------------------------------------------------------------
      final deleteIcon = find.byIcon(Icons.delete_outline);
      expect(deleteIcon, findsWidgets);
      await tester.tap(deleteIcon.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify item was removed from the real-time stream.
      expect(find.text('Eevee Heroes Special Art'), findsNothing);
    });
  });
}
