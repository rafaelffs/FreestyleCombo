import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

/// Captures the widget behind a RepaintBoundary as a PNG and either hands it
/// to Instagram's Story composer via a native platform channel (see
/// ios/Runner/InstagramShareBridge.swift) or saves it to the device's photo
/// library.
class InstagramShareService {
  static const _channel =
      MethodChannel('com.rafaelffs.freestyleCombo/instagram_share');

  static Future<void> shareToStory(GlobalKey boundaryKey,
      {required double pixelRatio}) async {
    final pngBytes = await _capturePng(boundaryKey, pixelRatio: pixelRatio);

    try {
      await _channel.invokeMethod('shareToInstagramStory', {'image': pngBytes});
    } on PlatformException catch (e) {
      if (e.code == 'not_installed') {
        throw Exception('Install Instagram to share to your Story.');
      }
      throw Exception(e.message ?? 'Could not open Instagram.');
    } on MissingPluginException {
      throw Exception('Could not open Instagram.');
    }
  }

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
