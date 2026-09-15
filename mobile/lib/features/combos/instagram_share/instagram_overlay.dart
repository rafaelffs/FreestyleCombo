import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/combo.dart';
import '../../../core/models/instagram_overlay_content.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/brand_mark.dart';

/// Base design canvas — captured via
/// RenderRepaintBoundary.toImage(pixelRatio: kInstagramOverlayExportPixelRatio)
/// to rasterize at ~1080x1920 real pixels. See InstagramShareService.
const double kInstagramOverlayWidth = 220;
const double kInstagramOverlayHeight = 391;
const double kInstagramOverlayExportPixelRatio = 1080 / kInstagramOverlayWidth;

// The leading gap `contentPadding` puts between the content and the far
// (non-edge) side of the column — see its EdgeInsets.fromLTRB call below.
// Kept as one named constant so the scrim math and the padding it's
// describing can't drift out of sync.
const double _kContentLeadingGap = 20;

/// The overlay content itself — fully transparent except the text band
/// (top or bottom, see [position]), so it composites over the person's own
/// photo/video in Instagram rather than sitting on top of it as an opaque
/// card. Deliberately has no background decoration of its own.
class InstagramOverlay extends StatefulWidget {
  final ComboDto combo;
  final InstagramOverlayStyle style;
  final InstagramOverlayToggles toggles;
  final InstagramTextSize textSize;
  final InstagramOverlayPosition position;

  const InstagramOverlay({
    super.key,
    required this.combo,
    required this.style,
    required this.toggles,
    required this.textSize,
    this.position = InstagramOverlayPosition.bottom,
  });

  @override
  State<InstagramOverlay> createState() => _InstagramOverlayState();
}

class _InstagramOverlayState extends State<InstagramOverlay> {
  // Height of the actual rendered content+wordmark column, measured after
  // layout (see _MeasureSize below) — null until the first frame. Falls
  // back to a reasonable estimate for that first frame so there's no
  // flash of an unscrimmed image before the real measurement lands.
  double? _measuredHeight;

  // Height of just the text/chips content, excluding the wordmark row and
  // the fixed padding around both — used to scale the *fade* portion of
  // the scrim. Using the whole-column height (above) for that too made the
  // fade grow with fixed layout padding, not just with how much text was
  // actually showing, so it read as an oversized grey wash even for short
  // content — this keeps the fade tied to the real text only.
  double? _measuredContentOnlyHeight;

  @override
  Widget build(BuildContext context) {
    final isTop = widget.position == InstagramOverlayPosition.top;

    // Content and the wordmark share one Column, edge-anchored per
    // [position] — the wordmark always sits closest to the outer screen
    // edge (bottom-most when the band is at the bottom, top-most when it's
    // at the top), with content filling in toward the canvas center.
    // Flutter's layout guarantees the two never overlap, since it's one
    // ordered Column rather than two independently-positioned Stack
    // children that could visually collide if content grew tall enough to
    // reach the wordmark's fixed corner position.
    final contentPadding = Padding(
      padding: EdgeInsets.fromLTRB(
          18, isTop ? 0 : _kContentLeadingGap, 18, isTop ? _kContentLeadingGap : 0),
      child: _MeasureSize(
        onChange: (size) {
          if (size.height != _measuredContentOnlyHeight) {
            setState(() => _measuredContentOnlyHeight = size.height);
          }
        },
        child: _buildContent(),
      ),
    );
    final wordmarkPadding = Padding(
      // Extra top clearance only when the band is at the top: Instagram's
      // own Story UI (profile picture, username, close button) sits right
      // along the true top edge, on top of everything including this
      // sticker — without it, that chrome would sit directly over the
      // wordmark/combo text instead of over empty video.
      padding: EdgeInsets.only(top: isTop ? 34 : 8, right: 8, bottom: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(
              size: 7,
              markColor: Colors.white.withValues(alpha: 0.85),
              boltColor: AppColors.lime,
            ),
            const SizedBox(width: 2),
            Text(
              'FSCOMBO',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 3.2,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );

    // Scrim sizing derived from the actual measured content height, not a
    // fixed fraction of the canvas — so a bigger text size or more toggled-
    // on stats (taller content) gets a proportionally bigger scrim, and a
    // small Minimal layout at Smallest text doesn't get an oversized one.
    //
    // `solidHeight` is held at full weight — it only needs to cover the
    // wordmark and the actual text/chips, i.e. the whole measured column
    // *minus* the content's own leading gap (`_kContentLeadingGap`, the 20
    // set on `contentPadding` above — on the far side of the content from
    // the true edge in both [position]s, so it's not covering anything).
    // Folding that gap into the flat zone (as an earlier version did, by
    // using the whole column for `solidHeight`) left a wide band of solid
    // color with no text anywhere near it, which is what read as an
    // oversized, mostly-empty grey wash. `fadeHeight` reclaims that gap as
    // actual fade room, plus a bit more scaled off `contentOnlyHeight` (the
    // text/chips alone) so a taller/bigger-text layout still gets a
    // correspondingly longer fade.
    const fadeRatio = 0.2;
    final measuredColumn = _measuredHeight ?? kInstagramOverlayHeight * 0.3;
    final contentOnlyHeight = _measuredContentOnlyHeight ?? measuredColumn * 0.6;
    final solidHeight = (measuredColumn - _kContentLeadingGap).clamp(0.0, measuredColumn);
    final fadeHeight = _kContentLeadingGap + contentOnlyHeight * fadeRatio;
    final scrimHeight = (solidHeight + fadeHeight)
        .clamp(kInstagramOverlayHeight * 0.14, kInstagramOverlayHeight * 0.55);
    final flatStop = (solidHeight / (solidHeight + fadeHeight)).clamp(0.1, 0.92);

    return SizedBox(
      width: kInstagramOverlayWidth,
      height: kInstagramOverlayHeight,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: isTop ? 0 : null,
            bottom: isTop ? null : 0,
            // Held at full weight right behind the text (plus a small
            // buffer) then falling off over a proportional distance — a
            // slow ramp across a tall fixed band reads as grey across most
            // of the image, which is what was washing out video
            // backgrounds; sizing it off the real content instead keeps
            // that same tight look no matter how much text is showing.
            height: scrimHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
                  end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0),
                  ],
                  stops: [0, flatStop, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: isTop ? 0 : null,
            bottom: isTop ? null : 0,
            child: _MeasureSize(
              onChange: (size) {
                if (size.height != _measuredHeight) {
                  setState(() => _measuredHeight = size.height);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                // Stretch so both children get the full canvas width — the
                // content Padding needs it to stay left-anchored (its own
                // inner Column uses CrossAxisAlignment.start), and the
                // wordmark's Align(centerRight) needs it to actually reach
                // the right edge rather than shrink-wrapping to nothing.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: isTop
                    ? [wordmarkPadding, contentPadding]
                    : [contentPadding, wordmarkPadding],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final isTop = widget.position == InstagramOverlayPosition.top;
    switch (widget.style) {
      case InstagramOverlayStyle.minimal:
        return _MinimalContent(
            content: computeMinimalContent(widget.combo, widget.toggles),
            scale: widget.textSize.scale,
            reversed: isTop);
      case InstagramOverlayStyle.sequence:
        return _SequenceContent(
            content: computeSequenceContent(widget.combo, widget.toggles),
            scale: widget.textSize.scale,
            reversed: isTop);
      case InstagramOverlayStyle.stat:
        return _StatContent(
            content: computeStatContent(widget.combo, widget.toggles),
            scale: widget.textSize.scale,
            reversed: isTop);
    }
  }
}

/// Reports the actual laid-out size of [child] after every frame via
/// [onChange], without affecting layout itself (it renders [child]
/// directly with no wrapper box). Used to size the scrim off the real
/// rendered height of the text/chips content rather than a guessed fixed
/// fraction of the canvas.
class _MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onChange;
  const _MeasureSize({required this.child, required this.onChange});

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = context.size;
      if (size != null) widget.onChange(size);
    });
    return widget.child;
  }
}

/// Lays out [pieces] top-to-bottom with a uniform gap between each visible
/// one, in [pieces] order — or reversed, when the text band is anchored to
/// the top of the canvas ([reversed]), so e.g. the combo name ends up
/// closest to the video/photo (center of the screen) instead of closest to
/// the top edge, mirroring how it reads when the band is at the bottom.
Widget _stackPieces(List<Widget> pieces, {required bool reversed, required double scale}) {
  final ordered = reversed ? pieces.reversed.toList() : pieces;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < ordered.length; i++) ...[
        if (i > 0) SizedBox(height: 8 * scale),
        ordered[i],
      ],
    ],
  );
}

class _ChipRow extends StatelessWidget {
  final OverlayChips chips;
  final double scale;
  const _ChipRow({required this.chips, required this.scale});

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.jetBrainsMono(
      fontSize: 7.5 * scale,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );
    return Wrap(
      spacing: 4 * scale,
      runSpacing: 4 * scale,
      children: [
        for (var i = 0; i < chips.shown.length; i++)
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: 5.5 * scale, vertical: 3.5 * scale),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              borderRadius: BorderRadius.circular(5 * scale),
            ),
            // Weak foot gets a small, muted "wf" suffix — present without
            // competing with the trick label itself. Strong foot (the
            // common case) and transition tricks (strongFoot null) get no
            // marker at all.
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: chips.shown[i], style: labelStyle),
                  if (chips.shownStrongFoot[i] == false)
                    TextSpan(
                      text: ' wf',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 5.5 * scale,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                ],
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
    );
  }
}

const _kTextShadow = [
  Shadow(blurRadius: 12, color: Colors.black54, offset: Offset(0, 2))
];

class _EmptyStateText extends StatelessWidget {
  final double scale;
  const _EmptyStateText({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Text(
      'No stats selected',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 9 * scale,
        fontStyle: FontStyle.italic,
        color: Colors.white.withValues(alpha: 0.55),
      ),
    );
  }
}

class _MinimalContent extends StatelessWidget {
  final MinimalOverlayContent content;
  final double scale;
  final bool reversed;
  const _MinimalContent({required this.content, required this.scale, required this.reversed});

  @override
  Widget build(BuildContext context) {
    final pieces = <Widget>[
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
        Text(
          content.metaParts.join(' · '),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9 * scale,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      if (content.chips.shown.isNotEmpty) _ChipRow(chips: content.chips, scale: scale),
    ];
    return _stackPieces(pieces, reversed: reversed, scale: scale);
  }
}

class _SequenceContent extends StatelessWidget {
  final SequenceOverlayContent content;
  final double scale;
  final bool reversed;
  const _SequenceContent({required this.content, required this.scale, required this.reversed});

  @override
  Widget build(BuildContext context) {
    final hasNameRow = content.title != null || content.difficultyBadge != null;
    final pieces = <Widget>[
      if (hasNameRow)
        Row(
          mainAxisAlignment: content.title != null
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
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
        Text(
          content.subParts.join(' · '),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9 * scale,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      if (content.chips.shown.isNotEmpty) _ChipRow(chips: content.chips, scale: scale),
      if (content.isEmpty) _EmptyStateText(scale: scale),
    ];
    return _stackPieces(pieces, reversed: reversed, scale: scale);
  }
}

class _StatContent extends StatelessWidget {
  final StatOverlayContent content;
  final double scale;
  final bool reversed;
  const _StatContent({required this.content, required this.scale, required this.reversed});

  @override
  Widget build(BuildContext context) {
    final pieces = <Widget>[
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
        Wrap(
          spacing: 16 * scale,
          runSpacing: 8 * scale,
          children: [
            for (final tile in content.tiles)
              Column(
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
          ],
        ),
      if (content.chips.shown.isNotEmpty) _ChipRow(chips: content.chips, scale: scale),
      if (content.isEmpty) _EmptyStateText(scale: scale),
    ];
    return _stackPieces(pieces, reversed: reversed, scale: scale);
  }
}
