import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:tracr/core/presentation/widgets/suggesting_input.dart';

const _suggestions = ['Holo', 'Vintage', 'Grail', 'Graded Slab'];

Future<TextEditingController> _pumpField(
  WidgetTester tester, {
  bool commaSeparated = false,
  List<String> suggestions = _suggestions,
}) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    ShadApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: SuggestingInput(
            controller: controller,
            suggestions: suggestions,
            commaSeparated: commaSeparated,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// A focused [ShadInput] blinks its caret forever, so `pumpAndSettle` would
/// never return. The first pump processes the callback, the second lets the
/// popover's portal mount and animate in.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The popover row, as opposed to the text sitting in the field itself.
Finder _option(String label) => find.widgetWithText(ShadButton, label);

void main() {
  testWidgets('focusing an empty field offers every suggestion', (tester) async {
    await _pumpField(tester);

    await tester.tap(find.byType(ShadInput));
    await _settle(tester);

    for (final suggestion in _suggestions) {
      expect(_option(suggestion), findsOneWidget);
    }
  });

  // Regression: a ShadPopover requests focus when it opens, which blurred the
  // field and closed the list again. Typing has to survive the list appearing.
  testWidgets('the field keeps focus while suggestions are open', (tester) async {
    final controller = await _pumpField(tester);

    await tester.tap(find.byType(ShadInput));
    await _settle(tester);
    expect(_option('Holo'), findsOneWidget);

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);

    await tester.enterText(find.byType(ShadInput), 'gra');
    await _settle(tester);

    expect(controller.text, 'gra');
    expect(_option('Grail'), findsOneWidget);
  });

  testWidgets('typing narrows suggestions and matches are case-insensitive', (tester) async {
    await _pumpField(tester);

    await tester.tap(find.byType(ShadInput));
    await _settle(tester);
    await tester.enterText(find.byType(ShadInput), 'gra');
    await _settle(tester);

    expect(_option('Grail'), findsOneWidget);
    expect(_option('Graded Slab'), findsOneWidget);
    expect(_option('Holo'), findsNothing);
    expect(_option('Vintage'), findsNothing);
  });

  testWidgets('tapping a suggestion fills the field', (tester) async {
    final controller = await _pumpField(tester);

    await tester.tap(find.byType(ShadInput));
    await _settle(tester);
    await tester.enterText(find.byType(ShadInput), 'vin');
    await _settle(tester);

    await tester.tap(_option('Vintage'));
    await _settle(tester);

    expect(controller.text, 'Vintage');
    // A single-value field closes once it has its answer.
    expect(_option('Vintage'), findsNothing);
  });

  testWidgets('a free-typed value is kept even when nothing matches', (tester) async {
    final controller = await _pumpField(tester);

    await tester.tap(find.byType(ShadInput));
    await _settle(tester);
    await tester.enterText(find.byType(ShadInput), 'Sealed Booster Box');
    await _settle(tester);

    expect(controller.text, 'Sealed Booster Box');
    expect(_option('Holo'), findsNothing);
  });

  group('comma-separated', () {
    testWidgets('completes only the token after the last comma', (tester) async {
      final controller = await _pumpField(tester, commaSeparated: true);

      await tester.tap(find.byType(ShadInput));
      await _settle(tester);
      await tester.enterText(find.byType(ShadInput), 'holo, gra');
      await _settle(tester);

      // Filtering applies to "gra", not the whole string.
      expect(_option('Grail'), findsOneWidget);

      await tester.tap(_option('Grail'));
      await _settle(tester);

      expect(controller.text, 'holo, Grail, ');
    });

    testWidgets('does not re-offer tags already entered', (tester) async {
      await _pumpField(tester, commaSeparated: true);

      await tester.tap(find.byType(ShadInput));
      await _settle(tester);
      await tester.enterText(find.byType(ShadInput), 'Vintage, ');
      await _settle(tester);

      expect(_option('Vintage'), findsNothing);
      expect(_option('Holo'), findsOneWidget);
    });
  });
}
