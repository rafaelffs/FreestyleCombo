const double kRevolutionRangeMin = 0.5;
const double kRevolutionRangeMax = 4.0;
const double kRevolutionRangeStep = 0.5;

/// A full-range selection (kRevolutionRangeMin..kRevolutionRangeMax) encodes
/// to an empty list, matching the existing "empty AllowedRevolutions = no
/// restriction" backend semantics.
List<double> encodeRevolutionRange(double min, double max) {
  if (min <= kRevolutionRangeMin && max >= kRevolutionRangeMax) return [];
  final steps = ((max - min) / kRevolutionRangeStep).round();
  return [
    for (var i = 0; i <= steps; i++)
      ((min + i * kRevolutionRangeStep) * 2).round() / 2,
  ];
}

({double min, double max}) decodeRevolutionRange(List<double> list) {
  if (list.isEmpty) {
    return (min: kRevolutionRangeMin, max: kRevolutionRangeMax);
  }
  var lo = list.first;
  var hi = list.first;
  for (final v in list) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  return (min: lo, max: hi);
}
