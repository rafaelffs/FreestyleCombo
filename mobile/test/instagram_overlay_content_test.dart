import 'package:flutter_test/flutter_test.dart';
import 'package:freestyle_combo/core/models/combo.dart';
import 'package:freestyle_combo/core/models/instagram_overlay_content.dart';

ComboDto _combo({
  String? name,
  double totalDifficulty = 24,
  int trickCount = 5,
  double averageRating = 4.8,
  int totalRatings = 12,
  List<ComboTrickDto>? tricks,
}) {
  return ComboDto(
    id: 'combo-1',
    ownerId: 'owner-1',
    name: name,
    totalDifficulty: totalDifficulty,
    trickCount: trickCount,
    createdAt: '2026-09-08T00:00:00Z',
    displayText: 'SATW MATW',
    tricks: tricks,
    averageRating: averageRating,
    totalRatings: totalRatings,
  );
}

List<ComboTrickDto> _tricks(int count, {bool lastNoTouch = false}) {
  return List.generate(
    count,
    (i) => ComboTrickDto(
      position: i + 1,
      abbreviation: 'T${i + 1}',
      noTouch: lastNoTouch && i == count - 1,
    ),
  );
}

void main() {
  group('overlayNameToggleDisabled', () {
    test('true when combo has no name', () {
      expect(overlayNameToggleDisabled(_combo(name: null)), isTrue);
    });

    test('true when combo name is empty string', () {
      expect(overlayNameToggleDisabled(_combo(name: '')), isTrue);
    });

    test('false when combo has a name', () {
      expect(
          overlayNameToggleDisabled(_combo(name: 'Sunset Special')), isFalse);
    });
  });

  group('overlayEffectiveTitle', () {
    test('null when combo has no name, regardless of toggle', () {
      final combo = _combo(name: null);
      expect(
          overlayEffectiveTitle(
              combo, const InstagramOverlayToggles(name: true)),
          isNull);
    });

    test('null when combo has a name but the Name toggle is off', () {
      final combo = _combo(name: 'Sunset Special');
      expect(
          overlayEffectiveTitle(
              combo, const InstagramOverlayToggles(name: false)),
          isNull);
    });

    test('the name when combo has one and the toggle is on', () {
      final combo = _combo(name: 'Sunset Special');
      expect(
          overlayEffectiveTitle(
              combo, const InstagramOverlayToggles(name: true)),
          'Sunset Special');
    });
  });

  group('overlaySequenceOn', () {
    test('forced on for a nameless combo even if the toggle is off', () {
      final combo = _combo(name: null);
      expect(
          overlaySequenceOn(
              combo, const InstagramOverlayToggles(sequence: false)),
          isTrue);
    });

    test('follows the toggle for a named combo', () {
      final combo = _combo(name: 'Sunset Special');
      expect(
          overlaySequenceOn(
              combo, const InstagramOverlayToggles(sequence: false)),
          isFalse);
      expect(
          overlaySequenceOn(
              combo, const InstagramOverlayToggles(sequence: true)),
          isTrue);
    });
  });

  group('overlayChips', () {
    test('shows every trick with no overflow when at or under the cap', () {
      final combo = _combo(tricks: _tricks(5));
      final chips = overlayChips(combo, const InstagramOverlayToggles());
      expect(chips.shown, ['T1', 'T2', 'T3', 'T4', 'T5']);
      expect(chips.overflow, 0);
    });

    test('shows all 20 with no overflow right at the cap', () {
      final combo = _combo(tricks: _tricks(20));
      final chips = overlayChips(combo, const InstagramOverlayToggles());
      expect(chips.shown.length, 20);
      expect(chips.overflow, 0);
    });

    test('collapses to the first 20 plus an overflow count past the cap', () {
      final combo = _combo(tricks: _tricks(27));
      final chips = overlayChips(combo, const InstagramOverlayToggles());
      expect(chips.shown.length, 20);
      expect(chips.shown.first, 'T1');
      expect(chips.shown.last, 'T20');
      expect(chips.overflow, 7);
    });

    test('empty when Trick sequence is off and the combo has a name', () {
      final combo = _combo(name: 'Sunset Special', tricks: _tricks(5));
      final chips =
          overlayChips(combo, const InstagramOverlayToggles(sequence: false));
      expect(chips.shown, isEmpty);
      expect(chips.overflow, 0);
    });

    test('appends (nt) for a no-touch trick', () {
      final combo = _combo(tricks: _tricks(2, lastNoTouch: true));
      final chips = overlayChips(combo, const InstagramOverlayToggles());
      expect(chips.shown, ['T1', 'T2(nt)']);
    });

    test('empty when the combo has no trick data at all', () {
      final combo = _combo(tricks: null);
      final chips = overlayChips(combo, const InstagramOverlayToggles());
      expect(chips.shown, isEmpty);
      expect(chips.overflow, 0);
    });

    test('uses subComboName for a sub-combo entry, falling back to "Combo"',
        () {
      final combo = _combo(tricks: [
        const ComboTrickDto(type: 'trick', position: 1, abbreviation: 'T1'),
        const ComboTrickDto(
            type: 'combo', position: 2, subComboName: 'My Reusable'),
        const ComboTrickDto(type: 'combo', position: 3, subComboName: null),
      ]);
      final chips = overlayChips(combo, const InstagramOverlayToggles());
      expect(chips.shown, ['T1', 'My Reusable', 'Combo']);
    });
  });

  group('computeMinimalContent', () {
    test('title, meta line, and chips reflect the toggles', () {
      final combo = _combo(name: 'Sunset Special', tricks: _tricks(3));
      final content = computeMinimalContent(
        combo,
        const InstagramOverlayToggles(rating: true),
      );
      expect(content.title, 'Sunset Special');
      expect(content.metaParts, ['5 TRICKS', '24 DIFF', '4.8★']);
      expect(content.chips.shown, ['T1', 'T2', 'T3']);
    });

    test('meta line omits rating when the combo has zero ratings', () {
      final combo =
          _combo(name: 'Sunset Special', averageRating: 0, totalRatings: 0);
      final content = computeMinimalContent(
        combo,
        const InstagramOverlayToggles(rating: true),
      );
      expect(content.metaParts, isNot(contains(contains('★'))));
    });

    test('meta line is empty when every toggle is off', () {
      final combo = _combo(name: 'Sunset Special');
      final content = computeMinimalContent(
        combo,
        const InstagramOverlayToggles(
          name: false,
          difficulty: false,
          quantity: false,
          rating: false,
          sequence: false,
        ),
      );
      expect(content.metaParts, isEmpty);
    });
  });

  group('computeSequenceContent', () {
    test('difficulty badge and sub-line reflect the toggles', () {
      final combo = _combo(name: 'Sunset Special', tricks: _tricks(3));
      final content = computeSequenceContent(
        combo,
        const InstagramOverlayToggles(rating: true),
      );
      expect(content.title, 'Sunset Special');
      expect(content.difficultyBadge, '24');
      expect(content.subParts, ['5 tricks', '4.8★ (12)']);
      expect(content.isEmpty, isFalse);
    });

    test('isEmpty when everything is off for a named combo', () {
      final combo = _combo(name: 'Sunset Special');
      final content = computeSequenceContent(
        combo,
        const InstagramOverlayToggles(
          name: false,
          difficulty: false,
          quantity: false,
          rating: false,
          sequence: false,
        ),
      );
      expect(content.isEmpty, isTrue);
    });

    test('never isEmpty for a nameless combo — chips are forced on', () {
      final combo = _combo(name: null, tricks: _tricks(3));
      final content = computeSequenceContent(
        combo,
        const InstagramOverlayToggles(
          name: false,
          difficulty: false,
          quantity: false,
          rating: false,
          sequence: false,
        ),
      );
      expect(content.isEmpty, isFalse);
      expect(content.chips.shown, ['T1', 'T2', 'T3']);
    });
  });

  group('computeStatContent', () {
    test('tiles reflect the toggles, in Diff/Tricks/Rating order', () {
      final combo = _combo(name: 'Sunset Special');
      final content = computeStatContent(
        combo,
        const InstagramOverlayToggles(rating: true),
      );
      expect(content.tiles.map((t) => t.label), ['Diff', 'Tricks', 'Rating']);
      expect(content.tiles.map((t) => t.value), ['24', '5', '4.8★']);
    });

    test('drops the rating tile when the combo has zero ratings', () {
      final combo =
          _combo(name: 'Sunset Special', averageRating: 0, totalRatings: 0);
      final content = computeStatContent(
        combo,
        const InstagramOverlayToggles(rating: true),
      );
      expect(content.tiles.map((t) => t.label), ['Diff', 'Tricks']);
    });

    test('isEmpty when everything is off for a named combo', () {
      final combo = _combo(name: 'Sunset Special');
      final content = computeStatContent(
        combo,
        const InstagramOverlayToggles(
          name: false,
          difficulty: false,
          quantity: false,
          rating: false,
          sequence: false,
        ),
      );
      expect(content.isEmpty, isTrue);
    });

    test('never isEmpty for a nameless combo — chips are forced on', () {
      final combo = _combo(name: null, tricks: _tricks(3));
      final content = computeStatContent(
        combo,
        const InstagramOverlayToggles(
          name: false,
          difficulty: false,
          quantity: false,
          rating: false,
          sequence: false,
        ),
      );
      expect(content.isEmpty, isFalse);
      expect(content.chips.shown, ['T1', 'T2', 'T3']);
    });
  });
}
