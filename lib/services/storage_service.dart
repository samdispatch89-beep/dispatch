import 'dart:async';
import 'dart:typed_data';

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

  String sanitizeSegment(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'unknown';
    return trimmed.replaceAll(RegExp(r'[.#$\[\]/]+'), '_').replaceAll(' ', '_');
  }

  String buildLoadDocumentPath({
    required String companyName,
    required String driverName,
    required String yearWeek,
    required String loadNumber,
    required String documentType,
    required String fileName,
  }) {
    return 'companies/${sanitizeSegment(companyName)}/'
        'drivers/${sanitizeSegment(driverName)}/'
        '$yearWeek/'
        'loads/${sanitizeSegment(loadNumber)}/'
        '${sanitizeSegment(documentType)}/'
        '${sanitizeSegment(fileName)}';
  }

  String buildInvoicePath({
    required String companyName,
    required String driverName,
    required String yearWeek,
    required String loadNumber,
    required String fileName,
  }) {
    return buildLoadDocumentPath(
      companyName: companyName,
      driverName: driverName,
      yearWeek: yearWeek,
      loadNumber: loadNumber,
      documentType: 'invoice',
      fileName: fileName,
    );
  }

  String? _contentTypeForFileName(String? fileName) {
    if (fileName == null || !fileName.contains('.')) return null;
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => null,
    };
  }

  Future<UploadResult> uploadBytes(
    Uint8List bytes,
    String path, {
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putData(
      bytes,
      SettableMetadata(contentType: _contentTypeForFileName(fileName)),
    );
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
        fileName: fileName ?? path.split('/').last,
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> deleteByPath(String path) async {
    if (path.trim().isEmpty) return;
    await _storage.ref().child(path).delete();
  }
}
