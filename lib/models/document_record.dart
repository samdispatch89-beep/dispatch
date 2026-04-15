class DocumentRecord {
  final String id;
  final String loadId;
  final String companyId;
  final String companyName;
  final String driverId;
  final String driverName;
  final String dispatcherId;
  final int year;
  final int week;
  final String yearWeek;
  final String documentType;
  final String fileName;
  final String storagePath;
  final String downloadUrl;
  final String uploadedBy;
  final String uploadedAt;
  final bool verified;
  final bool affectsStatus;
  final String notes;

  const DocumentRecord({
    required this.id,
    required this.loadId,
    required this.companyId,
    required this.companyName,
    required this.driverId,
    required this.driverName,
    required this.dispatcherId,
    required this.year,
    required this.week,
    required this.yearWeek,
    required this.documentType,
    required this.fileName,
    required this.storagePath,
    required this.downloadUrl,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.verified,
    required this.affectsStatus,
    required this.notes,
  });

  factory DocumentRecord.fromMap(String id, Map<String, dynamic> map) {
    return DocumentRecord(
      id: id,
      loadId: (map['loadId'] ?? '').toString(),
      companyId: (map['companyId'] ?? '').toString(),
      companyName: (map['companyName'] ?? '').toString(),
      driverId: (map['driverId'] ?? '').toString(),
      driverName: (map['driverName'] ?? '').toString(),
      dispatcherId: (map['dispatcherId'] ?? '').toString(),
      year: (map['year'] ?? 0) as int,
      week: (map['week'] ?? 0) as int,
      yearWeek: (map['yearWeek'] ?? '').toString(),
      documentType: (map['documentType'] ?? '').toString(),
      fileName: (map['fileName'] ?? '').toString(),
      storagePath: (map['storagePath'] ?? '').toString(),
      downloadUrl: (map['downloadUrl'] ?? '').toString(),
      uploadedBy: (map['uploadedBy'] ?? '').toString(),
      uploadedAt: (map['uploadedAt'] ?? '').toString(),
      verified: map['verified'] == true,
      affectsStatus: map['affectsStatus'] != false,
      notes: (map['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'loadId': loadId,
      'companyId': companyId,
      'companyName': companyName,
      'driverId': driverId,
      'driverName': driverName,
      'dispatcherId': dispatcherId,
      'year': year,
      'week': week,
      'yearWeek': yearWeek,
      'documentType': documentType,
      'fileName': fileName,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt,
      'verified': verified,
      'affectsStatus': affectsStatus,
      'notes': notes,
    };
  }
}
