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
}
