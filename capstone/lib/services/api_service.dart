import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://wonsandbox.cloud/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  static const _storage = FlutterSecureStorage();

  /// 회원가입
  static Future<Response> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final res = await _dio.post('/auth/sign-up', data: {
      'email': email,
      'password': password,
      'name': name,
    });
    return res;
  }

  /// 로그인
  static Future<Response> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post('/auth/sign-in', data: {
      'email': email,
      'password': password,
    });

    // 토큰 저장
    final token = res.data['data']?['accessToken'];
    if (token != null) {
      await _storage.write(key: 'accessToken', value: token);
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }

    return res;
  }

  /// 로그인 후 인증 테스트용
  static Future<Response> getProfile() async {
    final token = await _storage.read(key: 'accessToken');
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }

    final res = await _dio.get('/member/me');
    return res;
  }
}
