import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

/// Captures the widget behind a RepaintBoundary as a PNG and saves it to the
/// device's photo library.
class InstagramShareService {
  static Future<void> saveImage(GlobalKey boundaryKey,
      {required double pixelRatio}) async {
    final pngBytes = await _capturePng(boundaryKey, pixelRatio: pixelRatio);

    try {
      await Gal.putImageBytes(pngBytes, name: 'fscombo-share');
    } on GalException catch (e) {
      if (e.type == GalExceptionType.accessDenied) {
        throw Exception('Allow Photos access to save the image.');
      }
      throw Exception('Could not save the image.');
    }
  }

  static Future<Uint8List> _capturePng(GlobalKey boundaryKey,
      {required double pixelRatio}) async {
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Nothing to share yet — try again.');
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Could not generate the image.');
    }
    return byteData.buffer.asUint8List();
  }
}
