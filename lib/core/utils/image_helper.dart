import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ImageHelper {
  /// Safely checks if a local file exists without throwing UnsupportedError on Web
  static bool isLocalFile(String? path) {
    if (path == null || path.isEmpty) return false;
    if (kIsWeb) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Builds a platform-safe image widget from a file path, blob URL, or network URL.
  static Widget buildImage(
    String? pathOrUrl, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) {
      return placeholder ?? const Icon(Icons.image_not_supported);
    }

    if (pathOrUrl.startsWith('http://') ||
        pathOrUrl.startsWith('https://') ||
        pathOrUrl.startsWith('blob:') ||
        pathOrUrl.startsWith('data:image')) {
      return Image.network(
        pathOrUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ?? placeholder ?? const Icon(Icons.broken_image),
      );
    }

    if (!kIsWeb && isLocalFile(pathOrUrl)) {
      return Image.file(
        File(pathOrUrl),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ?? placeholder ?? const Icon(Icons.broken_image),
      );
    }

    return placeholder ?? const Icon(Icons.image);
  }

  /// Returns an ImageProvider safely for CircleAvatar or BoxDecoration without dart:io errors on Web.
  static ImageProvider? getImageProvider(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return null;

    if (pathOrUrl.startsWith('http://') ||
        pathOrUrl.startsWith('https://') ||
        pathOrUrl.startsWith('blob:') ||
        pathOrUrl.startsWith('data:image')) {
      return NetworkImage(pathOrUrl);
    }

    if (!kIsWeb && isLocalFile(pathOrUrl)) {
      return FileImage(File(pathOrUrl));
    }

    return null;
  }
}
