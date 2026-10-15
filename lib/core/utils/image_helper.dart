import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ImageHelper {
  /// Safely resolves a path or URL. If it starts with '/', prepends ApiConfig.baseUrl.
  static String? resolveUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.trim().isEmpty) return null;
    final trimmed = pathOrUrl.trim();
    if (trimmed.startsWith('/')) {
      return '${ApiConfig.baseUrl}$trimmed';
    }
    return trimmed;
  }

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
    final resolved = resolveUrl(pathOrUrl);
    if (resolved == null || resolved.isEmpty) {
      return placeholder ?? const Icon(Icons.image_not_supported);
    }

    if (resolved.startsWith('http://') ||
        resolved.startsWith('https://') ||
        resolved.startsWith('blob:') ||
        resolved.startsWith('data:image')) {
      return Image.network(
        resolved,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ?? placeholder ?? const Icon(Icons.broken_image),
      );
    }

    if (!kIsWeb && isLocalFile(resolved)) {
      return Image.file(
        File(resolved),
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
    final resolved = resolveUrl(pathOrUrl);
    if (resolved == null || resolved.isEmpty) return null;

    if (resolved.startsWith('http://') ||
        resolved.startsWith('https://') ||
        resolved.startsWith('blob:') ||
        resolved.startsWith('data:image')) {
      return NetworkImage(resolved);
    }

    if (!kIsWeb && isLocalFile(resolved)) {
      return FileImage(File(resolved));
    }

    return null;
  }

  /// Loads raw file/image bytes safely across Web and native Android
  static Future<Uint8List?> loadBytes(String? pathOrUrl) async {
    final resolved = resolveUrl(pathOrUrl);
    if (resolved == null || resolved.isEmpty) return null;

    try {
      if (resolved.startsWith('data:')) {
        final commaIdx = resolved.indexOf(',');
        if (commaIdx != -1) {
          final b64 = resolved.substring(commaIdx + 1);
          return base64Decode(b64);
        }
      }

      if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
        final res = await http.get(Uri.parse(resolved));
        if (res.statusCode == 200) {
          return res.bodyBytes;
        }
      }

      if (!kIsWeb && isLocalFile(resolved)) {
        return await File(resolved).readAsBytes();
      }
    } catch (e) {
      debugPrint('[IMAGE HELPER] loadBytes failed for $resolved: $e');
    }
    return null;
  }
}
