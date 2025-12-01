import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://wonsandbox.cloud/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 120),
      // headers: {'Content-Type': 'application/json'},
    ),
  );

  static const _storage = FlutterSecureStorage();

  static void init() {
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()), // 👈 print 대신 debugPrint
      ),
    );
  }

  /// ✅ 회원가입
  static Future<Response> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/sign-up',
        data: {'email': email, 'password': password, 'name': name},
        options: Options(contentType: Headers.jsonContentType),
      );
      return res;
    } on DioException catch (e) {
      throw Exception('회원가입 실패: ${e.response?.data ?? e.message}');
    }
  }

  /// ✅ 로그인
  static Future<Response> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/sign-in',
        data: {'email': email, 'password': password},
        options: Options(contentType: Headers.jsonContentType),
      );

      // ✅ 토큰 + memberId 저장
      final data = res.data['data'];
      final token = data?['accessToken'];
      final memberId = data?['memberId']; // 🔹 백엔드 응답에 따라 키 이름 확인 필요

      if (token != null && token is String && token.isNotEmpty) {
        await _storage.write(key: 'accessToken', value: token);
        _dio.options.headers['Authorization'] = 'Bearer $token';
      }

      if (memberId != null) {
        await _storage.write(key: 'memberId', value: memberId.toString());
      }

      return res;
    } on DioException catch (e) {
      throw Exception('로그인 실패: ${e.response?.data ?? e.message}');
    }
  }

  /// ✅ 내 정보 가져오기 (로그인 토큰 검증용)
  static Future<Response> getProfile() async {
    try {
      final token = await _storage.read(key: 'accessToken');
      if (token != null) {
        _dio.options.headers['Authorization'] = 'Bearer $token';
      }

      final res = await _dio.get('/member/profile');
      return res;
    } on DioException catch (e) {
      throw Exception('프로필 요청 실패: ${e.response?.data ?? e.message}');
    }
  }

  /// ✅ 로그아웃 (토큰 삭제)
  static Future<void> signOut() async {
    await _storage.delete(key: 'accessToken');
    _dio.options.headers.remove('Authorization');
  }

  /// ✅ 내 정보 조회
  /* static Future<Response> getProfile() async {
    final token = await _storage.read(key: 'accessToken');
    if (token == null) throw Exception('토큰이 없습니다. 로그인해주세요.');

    _dio.options.headers['Authorization'] = 'Bearer $token';
    return await _dio.get('/member/me');
  } */

  /// ✅ 회원 정보 수정
  /// ✅ 이름(닉네임) 수정
  static Future<Response> updateName({required String name}) async {
    final token = await _storage.read(key: 'accessToken');
    _dio.options.headers['Authorization'] = 'Bearer $token';

    final data = {'name': name};
    return await _dio.put('/member/profile', data: data);
  }

  /// ✅ 비밀번호 변경
  static Future<Response> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await _storage.read(key: 'accessToken');
    _dio.options.headers['Authorization'] = 'Bearer $token';

    final data = {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    };
    return await _dio.put('/member/password', data: data);
  }

  /// ✅ 회원 탈퇴
  static Future<Response> deleteAccount() async {
    final token = await _storage.read(key: 'accessToken');
    _dio.options.headers['Authorization'] = 'Bearer $token';
    return await _dio.delete('/member');
  }

  /// ✅ 알약 사진 업로드 + 분석 API
  static Future<Response> uploadPillImage({required File imageFile}) async {
    // 1) 토큰 / memberId 읽기
    final token = await _storage.read(key: 'accessToken');
    final memberIdStr = await _storage.read(key: 'memberId');

    if (token == null ||
        token.isEmpty ||
        memberIdStr == null ||
        memberIdStr.isEmpty) {
      throw Exception('로그인이 필요합니다. 다시 로그인해주세요.');
    }

    final memberId = int.tryParse(memberIdStr);
    if (memberId == null) {
      throw Exception('memberId 형식이 올바르지 않습니다.');
    }

    // 2) Authorization 헤더 설정
    _dio.options.headers['Authorization'] = 'Bearer $token';

    // 3) FormData 생성
    final fileName = imageFile.path.split('/').last;

    final formData = FormData.fromMap({
      "memberId": memberId, // ✅ 로그인한 사용자 기준
      "file": await MultipartFile.fromFile(imageFile.path, filename: fileName),
    });

    print('📦 FormData fields: ${formData.fields}');
    print('📦 FormData files: ${formData.files}');

    // 4) 업로드 호출
    try {
      final res = await _dio.post(
        '/photo/upload',
        data: formData,
        // ⚠ 여기서 Content-Type은 dio가 알아서 multipart로 설정하게 두는 게 좋음
        // options: Options(contentType: 'multipart/form-data'), // 필요하면 추가
      );
      return res;
    } on DioException catch (e) {
      throw Exception('사진 업로드 실패: ${e.response?.data ?? e.message}');
    }
  }

  // 🔥 DUR + GPT 종합 주의사항 조회 (/api/drug/caution)
  static Future<Response> getDrugCautions({
    required List<String> itemSeqList,
    int? memberId,
    int? photoId,
  }) async {
    final token = await _storage.read(key: 'accessToken');
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }

    try {
      final res = await _dio.post(
        '/drug/caution',
        data: {'itemSeqList': itemSeqList},
        queryParameters: {
          if (memberId != null) 'memberId': memberId,
          if (photoId != null) 'photoId': photoId,
        },
      );
      return res;
    } on DioException catch (e) {
      throw Exception('주의사항 조회 실패: ${e.response?.data ?? e.message}');
    }
  }

  static Future<Response> getDrugCaution({
    required List<String> itemSeqList,
    int? photoId,
  }) async {
    final token = await _storage.read(key: 'accessToken');
    final memberId = await _storage.read(key: 'memberId');

    if (token == null ||
        token.isEmpty ||
        memberId == null ||
        memberId.isEmpty) {
      throw Exception('로그인이 필요합니다. 다시 로그인해주세요.');
    }

    _dio.options.headers['Authorization'] = 'Bearer $token';

    return await _dio.post(
      '/drug/caution',
      data: {"itemSeqList": itemSeqList},
      queryParameters: {
        "memberId": memberId, // ✅ 로그인한 사용자와 일치
        if (photoId != null) "photoId": photoId,
      },
    );
  }

  /// ✅ 특정 의약품 상세정보 조회 API (/api/drug/{itemSeq})
  static Future<Response> getDrugDetail(String itemSeq) async {
    final token = await _storage.read(key: 'accessToken');
    if (token == null || token.isEmpty) {
      throw Exception('로그인이 필요합니다. 다시 로그인해주세요.');
    }

    _dio.options.headers['Authorization'] = 'Bearer $token';

    try {
      final res = await _dio.get('/drug/$itemSeq');
      return res;
    } on DioException catch (e) {
      throw Exception('약품 상세정보 조회 실패: ${e.response?.data ?? e.message}');
    }
  }

  static void printLong(dynamic data) {
    const int max = 800;
    final text = data.toString();
    for (var i = 0; i < text.length; i += max) {
      debugPrint(
        text.substring(i, i + max > text.length ? text.length : i + max),
      );
    }
  }

  /// ✅ 여러 장 사진 업로드 API
  static Future<Response> uploadMultiplePillImages({
    required List<File> imageFiles,
  }) async {
    // 1) 토큰 + memberId 읽기
    final token = await _storage.read(key: 'accessToken');
    final memberIdStr = await _storage.read(key: 'memberId');

    if (token == null || token.isEmpty) {
      throw Exception("로그인이 필요합니다.");
    }
    if (memberIdStr == null || memberIdStr.isEmpty) {
      throw Exception("memberId 조회 실패");
    }

    final memberId = int.tryParse(memberIdStr);
    if (memberId == null) throw Exception("memberId 파싱 실패");

    _dio.options.headers['Authorization'] = 'Bearer $token';

    // 2) FormData 생성
    final formData = FormData();
    formData.fields.add(MapEntry("memberId", memberId.toString()));

    // 3) 여러 파일 추가
    for (int i = 0; i < imageFiles.length; i++) {
      final file = imageFiles[i];
      final fileName = file.path.split('/').last;

      formData.files.add(
        MapEntry(
          "file", // 백엔드 name="file"
          await MultipartFile.fromFile(
            file.path,
            filename:
                "image_${DateTime.now().millisecondsSinceEpoch}_$fileName",
          ),
        ),
      );
    }

    // 4) 업로드 호출
    try {
      final res = await _dio.post("/photo/upload", data: formData);
      return res;
    } on DioException catch (e) {
      throw Exception("여러 사진 업로드 실패: ${e.response?.data ?? e.message}");
    }
  }
}
