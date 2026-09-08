# Share to Instagram Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Share to Instagram" option next to the existing "Share Link" on the combo detail screen that generates a full-canvas transparent PNG overlay (combo name/stats in a bottom text band, not a floating card) and hands it to Instagram's Story composer.

**Architecture:** Pure, unit-tested content-computation functions decide what text/chips/stats each of 3 layouts shows (name-fallback, chip truncation) — completely decoupled from rendering. A single `InstagramOverlay` Flutter widget (built on a fixed 220×391 logical-pixel canvas) renders those layouts and is reused for both the on-screen preview and the actual export: `RenderRepaintBoundary.toImage(pixelRatio: 1080/220)` rasterizes the exact same widget instance to ~1080×1920 real pixels. A small native iOS platform channel (mirroring the existing `WatchBridge.swift` pattern) hands the resulting PNG bytes to Instagram via `UIPasteboard` + the `instagram-stories://` URL scheme.

**Tech Stack:** Flutter/Dart (existing `google_fonts`, `AppColors` design tokens), Swift platform channel (iOS only — see Non-goals), no new package dependencies.

**Spec:** `docs/superpowers/specs/2026-09-08-instagram-share-design.md`

**Scope:** iOS only for this plan (matches the spec's flagged open question #5 — this app has only shipped iOS so far; Android's `instagram-stories://` equivalent needs separate research before it can be implemented, tracked as follow-up, not part of this plan).

---

### Task 1: Content-computation module — nameless-combo and chip-truncation logic (TDD)

**Files:**
- Create: `mobile/lib/core/models/instagram_overlay_content.dart`
- Test: `mobile/test/instagram_overlay_content_test.dart`

This task covers the two behaviors that are easy to get subtly wrong: the nameless-combo fallback, and the 20-chip truncation threshold. Later tasks build the three style-specific content functions on top of these primitives.

- [ ] **Step 1: Write the failing tests**

Create `mobile/test/instagram_overlay_content_test.dart`:

```dart
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
      expect(overlayNameToggleDisabled(_combo(name: 'Sunset Special')), isFalse);
    });
  });

  group('overlayEffectiveTitle', () {
    test('null when combo has no name, regardless of toggle', () {
      final combo = _combo(name: null);
      expect(overlayEffectiveTitle(combo, const InstagramOverlayToggles(name: true)), isNull);
    });

    test('null when combo has a name but the Name toggle is off', () {
      final combo = _combo(name: 'Sunset Special');
      expect(overlayEffectiveTitle(combo, const InstagramOverlayToggles(name: false)), isNull);
    });

    test('the name when combo has one and the toggle is on', () {
      final combo = _combo(name: 'Sunset Special');
      expect(overlayEffectiveTitle(combo, const InstagramOverlayToggles(name: true)), 'Sunset Special');
    });
  });

  group('overlaySequenceOn', () {
    test('forced on for a nameless combo even if the toggle is off', () {
      final combo = _combo(name: null);
      expect(overlaySequenceOn(combo, const InstagramOverlayToggles(sequence: false)), isTrue);
    });

    test('follows the toggle for a named combo', () {
      final combo = _combo(name: 'Sunset Special');
      expect(overlaySequenceOn(combo, const InstagramOverlayToggles(sequence: false)), isFalse);
      expect(overlaySequenceOn(combo, const InstagramOverlayToggles(sequence: true)), isTrue);
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
      final chips = overlayChips(combo, const InstagramOverlayToggles(sequence: false));
      expect(chips.shown, isEmpty);
      expect(chips.overflow, 0);
    });

    test('appends (nt) for a no-touch trick', () {
      final combo = _combo(tricks: _tricks(2, lastNoTouch: true));
      final chips = overlayChips(combo, const InstagramOverlayToggles());
      expect(chips.shown, ['T1', 'T2(nt)']);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd mobile && flutter test test/instagram_overlay_content_test.dart`
Expected: fails to compile — `instagram_overlay_content.dart` doesn't exist yet.

- [ ] **Step 3: Implement the module**

Create `mobile/lib/core/models/instagram_overlay_content.dart`:

```dart
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd mobile && flutter test test/instagram_overlay_content_test.dart`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/core/models/instagram_overlay_content.dart mobile/test/instagram_overlay_content_test.dart
git commit -m "Add nameless-combo fallback and chip-truncation logic for Instagram share"
```

---

### Task 2: Per-style content functions (TDD)

**Files:**
- Modify: `mobile/lib/core/models/instagram_overlay_content.dart`
- Modify: `mobile/test/instagram_overlay_content_test.dart`

Builds the three style-specific content computations (Minimal / Sequence / Stat) on top of Task 1's primitives, including the rule that a Rating stat/line never shows for a combo with zero ratings even if the toggle is on (showing "0.0★" on an unrated combo would be misleading — this wasn't in the original mockup, which used fixed mock data that always had ratings, but is a real edge case the implementation must handle).

- [ ] **Step 1: Write the failing tests**

Append to `mobile/test/instagram_overlay_content_test.dart` (inside `void main() { ... }`, after the existing groups):

```dart
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
      final combo = _combo(name: 'Sunset Special', averageRating: 0, totalRatings: 0);
      final content = computeMinimalContent(
        combo,
        const InstagramOverlayToggles(rating: true),
      );
      expect(content.metaParts, isNot(contains(contains('★'))));
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
      final combo = _combo(name: 'Sunset Special', averageRating: 0, totalRatings: 0);
      final content = computeStatContent(
        combo,
        const InstagramOverlayToggles(rating: true),
      );
      expect(content.tiles.map((t) => t.label), ['Diff', 'Tricks']);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd mobile && flutter test test/instagram_overlay_content_test.dart`
Expected: fails to compile — `computeMinimalContent`, `computeSequenceContent`, `computeStatContent`, `OverlayStatTile`, `MinimalOverlayContent`, `SequenceOverlayContent`, `StatOverlayContent` don't exist yet.

- [ ] **Step 3: Implement the per-style functions**

Append to `mobile/lib/core/models/instagram_overlay_content.dart`:

```dart
class MinimalOverlayContent {
  final String? title;
  final List<String> metaParts;
  final OverlayChips chips;
  const MinimalOverlayContent({required this.title, required this.metaParts, required this.chips});
}

MinimalOverlayContent computeMinimalContent(ComboDto combo, InstagramOverlayToggles toggles) {
  final meta = <String>[];
  if (toggles.quantity) meta.add('${combo.trickCount} TRICKS');
  if (toggles.difficulty) meta.add('${combo.totalDifficulty.round()} DIFF');
  if (toggles.rating && combo.totalRatings > 0) meta.add('${combo.averageRating.toStringAsFixed(1)}★');
  return MinimalOverlayContent(
    title: overlayEffectiveTitle(combo, toggles),
    metaParts: meta,
    chips: overlayChips(combo, toggles),
  );
}

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

SequenceOverlayContent computeSequenceContent(ComboDto combo, InstagramOverlayToggles toggles) {
  final title = overlayEffectiveTitle(combo, toggles);
  final diffBadge = toggles.difficulty ? '${combo.totalDifficulty.round()}' : null;
  final sub = <String>[];
  if (toggles.quantity) sub.add('${combo.trickCount} tricks');
  if (toggles.rating && combo.totalRatings > 0) {
    sub.add('${combo.averageRating.toStringAsFixed(1)}★ (${combo.totalRatings})');
  }
  final chips = overlayChips(combo, toggles);
  final isEmpty = title == null && diffBadge == null && sub.isEmpty && chips.shown.isEmpty;
  return SequenceOverlayContent(
    title: title,
    difficultyBadge: diffBadge,
    subParts: sub,
    chips: chips,
    isEmpty: isEmpty,
  );
}

class OverlayStatTile {
  final String value;
  final String label;
  const OverlayStatTile(this.value, this.label);
}

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

StatOverlayContent computeStatContent(ComboDto combo, InstagramOverlayToggles toggles) {
  final title = overlayEffectiveTitle(combo, toggles);
  final tiles = <OverlayStatTile>[];
  if (toggles.difficulty) tiles.add(OverlayStatTile('${combo.totalDifficulty.round()}', 'Diff'));
  if (toggles.quantity) tiles.add(OverlayStatTile('${combo.trickCount}', 'Tricks'));
  if (toggles.rating && combo.totalRatings > 0) {
    tiles.add(OverlayStatTile('${combo.averageRating.toStringAsFixed(1)}★', 'Rating'));
  }
  final chips = overlayChips(combo, toggles);
  final isEmpty = title == null && tiles.isEmpty && chips.shown.isEmpty;
  return StatOverlayContent(title: title, tiles: tiles, chips: chips, isEmpty: isEmpty);
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd mobile && flutter test test/instagram_overlay_content_test.dart`
Expected: all tests pass.

- [ ] **Step 5: Run the full test suite to check for regressions**

Run: `cd mobile && flutter test`
Expected: all tests pass (existing `widget_test.dart` and `revolution_range_test.dart` untouched).

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/core/models/instagram_overlay_content.dart mobile/test/instagram_overlay_content_test.dart
git commit -m "Add per-style content computation for Instagram share overlay"
```

---

### Task 3: The overlay widget

**Files:**
- Create: `mobile/lib/features/combos/instagram_share/instagram_overlay.dart`

Builds the actual rendered overlay: a fixed 220×391-logical-pixel, **fully transparent** widget (no background of its own — the picker sheet in Task 6 supplies a decorative preview backdrop *around*, not *inside*, this widget, so the real exported PNG stays transparent). Reuses the app's existing design tokens (`AppColors`, `google_fonts`).

- [ ] **Step 1: Create the widget file**

Create `mobile/lib/features/combos/instagram_share/instagram_overlay.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/combo.dart';
import '../../../core/models/instagram_overlay_content.dart';
import '../../../theme/app_colors.dart';

/// Base design canvas — captured via
/// RenderRepaintBoundary.toImage(pixelRatio: kInstagramOverlayExportPixelRatio)
/// to rasterize at ~1080x1920 real pixels. See InstagramShareService.
const double kInstagramOverlayWidth = 220;
const double kInstagramOverlayHeight = 391;
const double kInstagramOverlayExportPixelRatio = 1080 / kInstagramOverlayWidth;

/// The overlay content itself — fully transparent except the bottom text
/// band, so it composites over the person's own photo/video in Instagram
/// rather than sitting on top of it as an opaque card. Deliberately has no
/// background decoration of its own.
class InstagramOverlay extends StatelessWidget {
  final ComboDto combo;
  final InstagramOverlayStyle style;
  final InstagramOverlayToggles toggles;
  final InstagramTextSize textSize;

  const InstagramOverlay({
    super.key,
    required this.combo,
    required this.style,
    required this.toggles,
    required this.textSize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kInstagramOverlayWidth,
      height: kInstagramOverlayHeight,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: kInstagramOverlayHeight * 0.44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
              child: _buildContent(),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 3.5,
                  height: 3.5,
                  decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
                ),
                const SizedBox(width: 3),
                Text(
                  'FSCOMBO',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 6.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (style) {
      case InstagramOverlayStyle.minimal:
        return _MinimalContent(content: computeMinimalContent(combo, toggles), scale: textSize.scale);
      case InstagramOverlayStyle.sequence:
        return _SequenceContent(content: computeSequenceContent(combo, toggles), scale: textSize.scale);
      case InstagramOverlayStyle.stat:
        return _StatContent(content: computeStatContent(combo, toggles), scale: textSize.scale);
    }
  }
}

class _ChipRow extends StatelessWidget {
  final OverlayChips chips;
  final double scale;
  const _ChipRow({required this.chips, required this.scale});

  @override
  Widget build(BuildContext context) {
    if (chips.shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 9 * scale),
      child: Wrap(
        spacing: 4 * scale,
        runSpacing: 4 * scale,
        children: [
          for (final t in chips.shown)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.5 * scale, vertical: 3.5 * scale),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                borderRadius: BorderRadius.circular(5 * scale),
              ),
              child: Text(
                t,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 7.5 * scale,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          if (chips.overflow > 0)
            Padding(
              padding: const EdgeInsets.only(left: 1),
              child: Text(
                '+${chips.overflow} more',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 7.5 * scale,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _kTextShadow = [Shadow(blurRadius: 12, color: Colors.black54, offset: Offset(0, 2))];

class _MinimalContent extends StatelessWidget {
  final MinimalOverlayContent content;
  final double scale;
  const _MinimalContent({required this.content, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (content.title != null)
          Text(
            content.title!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15 * scale,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              height: 1.18,
              color: Colors.white,
              shadows: _kTextShadow,
            ),
          ),
        if (content.metaParts.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: content.title != null ? 6 * scale : 0),
            child: Text(
              content.metaParts.join(' · '),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9 * scale,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        _ChipRow(chips: content.chips, scale: scale),
      ],
    );
  }
}

class _SequenceContent extends StatelessWidget {
  final SequenceOverlayContent content;
  final double scale;
  const _SequenceContent({required this.content, required this.scale});

  @override
  Widget build(BuildContext context) {
    final hasNameRow = content.title != null || content.difficultyBadge != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasNameRow)
          Row(
            mainAxisAlignment: content.title != null ? MainAxisAlignment.start : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (content.title != null)
                Flexible(
                  child: Text(
                    content.title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5 * scale,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: Colors.white,
                      shadows: _kTextShadow,
                    ),
                  ),
                ),
              if (content.difficultyBadge != null) ...[
                if (content.title != null) SizedBox(width: 8 * scale),
                Text(
                  content.difficultyBadge!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5 * scale,
                    fontWeight: FontWeight.w800,
                    color: AppColors.lime,
                  ),
                ),
              ],
            ],
          ),
        if (content.subParts.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: hasNameRow ? 6 * scale : 0),
            child: Text(
              content.subParts.join(' · '),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9 * scale,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        _ChipRow(chips: content.chips, scale: scale),
        if (content.isEmpty)
          Text(
            'No stats selected',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9 * scale,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
      ],
    );
  }
}

class _StatContent extends StatelessWidget {
  final StatOverlayContent content;
  final double scale;
  const _StatContent({required this.content, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (content.title != null)
          Text(
            content.title!.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5 * scale,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        if (content.tiles.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 3 * scale),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final tile in content.tiles)
                  Padding(
                    padding: EdgeInsets.only(right: 16 * scale),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tile.value,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 19 * scale,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: _kTextShadow,
                          ),
                        ),
                        Text(
                          tile.label.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 7.5 * scale,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        _ChipRow(chips: content.chips, scale: scale),
        if (content.isEmpty)
          Text(
            'No stats selected',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9 * scale,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd mobile && flutter analyze lib/features/combos/instagram_share/instagram_overlay.dart`
Expected: no errors (info-level lints about `const`/`key` are fine — check against the existing baseline with `flutter analyze` from Task 8 before treating any as new).

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/features/combos/instagram_share/instagram_overlay.dart
git commit -m "Add the Instagram overlay widget (3 layouts, transparent canvas)"
```

---

### Task 4: Image capture + native handoff service

**Files:**
- Create: `mobile/lib/features/combos/instagram_share/instagram_share_service.dart`

- [ ] **Step 1: Create the service**

Create `mobile/lib/features/combos/instagram_share/instagram_share_service.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Captures the widget behind a RepaintBoundary as a PNG and hands it to
/// Instagram's Story composer via a native platform channel (see
/// ios/Runner/InstagramShareBridge.swift).
class InstagramShareService {
  static const _channel = MethodChannel('com.rafaelffs.freestyleCombo/instagram_share');

  static Future<void> shareToStory(GlobalKey boundaryKey, {required double pixelRatio}) async {
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Nothing to share yet — try again.');
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Could not generate the image.');
    }
    final Uint8List pngBytes = byteData.buffer.asUint8List();

    try {
      await _channel.invokeMethod('shareToInstagramStory', {'image': pngBytes});
    } on PlatformException catch (e) {
      if (e.code == 'not_installed') {
        throw Exception('Install Instagram to share to your Story.');
      }
      throw Exception(e.message ?? 'Could not open Instagram.');
    }
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd mobile && flutter analyze lib/features/combos/instagram_share/instagram_share_service.dart`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/features/combos/instagram_share/instagram_share_service.dart
git commit -m "Add the image-capture and Instagram handoff service"
```

---

### Task 5: Native iOS bridge

**Files:**
- Create: `mobile/ios/Runner/InstagramShareBridge.swift`
- Modify: `mobile/ios/Runner/AppDelegate.swift`
- Modify: `mobile/ios/Runner/Info.plist`

Mirrors the existing `WatchBridge.swift` platform-channel pattern (`mobile/ios/Runner/WatchBridge.swift`, registered in `AppDelegate.swift`'s `didInitializeImplicitFlutterEngine`).

- [ ] **Step 1: Create the native bridge**

Create `mobile/ios/Runner/InstagramShareBridge.swift`:

```swift
import Flutter
import UIKit

/// Hands a PNG image to Instagram's Story composer via the documented
/// sticker-share mechanism: place the image on the pasteboard under
/// Instagram's well-known key, then open the instagram-stories:// URL
/// scheme. Instagram reads the pasteboard item itself — there's no
/// response payload, just success/failure of opening the URL.
final class InstagramShareBridge: NSObject {
    static let shared = InstagramShareBridge()

    func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.rafaelffs.freestyleCombo/instagram_share",
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "shareToInstagramStory":
                guard
                    let args = call.arguments as? [String: Any],
                    let imageData = args["image"] as? FlutterStandardTypedData
                else {
                    result(FlutterError(code: "bad_args", message: "image required", details: nil))
                    return
                }
                self.share(pngData: imageData.data, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func share(pngData: Data, result: @escaping FlutterResult) {
        guard
            let bundleId = Bundle.main.bundleIdentifier,
            let urlScheme = URL(string: "instagram-stories://share?source_application=\(bundleId)"),
            UIApplication.shared.canOpenURL(urlScheme)
        else {
            result(FlutterError(code: "not_installed", message: "Instagram is not installed", details: nil))
            return
        }

        let pasteboardItems: [String: Any] = [
            "com.instagram.sharedSticker.stickerImage": pngData
        ]
        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5)
        ]
        UIPasteboard.general.setItems([pasteboardItems], options: pasteboardOptions)

        UIApplication.shared.open(urlScheme, options: [:]) { success in
            if success {
                result(nil)
            } else {
                result(FlutterError(code: "open_failed", message: "Could not open Instagram", details: nil))
            }
        }
    }
}
```

- [ ] **Step 2: Register the bridge in AppDelegate**

In `mobile/ios/Runner/AppDelegate.swift`, find:

```swift
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WatchBridge") {
      WatchBridge.shared.register(with: registrar)
    }
  }
```

Replace with:

```swift
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WatchBridge") {
      WatchBridge.shared.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "InstagramShareBridge") {
      InstagramShareBridge.shared.register(with: registrar)
    }
  }
```

- [ ] **Step 3: Declare the URL scheme query in Info.plist**

In `mobile/ios/Runner/Info.plist`, iOS refuses `canOpenURL` for a scheme not declared in `LSApplicationQueriesSchemes` (silently returns false instead of erroring) — this key doesn't exist in the file yet. Find:

```xml
	<key>ITSAppUsesNonExemptEncryption</key>
	<false/>
	<key>LSRequiresIPhoneOS</key>
	<true/>
```

Replace with:

```xml
	<key>ITSAppUsesNonExemptEncryption</key>
	<false/>
	<key>LSApplicationQueriesSchemes</key>
	<array>
		<string>instagram-stories</string>
	</array>
	<key>LSRequiresIPhoneOS</key>
	<true/>
```

- [ ] **Step 4: Verify the iOS project still builds**

Run: `cd mobile && flutter build ios --no-codesign --simulator`
Expected: build succeeds (this compiles the new Swift file and validates the Info.plist edit without needing a signing identity).

- [ ] **Step 5: Commit**

```bash
git add mobile/ios/Runner/InstagramShareBridge.swift mobile/ios/Runner/AppDelegate.swift mobile/ios/Runner/Info.plist
git commit -m "Add native iOS bridge for Instagram Story sharing"
```

---

### Task 6: The share picker sheet

**Files:**
- Create: `mobile/lib/features/combos/instagram_share/instagram_share_sheet.dart`

The style/toggles/text-size picker, with a live preview built from the same `InstagramOverlay` widget used for export.

- [ ] **Step 1: Create the sheet**

Create `mobile/lib/features/combos/instagram_share/instagram_share_sheet.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/combo.dart';
import '../../../core/models/instagram_overlay_content.dart';
import '../../../theme/app_colors.dart';
import 'instagram_overlay.dart';
import 'instagram_share_service.dart';

Future<void> showInstagramShareSheet(BuildContext context, ComboDto combo) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _InstagramShareSheet(combo: combo),
  );
}

class _InstagramShareSheet extends StatefulWidget {
  final ComboDto combo;
  const _InstagramShareSheet({required this.combo});

  @override
  State<_InstagramShareSheet> createState() => _InstagramShareSheetState();
}

class _InstagramShareSheetState extends State<_InstagramShareSheet> {
  final _boundaryKey = GlobalKey();
  InstagramOverlayStyle _style = InstagramOverlayStyle.sequence;
  InstagramTextSize _textSize = InstagramTextSize.medium;
  InstagramOverlayToggles _toggles = const InstagramOverlayToggles();
  bool _sending = false;
  String? _error;

  bool get _nameDisabled => overlayNameToggleDisabled(widget.combo);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Share to Instagram',
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 20),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF5B3A7A), Color(0xFF2C2350)],
                    ),
                  ),
                  // The gradient above is preview-only decoration standing in
                  // for the person's real photo/video — it sits OUTSIDE the
                  // RepaintBoundary, so the actual captured/exported image
                  // (Task 4) stays fully transparent there.
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: InstagramOverlay(
                      combo: widget.combo,
                      style: _style,
                      toggles: _toggles,
                      textSize: _textSize,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('LAYOUT', style: _sectionLabelStyle),
            const SizedBox(height: 10),
            _styleRow(),
            const SizedBox(height: 22),
            Text('SHOW ON OVERLAY', style: _sectionLabelStyle),
            const SizedBox(height: 10),
            _toggleRow('Combo name', _toggles.name, _nameDisabled, (v) => setState(() => _toggles = _toggles.copyWith(name: v))),
            _toggleRow('Difficulty', _toggles.difficulty, false, (v) => setState(() => _toggles = _toggles.copyWith(difficulty: v))),
            _toggleRow('Trick count', _toggles.quantity, false, (v) => setState(() => _toggles = _toggles.copyWith(quantity: v))),
            _toggleRow('Rating', _toggles.rating, false, (v) => setState(() => _toggles = _toggles.copyWith(rating: v))),
            _toggleRow('Trick sequence', _toggles.sequence, false, (v) => setState(() => _toggles = _toggles.copyWith(sequence: v))),
            const SizedBox(height: 22),
            Text('TEXT SIZE', style: _sectionLabelStyle),
            const SizedBox(height: 10),
            _sizeRow(),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
              ),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _sending ? null : _addToStory,
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Add to Story',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _sectionLabelStyle => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AppColors.faint,
      );

  Widget _chipRow<T>(List<(T, String)> options, T selected, ValueChanged<T> onSelected) {
    return Wrap(
      spacing: 8,
      children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: selected == value,
            onSelected: (_) => onSelected(value),
            selectedColor: AppColors.indigoTint,
            backgroundColor: AppColors.surface,
            labelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected == value ? AppColors.indigo : AppColors.ink2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(color: selected == value ? AppColors.indigo : AppColors.line2),
            ),
          ),
      ],
    );
  }

  Widget _styleRow() {
    return _chipRow<InstagramOverlayStyle>(
      const [
        (InstagramOverlayStyle.minimal, 'Minimal'),
        (InstagramOverlayStyle.sequence, 'Sequence'),
        (InstagramOverlayStyle.stat, 'Stat'),
      ],
      _style,
      (v) => setState(() => _style = v),
    );
  }

  Widget _sizeRow() {
    return _chipRow<InstagramTextSize>(
      const [
        (InstagramTextSize.small, 'Small'),
        (InstagramTextSize.medium, 'Medium'),
        (InstagramTextSize.large, 'Large'),
      ],
      _textSize,
      (v) => setState(() => _textSize = v),
    );
  }

  Widget _toggleRow(String label, bool value, bool disabled, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: disabled ? AppColors.faint : AppColors.ink2,
              ),
            ),
          ),
          CupertinoSwitch(
            value: disabled ? false : value,
            activeTrackColor: AppColors.indigo,
            onChanged: disabled ? null : onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _addToStory() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await InstagramShareService.shareToStory(_boundaryKey, pixelRatio: kInstagramOverlayExportPixelRatio);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd mobile && flutter analyze lib/features/combos/instagram_share/instagram_share_sheet.dart`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/features/combos/instagram_share/instagram_share_sheet.dart
git commit -m "Add the Instagram share style/toggles/size picker sheet"
```

---

### Task 7: The share-options entry sheet

**Files:**
- Create: `mobile/lib/features/combos/instagram_share/share_options_sheet.dart`
- Test: `mobile/test/share_options_sheet_test.dart`

The sheet the existing share button now opens first — "Share Link" (existing behavior, passed in as a callback) vs. "Share to Instagram" (opens Task 6's sheet directly).

- [ ] **Step 1: Write the failing test**

Create `mobile/test/share_options_sheet_test.dart`:

```dart
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
  testWidgets('shows both Share Link and Share to Instagram options', (tester) async {
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

    expect(find.text('Share Link'), findsOneWidget);
    expect(find.text('Share to Instagram'), findsOneWidget);

    await tester.tap(find.text('Share Link'));
    await tester.pumpAndSettle();
    expect(linkTapped, isTrue);
  });

  testWidgets('tapping Share to Instagram opens the style picker', (tester) async {
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
    await tester.tap(find.text('Share to Instagram'));
    await tester.pumpAndSettle();

    expect(find.text('Add to Story'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd mobile && flutter test test/share_options_sheet_test.dart`
Expected: fails to compile — `share_options_sheet.dart` doesn't exist yet.

- [ ] **Step 3: Implement the sheet**

Create `mobile/lib/features/combos/instagram_share/share_options_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/combo.dart';
import '../../../theme/app_colors.dart';
import 'instagram_share_sheet.dart';

/// Shows the "Share Link" vs. "Share to Instagram" choice — the existing
/// share icon opens this instead of firing Share.share directly.
/// [onShareLink] runs the existing link-share flow unchanged; Instagram
/// opens the style/stats picker (instagram_share_sheet.dart) directly.
Future<void> showShareOptionsSheet(
  BuildContext context, {
  required ComboDto combo,
  required VoidCallback onShareLink,
}) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Share "${combo.name ?? combo.displayText}"',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.faint,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ShareOptionTile(
            iconBackground: AppColors.indigoTint,
            icon: const Icon(Icons.link, color: AppColors.indigo),
            title: 'Share Link',
            subtitle: 'Copy or send the combo page',
            onTap: () {
              Navigator.pop(sheetContext);
              onShareLink();
            },
          ),
          _ShareOptionTile(
            iconGradient: const LinearGradient(
              colors: [Color(0xFFFEDA75), Color(0xFFD62976), Color(0xFF4F5BD5)],
            ),
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
            title: 'Share to Instagram',
            subtitle: 'Create a story overlay',
            onTap: () {
              Navigator.pop(sheetContext);
              showInstagramShareSheet(context, combo);
            },
          ),
        ],
      ),
    ),
  );
}

class _ShareOptionTile extends StatelessWidget {
  final Color? iconBackground;
  final Gradient? iconGradient;
  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOptionTile({
    this.iconBackground,
    this.iconGradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBackground,
                gradient: iconGradient,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 1),
                  Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd mobile && flutter test test/share_options_sheet_test.dart`
Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/combos/instagram_share/share_options_sheet.dart mobile/test/share_options_sheet_test.dart
git commit -m "Add the Share Link / Share to Instagram entry sheet"
```

---

### Task 8: Wire up the existing share button

**Files:**
- Modify: `mobile/lib/features/combos/combo_detail_screen.dart`

- [ ] **Step 1: Add the import**

In `mobile/lib/features/combos/combo_detail_screen.dart`, find the existing import block (near the top, alongside the other feature/widget imports):

```dart
import '../../widgets/setting_icon_button.dart';
```

Add directly after it:

```dart
import 'instagram_share/share_options_sheet.dart';
```

- [ ] **Step 2: Split `_shareCombo` into the options-sheet opener and the link-share flow**

Find:

```dart
  Future<void> _shareCombo(ComboDto combo) async {
    final url = '$kWebOrigin/share/combos/${combo.id}';
    // iOS requires a non-zero sharePositionOrigin (the share sheet's popover
    // anchor) — without it the native call throws PlatformException instead
    // of presenting anything, even on iPhone.
    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? (box.localToGlobal(Offset.zero) & box.size)
        : const Rect.fromLTWH(0, 0, 1, 1); // just needs to be non-zero; only affects iPad popover arrow position
    await Share.share(url, subject: combo.name ?? combo.displayText, sharePositionOrigin: origin);
  }
```

Replace with:

```dart
  Future<void> _openShareOptions(ComboDto combo) {
    return showShareOptionsSheet(
      context,
      combo: combo,
      onShareLink: () => _shareLinkCombo(combo),
    );
  }

  Future<void> _shareLinkCombo(ComboDto combo) async {
    final url = '$kWebOrigin/share/combos/${combo.id}';
    // iOS requires a non-zero sharePositionOrigin (the share sheet's popover
    // anchor) — without it the native call throws PlatformException instead
    // of presenting anything, even on iPhone.
    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? (box.localToGlobal(Offset.zero) & box.size)
        : const Rect.fromLTWH(0, 0, 1, 1); // just needs to be non-zero; only affects iPad popover arrow position
    await Share.share(url, subject: combo.name ?? combo.displayText, sharePositionOrigin: origin);
  }
```

- [ ] **Step 3: Update the hero button's callback**

Find:

```dart
                  onShare: () => _shareCombo(combo),
```

Replace with:

```dart
                  onShare: () => _openShareOptions(combo),
```

- [ ] **Step 4: Verify it compiles and the existing test suite still passes**

Run: `cd mobile && flutter analyze lib/features/combos/combo_detail_screen.dart`
Expected: no new errors (compare against the pre-existing lint baseline — this file already has some `info`-level lints per `CLAUDE.md`'s known baseline; only new *errors* matter here).

Run: `cd mobile && flutter test`
Expected: all tests pass, including the new `instagram_overlay_content_test.dart` and `share_options_sheet_test.dart` from earlier tasks.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/combos/combo_detail_screen.dart
git commit -m "Wire the combo detail share button to the new share-options sheet"
```

---

### Task 9: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

Per this repo's own standing instruction ("Whenever you make a change that affects documented behavior... update the relevant section of this file"), document the new feature alongside the existing "Combo link sharing" section.

- [ ] **Step 1: Add a new subsection**

In `CLAUDE.md`, find the `#### Combo link sharing` section (under "### Combos extra endpoints"). Directly after that section's final paragraph (the one ending "...the desktop clipboard-copy fallback copies the plain `/combos/{id}` SPA URL directly."), add a new subsection:

```markdown
#### Share to Instagram (mobile only)

A second option alongside "Share Link" on the combo detail screen's share button (`combo_detail_screen.dart`'s `_openShareOptions` now opens `share_options_sheet.dart`'s choice sheet instead of calling `Share.share` directly). Generates a **full Story-canvas-sized transparent PNG** (not a small floating card) — the combo name/stats sit in a bottom text band over a black-to-transparent scrim; everywhere else stays transparent so the person's own photo/video shows through. Handed to Instagram via the native `instagram-stories://` sticker-share mechanism (`UIPasteboard` + a platform channel, `ios/Runner/InstagramShareBridge.swift`, mirroring the existing `WatchBridge.swift` pattern) — Instagram still lets the person nudge/resize it like any sticker, but since it matches the canvas exactly it starts already filling the screen.

Three layouts (`InstagramOverlayStyle`: Minimal/Sequence/Stat) share five independent display toggles (`InstagramOverlayToggles`: name/difficulty/quantity/rating/sequence — `mobile/lib/core/models/instagram_overlay_content.dart`) and a three-way text-size multiplier (`InstagramTextSize`: small/medium/large, applied to every overlay text element except the fixed-size FSCOMBO wordmark). A nameless combo (same fallback convention as the rest of the app — see "Tricks API" above) always shows its trick sequence instead of a title, and the Name toggle becomes non-interactive since there's nothing to hide. The chip list shows the entire trick sequence up to 20 tricks before collapsing to a "+N more" summary — deliberately generous, since the app's own random-unset-field default range only goes up to 20 (see "Unset-field resolution during generation" above).

The same `InstagramOverlay` widget instance renders both the live on-screen preview (`instagram_share_sheet.dart`) and the actual export — `RenderRepaintBoundary.toImage(pixelRatio: 1080/220)` rasterizes the fixed 220×391-logical-pixel canvas to ~1080×1920 real pixels, entirely client-side (no server round-trip, works offline). See `docs/superpowers/specs/2026-09-08-instagram-share-design.md` for the full design rationale.

**iOS only.** The sticker-share mechanism needs native pasteboard access, not available from a web browser — no web entry point exists or is planned. Android's `instagram-stories://` equivalent hasn't been implemented or verified yet (this app has only shipped iOS so far — see "Production Deployment" below) — tracked as a follow-up, not yet started.
```

- [ ] **Step 2: Add the new Info.plist key to context if this repo documents plist keys elsewhere**

Check whether `CLAUDE.md` documents `Info.plist` keys anywhere else in the file (search for `LSApplicationQueriesSchemes` or `CFBundleURLTypes` mentions outside the section just edited):

Run: `grep -n "LSApplicationQueriesSchemes\|CFBundleURLTypes" CLAUDE.md`

If the only matches are inside the section just added, no further edit is needed — the plist change is already covered there. If `CFBundleURLTypes` or similar is documented elsewhere (e.g. a dedicated "iOS configuration" list), add a one-line mention of `LSApplicationQueriesSchemes: ["instagram-stories"]` there too for consistency.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "Document the Share to Instagram feature in CLAUDE.md"
```

---

### Task 10: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run the full mobile test suite**

Run: `cd mobile && flutter test`
Expected: all tests pass — the pre-existing 2 files plus the new `instagram_overlay_content_test.dart` and `share_options_sheet_test.dart`.

- [ ] **Step 2: Run the full analyzer**

Run: `cd mobile && flutter analyze`
Expected: 0 errors. Compare the info/warning count against the pre-existing baseline documented in this session (20 pre-existing info-level lints as of the last full run) — flag any *new* warnings/errors, don't just check the exit code.

- [ ] **Step 3: Build for iOS simulator**

Run: `cd mobile && flutter build ios --no-codesign --simulator`
Expected: build succeeds, confirming the new Swift file and Info.plist changes are structurally valid.

- [ ] **Step 4: Manual device verification (cannot be automated)**

The actual Instagram handoff can only be verified against the real Instagram app on a device/simulator with Instagram installed — there is no way to script this. Document in the PR/handoff notes that this step is outstanding:

1. Run the app on a simulator or device that has Instagram installed (`flutter run`).
2. Open any combo's detail screen, tap Share → Share to Instagram.
3. Pick each of the 3 layouts, toggle each of the 5 stats on/off, try all 3 text sizes — confirm the live preview updates correctly and matches the approved mockup's visual intent (`docs/superpowers/specs/2026-09-08-instagram-share-design.md`).
4. Test with a nameless combo (build one manually with no name) — confirm no title shows, the Name toggle is disabled, and the chip row is forced on.
5. Test with a combo that has more than 20 tricks — confirm the "+N more" summary appears.
6. Tap "Add to Story" — confirm Instagram opens with the overlay correctly positioned as a sticker over the camera/gallery view, transparent everywhere but the text band.
7. Test with Instagram *not* installed (or a simulator without it) — confirm the sheet shows a clear "Install Instagram to share to your Story." error instead of crashing or hanging.

- [ ] **Step 5: Final commit if any fixes were needed during manual verification**

If manual verification surfaces issues, fix them, re-run steps 1-3, and commit:

```bash
git add -A
git commit -m "Fix issues found during manual Instagram share verification"
```

---

## Explicit non-goals (from the spec)

- Web support — no entry point, no fallback download flow.
- Persisting a chosen style/toggle/size combination as a default for next time.
- Custom backgrounds or in-app camera capture — Instagram's own composer handles that entirely.
- Android — flagged as a follow-up requiring separate research into the Android equivalent of the `instagram-stories://` mechanism; not started here.
