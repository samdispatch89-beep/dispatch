import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

class SessionCacheService {
  SessionCacheService._();

  static final SessionCacheService instance = SessionCacheService._();

  static const _cachedUidKey = 'cached_uid';
  static const _cachedUserKey = 'cached_app_user';

  Future<void> saveUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedUidKey, user.uid);
    await prefs.setString(_cachedUserKey, jsonEncode(user.toMap()));
  }

  Future<AppUser?> loadUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedUid = prefs.getString(_cachedUidKey);
    final raw = prefs.getString(_cachedUserKey);
    if (cachedUid != uid || raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      return AppUser.fromMap(
        uid,
        map.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedUidKey);
    await prefs.remove(_cachedUserKey);
  }
}
