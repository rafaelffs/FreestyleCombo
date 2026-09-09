import 'combo.dart';

/// Which of the three overlay layouts is selected on the share picker.
enum InstagramOverlayStyle { minimal, sequence, stat }

/// Which edge of the canvas the text band (scrim + content + wordmark)
/// anchors to — see InstagramOverlay.
enum InstagramOverlayPosition { top, bottom }

/// Text-size multiplier applied uniformly to every overlay text element
/// except the FSCOMBO wordmark, which stays a fixed size regardless of
/// this choice — see InstagramOverlay.
enum InstagramTextSize {
  smallest(0.68),
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
    this.difficulty = false,
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
    final base = t.type == 'combo'
        ? (t.subComboName ?? 'Combo')
        : (t.abbreviation ?? t.name ?? '?');
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

/// Content for the Minimal layout: a title, an uppercase meta line
/// (tricks/diff/rating), and the trick chips. No [isEmpty] flag — unlike
/// the Sequence/Stat styles, this layout always renders something
/// presentable (the wordmark plus a blank meta line reads fine on its
/// own), so there's no "nothing to show" state a consuming widget needs
/// to react to.
class MinimalOverlayContent {
  final String? title;
  final List<String> metaParts;
  final OverlayChips chips;
  const MinimalOverlayContent(
      {required this.title, required this.metaParts, required this.chips});
}

/// Builds the Minimal layout's content from a combo and the current toggles.
MinimalOverlayContent computeMinimalContent(
    ComboDto combo, InstagramOverlayToggles toggles) {
  final meta = <String>[];
  if (toggles.quantity) meta.add('${combo.trickCount} TRICKS');
  if (toggles.difficulty) meta.add('${combo.totalDifficulty.round()} DIFF');
  if (toggles.rating && combo.totalRatings > 0) {
    meta.add('${combo.averageRating.toStringAsFixed(1)}★');
  }
  return MinimalOverlayContent(
    title: overlayEffectiveTitle(combo, toggles),
    metaParts: meta,
    chips: overlayChips(combo, toggles),
  );
}

/// Content for the Sequence layout: a title, a difficulty badge, a sub-line
/// (tricks/rating), and the trick chips. [isEmpty] is true only when every
/// one of these is off/absent — unlike Minimal, this layout has no filler
/// that reads fine on its own, so the consuming widget needs an explicit
/// signal to render a fallback ("nothing to show") state instead.
class SequenceOverlayContent {
  final String? title;
  final String? difficultyBadge;
  final List<String> subParts;
  final OverlayChips chips;
  final bool isEmpty;
  const SequenceOverlayContent({
    required this.title,
    required this.difficultyBadge,
    required this.subParts,
    required this.chips,
    required this.isEmpty,
  });
}

/// Builds the Sequence layout's content from a combo and the current toggles.
SequenceOverlayContent computeSequenceContent(
    ComboDto combo, InstagramOverlayToggles toggles) {
  final title = overlayEffectiveTitle(combo, toggles);
  final diffBadge =
      toggles.difficulty ? '${combo.totalDifficulty.round()}' : null;
  final sub = <String>[];
  if (toggles.quantity) sub.add('${combo.trickCount} tricks');
  if (toggles.rating && combo.totalRatings > 0) {
    sub.add(
        '${combo.averageRating.toStringAsFixed(1)}★ (${combo.totalRatings})');
  }
  final chips = overlayChips(combo, toggles);
  final isEmpty =
      title == null && diffBadge == null && sub.isEmpty && chips.shown.isEmpty;
  return SequenceOverlayContent(
    title: title,
    difficultyBadge: diffBadge,
    subParts: sub,
    chips: chips,
    isEmpty: isEmpty,
  );
}

/// One stat tile on the Stat layout, e.g. value "24", label "Diff".
class OverlayStatTile {
  final String value;
  final String label;
  const OverlayStatTile(this.value, this.label);
}

/// Content for the Stat layout: a title, up to three stat tiles
/// (Diff/Tricks/Rating, in that order), and the trick chips. [isEmpty]
/// mirrors [SequenceOverlayContent.isEmpty] — true only when title, tiles,
/// and chips are all off/absent — for the same reason: this layout has no
/// filler that reads fine on its own, so the consuming widget needs an
/// explicit signal to render a fallback ("nothing to show") state instead.
class StatOverlayContent {
  final String? title;
  final List<OverlayStatTile> tiles;
  final OverlayChips chips;
  final bool isEmpty;
  const StatOverlayContent({
    required this.title,
    required this.tiles,
    required this.chips,
    required this.isEmpty,
  });
}

/// Builds the Stat layout's content from a combo and the current toggles.
StatOverlayContent computeStatContent(
    ComboDto combo, InstagramOverlayToggles toggles) {
  final title = overlayEffectiveTitle(combo, toggles);
  final tiles = <OverlayStatTile>[];
  if (toggles.difficulty) {
    tiles.add(OverlayStatTile('${combo.totalDifficulty.round()}', 'Diff'));
  }
  if (toggles.quantity) {
    tiles.add(OverlayStatTile('${combo.trickCount}', 'Tricks'));
  }
  if (toggles.rating && combo.totalRatings > 0) {
    tiles.add(OverlayStatTile(
        '${combo.averageRating.toStringAsFixed(1)}★', 'Rating'));
  }
  final chips = overlayChips(combo, toggles);
  final isEmpty = title == null && tiles.isEmpty && chips.shown.isEmpty;
  return StatOverlayContent(
      title: title, tiles: tiles, chips: chips, isEmpty: isEmpty);
}
