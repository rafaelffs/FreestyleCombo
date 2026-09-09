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

/// The overlay content itself — fully transparent except the text band
/// (top or bottom, see [position]), so it composites over the person's own
/// photo/video in Instagram rather than sitting on top of it as an opaque
/// card. Deliberately has no background decoration of its own.
class InstagramOverlay extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isTop = position == InstagramOverlayPosition.top;

    // Content and the wordmark share one Column, edge-anchored per
    // [position] — the wordmark always sits closest to the outer screen
    // edge (bottom-most when the band is at the bottom, top-most when it's
    // at the top), with content filling in toward the canvas center.
    // Flutter's layout guarantees the two never overlap, since it's one
    // ordered Column rather than two independently-positioned Stack
    // children that could visually collide if content grew tall enough to
    // reach the wordmark's fixed corner position.
    final contentPadding = Padding(
      padding: EdgeInsets.fromLTRB(18, isTop ? 0 : 20, 18, isTop ? 20 : 0),
      child: _buildContent(),
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
            Container(
              width: 2.5,
              height: 2.5,
              decoration: const BoxDecoration(
                  color: AppColors.lime, shape: BoxShape.circle),
            ),
            const SizedBox(width: 2),
            Text(
              'FSCOMBO',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 4.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );

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
            height: kInstagramOverlayHeight * 0.44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
                  end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
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
            top: isTop ? 0 : null,
            bottom: isTop ? null : 0,
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
        ],
      ),
    );
  }

  Widget _buildContent() {
    final isTop = position == InstagramOverlayPosition.top;
    switch (style) {
      case InstagramOverlayStyle.minimal:
        return _MinimalContent(
            content: computeMinimalContent(combo, toggles),
            scale: textSize.scale,
            reversed: isTop);
      case InstagramOverlayStyle.sequence:
        return _SequenceContent(
            content: computeSequenceContent(combo, toggles),
            scale: textSize.scale,
            reversed: isTop);
      case InstagramOverlayStyle.stat:
        return _StatContent(
            content: computeStatContent(combo, toggles),
            scale: textSize.scale,
            reversed: isTop);
    }
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
    return Wrap(
      spacing: 4 * scale,
      runSpacing: 4 * scale,
      children: [
        for (final t in chips.shown)
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: 5.5 * scale, vertical: 3.5 * scale),
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
