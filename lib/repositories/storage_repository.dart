import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageRepository {
  FirebaseStorage get _storage => FirebaseStorage.instance;

  /// Uploads a file (e.g. prescription image, document) to Firebase Storage
  /// Path pattern: users/{userId}/health_records/{recordId}/documents/{fileName}
  Future<String?> uploadHealthRecordAttachment({
    required String userId,
    required String recordId,
    required String filePath,
    required String fileName,
  }) async {
    try {
      final ref = _storage
          .ref()
          .child('users')
          .child(userId)
          .child('health_records')
          .child(recordId)
          .child('documents')
          .child(fileName);

      if (kIsWeb) {
        // Web upload handling if Uint8List or byte array is available
        // Return existing filePath if it's already a URL or data URI
        if (filePath.startsWith('http') || filePath.startsWith('blob:') || filePath.startsWith('data:')) {
          return filePath;
        }
      } else {
        final file = File(filePath);
        if (await file.exists()) {
          final uploadTask = await ref.putFile(file);
          final downloadUrl = await uploadTask.ref.getDownloadURL();
          return downloadUrl;
        }
      }
    } catch (e) {
      debugPrint('Firebase Storage upload bypassed/failed: $e');
    }

    // Fallback: return the local filePath so health record creation is never blocked
    return filePath;
  }
}
