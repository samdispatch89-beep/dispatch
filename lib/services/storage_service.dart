import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'r2_direct_config.dart';

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

class SignedUploadRequest {
  final String uploadUrl;
  final String storagePath;
  final String downloadUrl;
  final String fileName;
  final String contentType;
  final Map<String, String> headers;

  const SignedUploadRequest({
    required this.uploadUrl,
    required this.storagePath,
    required this.downloadUrl,
    required this.fileName,
    required this.contentType,
    required this.headers,
  });
}

class StorageService {
  StorageService({
    DirectR2Config? config,
    http.Client? httpClient,
    AWSSigV4Signer? signer,
  }) : _config = config ?? const DirectR2Config(),
       _httpClient = httpClient ?? http.Client(),
       _signer =
           signer ??
           AWSSigV4Signer(
             credentialsProvider: AWSCredentialsProvider(
               AWSCredentials(
                 (config ?? const DirectR2Config()).accessKeyId,
                 (config ?? const DirectR2Config()).secretAccessKey,
               ),
             ),
           );

  final DirectR2Config _config;
  final http.Client _httpClient;
  final AWSSigV4Signer _signer;

  static const Set<String> _validDocumentTypes = {
    'rate_confirmation',
    'bol',
    'pod',
    'invoice',
    'carrier_packet',
    'invoice_copy',
    'payment_support_document',
    'other',
  };

  static const _presignDuration = Duration(hours: 4);

  AWSCredentialScope get _scope =>
      AWSCredentialScope(region: 'auto', service: AWSService.s3);

  S3ServiceConfiguration get _serviceConfiguration =>
      S3ServiceConfiguration(signPayload: false);

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

  String resolveMimeType(String? fileName) {
    if (fileName == null || !fileName.contains('.')) {
      return 'application/octet-stream';
    }
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };
  }

  void _ensureConfigured() {
    if (!_config.isConfigured) {
      throw StateError(
        'Cloudflare R2 is not configured. Set R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, and R2_BUCKET_NAME.',
      );
    }
  }

  Never _throwFriendlyError(Object error, {required String stage}) {
    final rawMessage = error.toString();
    if (kIsWeb && rawMessage.contains('ClientException: Failed to fetch')) {
      throw StateError(
        '$stage failed: Cloudflare R2 blocked the browser request. '
        'This direct web upload path requires an R2 bucket CORS rule that allows PUT, GET, and DELETE from your app origin.',
      );
    }
    throw StateError('$stage failed: $rawMessage');
  }

  void _validateUploadFields({
    required String companyName,
    required String driverName,
    required String yearWeek,
    required String loadNumber,
    required String documentType,
    required String fileName,
    required String mimeType,
  }) {
    if (companyName.trim().isEmpty ||
        driverName.trim().isEmpty ||
        yearWeek.trim().isEmpty ||
        loadNumber.trim().isEmpty ||
        fileName.trim().isEmpty) {
      throw StateError(
        'Missing required load info for upload. Company, driver, week, load number, and file name are required.',
      );
    }
    if (!_validDocumentTypes.contains(documentType.trim().toLowerCase())) {
      throw StateError('Invalid document type: $documentType');
    }
    if (mimeType.trim().isEmpty) {
      throw StateError('mimeType is required for upload.');
    }
  }

  Uri _objectUri(String storagePath) {
    final normalizedPath =
        storagePath.startsWith('/') ? storagePath.substring(1) : storagePath;
    return Uri.https(_config.endpointHost, '/${_config.bucket}/$normalizedPath');
  }

  AWSHttpRequest _putRequest({
    required Uri uri,
    required List<int> body,
    required String mimeType,
  }) {
    return AWSHttpRequest.put(
      uri,
      body: body,
      headers: {
        AWSHeaders.host: uri.host,
        AWSHeaders.contentType: mimeType,
      },
    );
  }

  AWSHttpRequest _getRequest(Uri uri) {
    return AWSHttpRequest.get(
      uri,
      headers: {
        AWSHeaders.host: uri.host,
      },
    );
  }

  AWSHttpRequest _deleteRequest(Uri uri) {
    return AWSHttpRequest.delete(
      uri,
      headers: {
        AWSHeaders.host: uri.host,
      },
    );
  }

  Future<String> _presignGet(String storagePath) async {
    _ensureConfigured();
    final uri = _objectUri(storagePath);
    final request = _getRequest(uri);
    final signedUrl = await _signer.presign(
      request,
      credentialScope: _scope,
      serviceConfiguration: _serviceConfiguration,
      expiresIn: _presignDuration,
    );
    return signedUrl.toString();
  }

  Future<SignedUploadRequest> createUploadRequest({
    required String companyName,
    required String driverName,
    required String yearWeek,
    required String loadNumber,
    required String documentType,
    required String fileName,
    required String mimeType,
  }) async {
    _ensureConfigured();
    _validateUploadFields(
      companyName: companyName,
      driverName: driverName,
      yearWeek: yearWeek,
      loadNumber: loadNumber,
      documentType: documentType,
      fileName: fileName,
      mimeType: mimeType,
    );

    final storagePath = buildLoadDocumentPath(
      companyName: companyName,
      driverName: driverName,
      yearWeek: yearWeek,
      loadNumber: loadNumber,
      documentType: documentType,
      fileName: fileName,
    );
    final objectUri = _objectUri(storagePath);
    final signedUploadUrl = await _signer.presign(
      _putRequest(uri: objectUri, body: const [], mimeType: mimeType),
      credentialScope: _scope,
      serviceConfiguration: _serviceConfiguration,
      expiresIn: _presignDuration,
    );

    return SignedUploadRequest(
      uploadUrl: signedUploadUrl.toString(),
      storagePath: storagePath,
      downloadUrl: await _presignGet(storagePath),
      fileName: sanitizeSegment(fileName),
      contentType: mimeType,
      headers: const {},
    );
  }

  Future<UploadResult> uploadDocumentBytes({
    required Uint8List bytes,
    required String companyName,
    required String driverName,
    required String yearWeek,
    required String loadNumber,
    required String documentType,
    required String fileName,
    String? mimeType,
    void Function(double progress)? onProgress,
  }) async {
    final resolvedMimeType = mimeType ?? resolveMimeType(fileName);
    try {
      final request = await createUploadRequest(
        companyName: companyName,
        driverName: driverName,
        yearWeek: yearWeek,
        loadNumber: loadNumber,
        documentType: documentType,
        fileName: fileName,
        mimeType: resolvedMimeType,
      );
      onProgress?.call(0);
      final response = await _httpClient.put(
        Uri.parse(request.uploadUrl),
        headers: {'Content-Type': request.contentType},
        body: bytes,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Upload to R2 failed [${response.statusCode}]: ${response.body.isEmpty ? 'No response body' : response.body}',
        );
      }
      onProgress?.call(1);
      return UploadResult(
        storagePath: request.storagePath,
        downloadUrl: request.downloadUrl,
        fileName: request.fileName,
      );
    } catch (error) {
      _throwFriendlyError(error, stage: 'Upload to R2');
    }
  }

  Future<String> getDownloadUrl({
    required String storagePath,
    bool inline = true,
  }) async {
    try {
      return await _presignGet(storagePath);
    } catch (error) {
      _throwFriendlyError(error, stage: 'Could not request download URL');
    }
  }

  Future<void> deleteByPath(String path) async {
    if (path.trim().isEmpty) return;
    try {
      _ensureConfigured();
      final uri = _objectUri(path);
      final signedDeleteUrl = await _signer.presign(
        _deleteRequest(uri),
        credentialScope: _scope,
        serviceConfiguration: _serviceConfiguration,
        expiresIn: _presignDuration,
      );
      final response = await _httpClient.delete(signedDeleteUrl);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Delete from R2 failed [${response.statusCode}]: ${response.body.isEmpty ? 'No response body' : response.body}',
        );
      }
    } catch (error) {
      _throwFriendlyError(error, stage: 'Could not delete uploaded file');
    }
  }

  Map<String, dynamic> buildMetadataPatch({
    required String storagePath,
    required String fileName,
  }) {
    return {
      'storagePath': storagePath,
      'fileName': fileName,
      'downloadUrl': '',
      'uploadedAt': DateTime.now().toIso8601String(),
    };
  }
}
