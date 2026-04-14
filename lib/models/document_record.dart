class DocumentRecord {
  final String id;
  final String loadId;
  final String documentType;
  final String fileName;
  final String storagePath;
  final String downloadUrl;
  final String uploadedBy;
  final String uploadedAt;
  final bool verified;
  final String notes;

  const DocumentRecord({
    required this.id,
    required this.loadId,
    required this.documentType,
    required this.fileName,
    required this.storagePath,
    required this.downloadUrl,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.verified,
    required this.notes,
  });

  factory DocumentRecord.fromMap(String id, Map<String, dynamic> map) {
    return DocumentRecord(
      id: id,
      loadId: (map['loadId'] ?? '').toString(),
      documentType: (map['documentType'] ?? '').toString(),
      fileName: (map['fileName'] ?? '').toString(),
      storagePath: (map['storagePath'] ?? '').toString(),
      downloadUrl: (map['downloadUrl'] ?? '').toString(),
      uploadedBy: (map['uploadedBy'] ?? '').toString(),
      uploadedAt: (map['uploadedAt'] ?? '').toString(),
      verified: map['verified'] == true,
      notes: (map['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'loadId': loadId,
      'documentType': documentType,
      'fileName': fileName,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt,
      'verified': verified,
      'notes': notes,
    };
  }
}
