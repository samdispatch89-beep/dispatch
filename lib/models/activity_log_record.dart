class ActivityLogRecord {
  final String id;
  final String loadId;
  final String type;
  final String message;
  final String actorId;
  final String actorName;
  final String createdAt;

  const ActivityLogRecord({
    required this.id,
    required this.loadId,
    required this.type,
    required this.message,
    required this.actorId,
    required this.actorName,
    required this.createdAt,
  });

  factory ActivityLogRecord.fromMap(String id, Map<String, dynamic> map) {
    return ActivityLogRecord(
      id: id,
      loadId: (map['loadId'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      actorId: (map['actorId'] ?? '').toString(),
      actorName: (map['actorName'] ?? '').toString(),
      createdAt: (map['createdAt'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'loadId': loadId,
      'type': type,
      'message': message,
      'actorId': actorId,
      'actorName': actorName,
      'createdAt': createdAt,
    };
  }
}
