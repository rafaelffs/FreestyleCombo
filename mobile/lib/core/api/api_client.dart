import 'package:dio/dio.dart';
import '../auth/auth_service.dart';
import '../models/combo.dart';
import '../models/trick_submission.dart';
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
      return data['error'] as String? ??
          data['message'] as String? ??
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
      String credential, String password) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'credential': credential, 'password': password},
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

  Future<PreviewComboResponse> previewCombo(
      bool usePreferences, GenerateComboOverrides? overrides) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/combos/preview',
        data: {
          'usePreferences': usePreferences,
          if (overrides != null) 'overrides': overrides.toJson(),
        },
      );
      return PreviewComboResponse.fromJson(res.data!);
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<ComboDto> generateCombo(
      bool usePreferences, GenerateComboOverrides? overrides, {String? name}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/combos/generate',
        data: {
          'usePreferences': usePreferences,
          if (overrides != null) 'overrides': overrides.toJson(),
          if (name != null && name.isNotEmpty) 'name': name,
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

  Future<ComboDto> buildCombo(
      List<BuildComboTrickItem> tricks, bool isPublic, {String? name}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/combos/build',
        data: {
          'tricks': tricks.map((t) => t.toJson()).toList(),
          'isPublic': isPublic,
          if (name != null && name.isNotEmpty) 'name': name,
        },
      );
      return ComboDto.fromJson(res.data!);
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<ComboDto> updateCombo(
      String id, {
      String? name,
      List<BuildComboTrickItem>? tricks,
    }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/combos/$id',
        data: {
          if (name != null) 'name': name.isEmpty ? null : name,
          if (tricks != null) 'tricks': tricks.map((t) => t.toJson()).toList(),
        },
      );
      return ComboDto.fromJson(res.data!);
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<void> addFavourite(String id) async {
    try {
      await _dio.post('/combos/$id/favourite');
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<void> removeFavourite(String id) async {
    try {
      await _dio.delete('/combos/$id/favourite');
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<void> deleteCombo(String id) async {
    try {
      await _dio.delete('/combos/$id');
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  // ── Ratings ─────────────────────────────────────────────────────────────

  Future<List<ComboDto>> getPendingComboReviews() async {
    try {
      final res = await _dio.get<List<dynamic>>('/combos/pending-review');
      return (res.data as List<dynamic>)
          .map((e) => ComboDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<void> approveComboVisibility(String id) async {
    try {
      await _dio.post('/combos/$id/approve-visibility');
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<void> rejectComboVisibility(String id) async {
    try {
      await _dio.post('/combos/$id/reject-visibility');
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<void> rateCombo(String comboId, int score) async {
    try {
      await _dio.post('/combos/$comboId/ratings', data: {'score': score});
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  // ── Trick Submissions ────────────────────────────────────────────────────

  Future<String> submitTrick({
    required String name,
    required String abbreviation,
    required bool crossOver,
    required bool knee,
    required double revolution,
    required int difficulty,
    required int commonLevel,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/trick-submissions',
        data: {
          'name': name,
          'abbreviation': abbreviation,
          'crossOver': crossOver,
          'knee': knee,
          'revolution': revolution,
          'difficulty': difficulty,
          'commonLevel': commonLevel,
        },
      );
      return res.data!['id'] as String;
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<List<TrickSubmissionDto>> getMySubmissions() async {
    try {
      final res = await _dio.get<List<dynamic>>('/trick-submissions/mine');
      return (res.data as List<dynamic>)
          .map((e) => TrickSubmissionDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<List<TrickSubmissionDto>> getPendingSubmissions() async {
    try {
      final res = await _dio.get<List<dynamic>>('/trick-submissions/pending');
      return (res.data as List<dynamic>)
          .map((e) => TrickSubmissionDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<void> approveSubmission(String id) async {
    try {
      await _dio.post('/trick-submissions/$id/approve');
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<void> rejectSubmission(String id) async {
    try {
      await _dio.post('/trick-submissions/$id/reject');
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  // ── Tricks ───────────────────────────────────────────────────────────────

  Future<List<TrickDto>> getTricks({
    bool? crossOver,
    bool? knee,
    int? maxDifficulty,
  }) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/tricks',
        queryParameters: {
          if (crossOver != null) 'crossOver': crossOver,
          if (knee != null) 'knee': knee,
          if (maxDifficulty != null) 'maxDifficulty': maxDifficulty,
        },
      );
      return (res.data as List<dynamic>)
          .map((e) => TrickDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<void> updateTrick(String id, TrickDto trick) async {
    try {
      await _dio.put('/tricks/$id', data: trick.toJson());
    } on DioException catch (e) {
      throw Exception(_extractMessage(e));
    }
  }

  Future<void> deleteTrick(String id) async {
    try {
      await _dio.delete('/tricks/$id');
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
