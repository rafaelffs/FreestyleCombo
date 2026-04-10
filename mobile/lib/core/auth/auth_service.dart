import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'fc_token';
const _userIdKey = 'fc_user_id';

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
  bool get isAuthenticated => token != null;

  Future<void> setCredentials(String token, String userId) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);
    _prefs = prefs;
  }

  Future<void> clear() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }
}
