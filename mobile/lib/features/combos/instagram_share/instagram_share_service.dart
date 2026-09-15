import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

/// Captures the widget behind a RepaintBoundary as a PNG and saves it to the
/// device's photo library.
///
/// [capturePng] and [saveBytes] are deliberately separate calls rather than
/// one combined `saveImage` — the caller must capture *before* triggering
/// any UI change (e.g. flipping a button into its loading/spinner state).
/// Calling `setState()` first and capturing after means the capture races
/// the resulting rebuild.
///
/// The boundary this is normally called with (the Share Image sheet's
/// preview) must stay scrolled into view / otherwise actually on-screen
/// right up until the capture — confirmed by instrumenting the render
/// pipeline that scrolling it far off-screen inside the sheet's settings
/// list (even with a large `cacheExtent` keeping the element mounted and
/// laid out) leaves the RenderObject permanently marked as needing a paint
/// pass it never actually gets, regardless of how many frames are awaited
/// afterward — `RenderRepaintBoundary.toImage()` then throws
/// AssertionError('!debugNeedsPaint') every single attempt. The real fix is
/// architectural: keep the preview pinned outside the scrollable settings
/// area (see `_InstagramShareSheet`'s layout) so it's never scrolled away
/// in the first place. The bounded retry below is only a defensive
/// safety net for a genuinely transient one-frame-stale case (e.g.
/// capturing a split second after the overlay's own self-measuring layout
/// changed) — it is compiled out in release along with the assertion it's
/// guarding against, at which point `toImage()` just proceeds and returns
/// whatever the layer tree currently holds.
class InstagramShareService {
  static Future<Uint8List> capturePng(GlobalKey boundaryKey,
      {required double pixelRatio}) async {
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Nothing to share yet — try again.');
    }

    ui.Image? image;
    for (var attempt = 0; attempt < 3 && image == null; attempt++) {
      try {
        image = await boundary.toImage(pixelRatio: pixelRatio);
      } on AssertionError {
        await WidgetsBinding.instance.endOfFrame;
      }
    }
    image ??= await boundary.toImage(pixelRatio: pixelRatio);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Could not generate the image.');
    }
    return byteData.buffer.asUint8List();
  }

  static Future<void> saveBytes(Uint8List pngBytes) async {
    try {
      await Gal.putImageBytes(pngBytes, name: 'fscombo-share');
    } on GalException catch (e) {
      if (e.type == GalExceptionType.accessDenied) {
        throw Exception('Allow Photos access to save the image.');
      }
      throw Exception('Could not save the image.');
    }
  }
}
