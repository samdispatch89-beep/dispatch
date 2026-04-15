class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String loadId;
  final String createdAt;
  final bool read;
  final String type;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.loadId,
    required this.createdAt,
    required this.read,
    required this.type,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      userId: (map['userId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      loadId: (map['loadId'] ?? '').toString(),
      createdAt: (map['createdAt'] ?? '').toString(),
      read: map['read'] == true,
      type: (map['type'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'loadId': loadId,
      'createdAt': createdAt,
      'read': read,
      'type': type,
    };
  }
}
