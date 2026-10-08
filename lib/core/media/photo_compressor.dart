import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../errors/app_exception.dart';

/// Shrinks a photo before upload so the free storage plan goes a long way:
/// at most [maxSide] pixels on the long side, JPEG, under [targetBytes].
abstract final class PhotoCompressor {
  static const maxSide = 1080;
  static const targetBytes = 300 * 1024;

  /// Photo formats accepted from the gallery or camera.
  static const _photoFormats = {
    img.ImageFormat.jpg,
    img.ImageFormat.png,
    img.ImageFormat.webp,
    img.ImageFormat.gif,
    img.ImageFormat.bmp,
  };

  /// Runs off the UI thread where the platform allows it.
  static Future<Uint8List> compress(Uint8List original) =>
      compute(compressSync, original);

  static Uint8List compressSync(Uint8List original) {
    img.Image? decoded;
    try {
      decoded = _photoFormats.contains(img.findFormatForData(original))
          ? img.decodeImage(original)
          : null;
    } catch (_) {
      // Truncated or unknown data can make the decoders throw.
      decoded = null;
    }
    if (decoded == null) {
      throw const AppException('This file is not a photo we can read.');
    }
    // Phone photos are often stored sideways with an orientation tag.
    var photo = _fit(img.bakeOrientation(decoded), maxSide);

    // Lower the quality first; very detailed photos then get a bit smaller
    // until they fit, so an upload is never refused for its size.
    var quality = 82;
    var jpeg = img.encodeJpg(photo, quality: quality);
    while (jpeg.length > targetBytes) {
      if (quality > 52) {
        quality -= 10;
      } else {
        final longSide = photo.width > photo.height
            ? photo.width
            : photo.height;
        if (longSide <= 320) break;
        photo = _fit(photo, (longSide * 0.8).round());
      }
      jpeg = img.encodeJpg(photo, quality: quality);
    }
    return jpeg;
  }

  static img.Image _fit(img.Image photo, int side) {
    final longSide = photo.width > photo.height ? photo.width : photo.height;
    if (longSide <= side) return photo;
    return photo.width >= photo.height
        ? img.copyResize(photo, width: side)
        : img.copyResize(photo, height: side);
  }
}
