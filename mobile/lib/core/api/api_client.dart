import 'package:dio/dio.dart';
import '../auth/auth_service.dart';
import '../models/combo.dart';
import '../models/user_preference.dart';

// Change to your machine's local IP when testing on a physical device.
// Android emulator: http://10.0.2.2:5050
// iOS simulator / web: http://localhost:5050
const String kBaseUrl = 'http://localhost:5050/api';

class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();

  late final Dio _dio;

  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = AuthService.instance.token;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          AuthService.instance.clear();
        }
        handler.next(error);
      },
    ));
  }

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return data['message'] as String? ??
          data['title'] as String? ??
          e.message ??
          'Request failed';
    }
    return e.message ?? 'Request failed';
  }

  // ── Auth ────────────────────────────────────────────────────────────────

  Future<({String token, String userId, String email})> register(
      String email, String userName, String password) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'email': email, 'userName': userName, 'password': password},
      );
      final d = res.data!;
      return (
        token: '',
        userId: d['userId'] as String,
        email: d['email'] as String,
      );
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<({String token, String userId})> login(
      String email, String password) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final d = res.data!;
      return (
        token: d['token'] as String,
        userId: d['userId'] as String,
      );
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  // ── Combos ──────────────────────────────────────────────────────────────

  Future<ComboDto> generateCombo(
      bool usePreferences, GenerateComboOverrides? overrides) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/combos/generate',
        data: {
          'usePreferences': usePreferences,
          if (overrides != null) 'overrides': overrides.toJson(),
        },
      );
      return ComboDto.fromJson(res.data!);
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<PagedResult<ComboDto>> getPublicCombos({
    int page = 1,
    int pageSize = 10,
    int? maxDifficulty,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/combos/public',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          if (maxDifficulty != null) 'maxDifficulty': maxDifficulty,
        },
      );
      final d = res.data!;
      return PagedResult<ComboDto>(
        items: (d['items'] as List<dynamic>)
            .map((i) => ComboDto.fromJson(i as Map<String, dynamic>))
            .toList(),
        totalCount: d['totalCount'] as int,
        page: d['page'] as int,
        pageSize: d['pageSize'] as int,
      );
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<PagedResult<ComboDto>> getMyCombos({
    int page = 1,
    int pageSize = 10,
    bool? isPublic,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/combos/mine',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          if (isPublic != null) 'isPublic': isPublic,
        },
      );
      final d = res.data!;
      return PagedResult<ComboDto>(
        items: (d['items'] as List<dynamic>)
            .map((i) => ComboDto.fromJson(i as Map<String, dynamic>))
            .toList(),
        totalCount: d['totalCount'] as int,
        page: d['page'] as int,
        pageSize: d['pageSize'] as int,
      );
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<ComboDto> getComboById(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/combos/$id');
      return ComboDto.fromJson(res.data!);
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<void> setVisibility(String id, bool isPublic) async {
    try {
      await _dio.put('/combos/$id/visibility', data: {'isPublic': isPublic});
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  // ── Ratings ─────────────────────────────────────────────────────────────

  Future<void> rateCombo(String comboId, int score) async {
    try {
      await _dio.post('/combos/$comboId/ratings', data: {'score': score});
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  // ── Preferences ──────────────────────────────────────────────────────────

  Future<UserPreference?> getPreferences() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/preferences');
      return UserPreference.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(_extractMessage(e));
    }
  }

  Future<UserPreference> upsertPreferences(UserPreference pref) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/preferences',
        data: pref.toJson(),
      );
      return UserPreference.fromJson(res.data!);
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }
}
