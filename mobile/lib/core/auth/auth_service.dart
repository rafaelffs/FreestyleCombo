import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'fc_token';
const _userIdKey = 'fc_user_id';
const _isAdminKey = 'fc_is_admin';
const _userNameKey = 'fc_user_name';
const _pendingComboKey = 'fc_pending_combo';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  AuthService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? get token => _prefs?.getString(_tokenKey);
  String? get userId => _prefs?.getString(_userIdKey);
  String? get userName => _prefs?.getString(_userNameKey);
  bool get isAuthenticated => token != null;
  bool get isAdmin => _prefs?.getBool(_isAdminKey) ?? false;

  Future<void> setCredentials(String token, String userId) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);
    await prefs.setBool(_isAdminKey, _extractIsAdmin(token));
    final name = _extractUserName(token);
    if (name != null) await prefs.setString(_userNameKey, name);
    _prefs = prefs;
  }

  Future<void> setUserName(String name) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
    _prefs = prefs;
  }

  Future<void> clear() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_isAdminKey);
    await prefs.remove(_userNameKey);
  }

  Map<String, dynamic>? getPendingCombo() {
    final raw = _prefs?.getString(_pendingComboKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setPendingCombo(Map<String, dynamic> combo) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_pendingComboKey, jsonEncode(combo));
    _prefs = prefs;
  }

  Future<void> clearPendingCombo() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_pendingComboKey);
    _prefs = prefs;
  }

  String? _extractUserName(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
        case 3:
          payload += '=';
      }
      final decoded = utf8.decode(base64.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return json['unique_name'] as String?;
    } catch (_) {
      return null;
    }
  }

  bool _extractIsAdmin(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      // Pad base64url to valid base64
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
        case 3:
          payload += '=';
      }
      final decoded = utf8.decode(base64.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      const roleKey =
          'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';
      final role = json[roleKey];
      if (role is String) return role == 'Admin';
      if (role is List) return role.contains('Admin');
      return false;
    } catch (_) {
      return false;
    }
  }
}
