import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freestyle_combo/core/models/combo.dart';
import 'package:freestyle_combo/features/combos/instagram_share/share_options_sheet.dart';

ComboDto _combo() {
  return const ComboDto(
    id: 'combo-1',
    ownerId: 'owner-1',
    name: 'Sunset Special',
    totalDifficulty: 24,
    trickCount: 5,
    createdAt: '2026-09-08T00:00:00Z',
    displayText: 'SATW MATW',
    averageRating: 4.8,
    totalRatings: 12,
  );
}

void main() {
  testWidgets('shows both Share to Social Media and Share Link options', (tester) async {
    var linkTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showShareOptionsSheet(
              context,
              combo: _combo(),
              onShareLink: () => linkTapped = true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Share to Social Media'), findsOneWidget);
    expect(find.text('Share Link'), findsOneWidget);

    await tester.tap(find.text('Share Link'));
    await tester.pumpAndSettle();
    expect(linkTapped, isTrue);
  });

  testWidgets('tapping Share to Social Media opens the style picker', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showShareOptionsSheet(context, combo: _combo(), onShareLink: () {}),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share to Social Media'));
    await tester.pumpAndSettle();

    // The picker sheet renders inside a scrollable DraggableScrollableSheet
    // taller than the default test viewport, so its ListView lazily builds only the
    // visible extent — scroll to bring the button into the built subtree first.
    await tester.dragUntilVisible(
      find.text('Save to device'),
      find.byType(ListView),
      const Offset(0, -50),
    );
    await tester.pumpAndSettle();

    expect(find.text('Save to device'), findsOneWidget);
  });
}
