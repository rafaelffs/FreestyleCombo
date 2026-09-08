import 'combo.dart';

/// Which of the three overlay layouts is selected on the share picker.
enum InstagramOverlayStyle { minimal, sequence, stat }

/// Text-size multiplier applied uniformly to every overlay text element
/// except the FSCOMBO wordmark, which stays a fixed size regardless of
/// this choice — see InstagramOverlay.
enum InstagramTextSize {
  small(0.82),
  medium(1.0),
  large(1.28);

  final double scale;
  const InstagramTextSize(this.scale);
}

/// Which stats show on the overlay — shared across all three layouts.
class InstagramOverlayToggles {
  final bool name;
  final bool difficulty;
  final bool quantity;
  final bool rating;
  final bool sequence;

  const InstagramOverlayToggles({
    this.name = true,
    this.difficulty = true,
    this.quantity = true,
    this.rating = false,
    this.sequence = true,
  });

  InstagramOverlayToggles copyWith({
    bool? name,
    bool? difficulty,
    bool? quantity,
    bool? rating,
    bool? sequence,
  }) {
    return InstagramOverlayToggles(
      name: name ?? this.name,
      difficulty: difficulty ?? this.difficulty,
      quantity: quantity ?? this.quantity,
      rating: rating ?? this.rating,
      sequence: sequence ?? this.sequence,
    );
  }
}

/// Chips show the entire trick sequence up to this count — no arbitrary
/// truncation for an ordinary combo. Only past this many tricks does the
/// list collapse to a head plus an overflow count, well beyond the app's
/// typical combo length (the random-unset-field default range is 5-20;
/// see CLAUDE.md's "Unset-field resolution during generation").
const int kOverlayChipShowAllUpTo = 20;

/// Nameless combos already fall back to their trick sequence everywhere
/// else in the app (combo cards, share links). The overlay follows the
/// same rule: no name means the Name toggle has nothing to hide.
bool overlayNameToggleDisabled(ComboDto combo) =>
    combo.name == null || combo.name!.isEmpty;

/// The title to show, or null if none should show — either because the
/// combo has no name, or because the Name toggle is off.
String? overlayEffectiveTitle(ComboDto combo, InstagramOverlayToggles toggles) {
  if (overlayNameToggleDisabled(combo)) return null;
  if (!toggles.name) return null;
  return combo.name;
}

/// True when the combo has no name — the chip row becomes the overlay's
/// only identifying content in that case.
bool overlaySequenceForced(ComboDto combo) => overlayNameToggleDisabled(combo);

/// Whether the chip row should render at all.
bool overlaySequenceOn(ComboDto combo, InstagramOverlayToggles toggles) =>
    toggles.sequence || overlaySequenceForced(combo);

List<String> _trickAbbreviations(ComboDto combo) {
  final tricks = combo.tricks;
  if (tricks == null) return [];
  return tricks.map((t) {
    final base = t.type == 'combo' ? (t.subComboName ?? 'Combo') : (t.abbreviation ?? t.name ?? '?');
    return (t.noTouch && !t.isTransition) ? '$base(nt)' : base;
  }).toList();
}

/// The chips to render, already truncated per [kOverlayChipShowAllUpTo],
/// plus how many tricks were left off (0 if none).
class OverlayChips {
  final List<String> shown;
  final int overflow;
  const OverlayChips({required this.shown, required this.overflow});
}

OverlayChips overlayChips(ComboDto combo, InstagramOverlayToggles toggles) {
  if (!overlaySequenceOn(combo, toggles)) {
    return const OverlayChips(shown: [], overflow: 0);
  }
  final all = _trickAbbreviations(combo);
  if (all.length <= kOverlayChipShowAllUpTo) {
    return OverlayChips(shown: all, overflow: 0);
  }
  return OverlayChips(
    shown: all.sublist(0, kOverlayChipShowAllUpTo),
    overflow: all.length - kOverlayChipShowAllUpTo,
  );
}
