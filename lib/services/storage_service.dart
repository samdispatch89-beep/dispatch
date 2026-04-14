import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class UploadResult {
  final String storagePath;
  final String downloadUrl;
  final String fileName;

  const UploadResult({
    required this.storagePath,
    required this.downloadUrl,
    required this.fileName,
  });
}

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<UploadResult> uploadFile(
    File file,
    String path, {
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putFile(file);
    final subscription = uploadTask.snapshotEvents.listen((snapshot) {
      final total = snapshot.totalBytes == 0 ? 1 : snapshot.totalBytes;
      onProgress?.call(snapshot.bytesTransferred / total);
    });

    try {
      await uploadTask;
      final url = await ref.getDownloadURL();
      return UploadResult(
        storagePath: path,
        downloadUrl: url,
        fileName: file.uri.pathSegments.isEmpty
            ? path.split('/').last
            : file.uri.pathSegments.last,
      );
    } finally {
      await subscription.cancel();
    }
  }
}
