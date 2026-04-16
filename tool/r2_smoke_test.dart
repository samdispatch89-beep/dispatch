import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dispatch/services/storage_service.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final storage = StorageService();
  final stamp = DateTime.now().millisecondsSinceEpoch.toString();
  final payload = Uint8List.fromList(
    utf8.encode('dispatch-r2-smoke-test-$stamp'),
  );

  final upload = await storage.uploadDocumentBytes(
    bytes: payload,
    companyName: 'Smoke Company',
    driverName: 'Smoke Driver',
    yearWeek: '2026-W16',
    loadNumber: 'SMOKE-$stamp',
    documentType: 'other',
    fileName: 'hello.txt',
    mimeType: 'text/plain',
  );

  final downloadUrl = await storage.getDownloadUrl(
    storagePath: upload.storagePath,
  );
  final response = await http.get(Uri.parse(downloadUrl));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('Download check failed [${response.statusCode}]');
  }

  final body = utf8.decode(response.bodyBytes);
  if (body != 'dispatch-r2-smoke-test-$stamp') {
    throw StateError('Downloaded body did not match uploaded body.');
  }

  await storage.deleteByPath(upload.storagePath);
  stdout.writeln('R2 smoke test passed for ${upload.storagePath}');
}
