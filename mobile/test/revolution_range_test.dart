import 'package:flutter_test/flutter_test.dart';
import 'package:freestyle_combo/core/models/revolution_range.dart';

void main() {
  group('encodeRevolutionRange', () {
    test('full range encodes to empty list (no filter)', () {
      expect(encodeRevolutionRange(0.5, 4.0), isEmpty);
    });

    test('2.0-3.0 encodes to [2.0, 2.5, 3.0]', () {
      expect(encodeRevolutionRange(2.0, 3.0), [2.0, 2.5, 3.0]);
    });

    test('single-value range encodes to one item', () {
      expect(encodeRevolutionRange(1.5, 1.5), [1.5]);
    });
  });

  group('decodeRevolutionRange', () {
    test('empty list decodes to full range', () {
      final r = decodeRevolutionRange([]);
      expect(r.min, 0.5);
      expect(r.max, 4.0);
    });

    test('[2.0, 2.5, 3.0] decodes to min 2.0 max 3.0', () {
      final r = decodeRevolutionRange([2.0, 2.5, 3.0]);
      expect(r.min, 2.0);
      expect(r.max, 3.0);
    });

    test('unordered list still decodes correctly', () {
      final r = decodeRevolutionRange([3.0, 0.5, 2.0]);
      expect(r.min, 0.5);
      expect(r.max, 3.0);
    });
  });
}
