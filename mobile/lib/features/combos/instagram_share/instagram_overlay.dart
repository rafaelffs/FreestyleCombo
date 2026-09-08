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
                  decoration: const BoxDecoration(
                      color: AppColors.lime, shape: BoxShape.circle),
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
        return _MinimalContent(
            content: computeMinimalContent(combo, toggles),
            scale: textSize.scale);
      case InstagramOverlayStyle.sequence:
        return _SequenceContent(
            content: computeSequenceContent(combo, toggles),
            scale: textSize.scale);
      case InstagramOverlayStyle.stat:
        return _StatContent(
            content: computeStatContent(combo, toggles), scale: textSize.scale);
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
      ),
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
            padding:
                EdgeInsets.only(top: content.title != null ? 6 * scale : 0),
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
        if (content.isEmpty) _EmptyStateText(scale: scale),
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
            child: Wrap(
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
          ),
        _ChipRow(chips: content.chips, scale: scale),
        if (content.isEmpty) _EmptyStateText(scale: scale),
      ],
    );
  }
}
