import 'app_role.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final AppRole role;
  final String dispatcherId;
  final bool active;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.dispatcherId,
    required this.active,
  });

  bool get isAdmin => role == AppRole.admin;
  bool get isDispatcher => role == AppRole.dispatcher;
  bool get isAccountant => role == AppRole.accountant;
  bool get isPaperwork => role == AppRole.paperwork;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      role: AppRole.fromValue(map['role']?.toString()),
      dispatcherId: (map['dispatcherId'] ?? '').toString(),
      active: map['active'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role.value,
      'dispatcherId': dispatcherId,
      'active': active,
    };
  }
}
