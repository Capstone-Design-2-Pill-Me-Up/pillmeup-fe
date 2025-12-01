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
    ),
  );

  static const _storage = FlutterSecureStorage();

  static void init() {
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ),
    );
  }

  // ================= 회원 / 프로필 =================

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
      final memberId = data?['memberId'];

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

  /// ✅ 내 정보 가져오기
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
    await _storage.delete(key: 'memberId');
    _dio.options.headers.remove('Authorization');
  }

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

  // ================= 알약 / 분석 관련 =================

  /// ✅ 단일 알약 사진 업로드
  /// 업로드 응답에서 백엔드가 historyId, itemSeqList, imageUrls 등을 내려줌.
  /// 우리는 응답을 그대로 반환하고, 사용하는 쪽에서
  ///   final data = res.data['data'];
  ///   final historyId = data['historyId'];
  /// 처럼 꺼내 쓰면 됨.
  static Future<Response> uploadPillImage({required File imageFile}) async {
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

    _dio.options.headers['Authorization'] = 'Bearer $token';

    final fileName = imageFile.path.split('/').last;

    final formData = FormData.fromMap({
      "memberId": memberId,
      "file": await MultipartFile.fromFile(imageFile.path, filename: fileName),
    });

    debugPrint('📦 [SINGLE] FormData fields: ${formData.fields}');
    debugPrint('📦 [SINGLE] FormData files: ${formData.files}');

    try {
      final res = await _dio.post('/photo/upload', data: formData);
      return res;
    } on DioException catch (e) {
      throw Exception('사진 업로드 실패: ${e.response?.data ?? e.message}');
    }
  }

  /// ✅ 여러 장 사진 업로드
  /// 마찬가지로 응답의 data 안에 historyId / itemSeqList / imageUrls 가 들어있다고 가정.
  static Future<Response> uploadMultiplePillImages({
    required List<File> imageFiles,
  }) async {
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

    final formData = FormData();
    formData.fields.add(MapEntry("memberId", memberId.toString()));

    for (int i = 0; i < imageFiles.length; i++) {
      final file = imageFiles[i];
      final fileName = file.path.split('/').last;

      formData.files.add(
        MapEntry(
          "file",
          await MultipartFile.fromFile(
            file.path,
            filename:
                "image_${DateTime.now().millisecondsSinceEpoch}_$fileName",
          ),
        ),
      );
    }

    debugPrint('📦 [MULTI] FormData fields: ${formData.fields}');
    debugPrint('📦 [MULTI] FormData files: ${formData.files}');

    try {
      final res = await _dio.post("/photo/upload", data: formData);
      return res;
    } on DioException catch (e) {
      throw Exception("여러 사진 업로드 실패: ${e.response?.data ?? e.message}");
    }
  }

  /// ✅ 분석 트리거 API
  /// POST /api/drug/caution
  /// body: { historyId, itemSeqList }
  /// query: ?memberId=...
  static Future<Response> requestDrugCaution({
    required int historyId,
    required List<String> itemSeqList,
  }) async {
    final token = await _storage.read(key: 'accessToken');
    final memberIdStr = await _storage.read(key: 'memberId');

    if (token == null ||
        token.isEmpty ||
        memberIdStr == null ||
        memberIdStr.isEmpty) {
      throw Exception('로그인이 필요합니다. 다시 로그인해주세요.');
    }

    _dio.options.headers['Authorization'] = 'Bearer $token';

    try {
      final res = await _dio.post(
        '/drug/caution',
        // ✅ body 에는 itemSeqList만
        data: {'itemSeqList': itemSeqList},
        // ✅ 쿼리 파라미터로 memberId + historyId 둘 다 전송
        queryParameters: {'memberId': memberIdStr, 'historyId': historyId},
      );
      return res;
    } on DioException catch (e) {
      throw Exception('주의사항 조회 실패: ${e.response?.data ?? e.message}');
    }
  }

  /// ✅ 분석 이력 상세 조회
  /// GET /api/drug/history/{historyId}
  /// -> historyId, gptSummary, imageUrls, drugs[]
  static Future<Response> getDrugHistory(int historyId) async {
    final token = await _storage.read(key: 'accessToken');
    if (token == null || token.isEmpty) {
      throw Exception('로그인이 필요합니다. 다시 로그인해주세요.');
    }

    _dio.options.headers['Authorization'] = 'Bearer $token';

    try {
      final res = await _dio.get('/drug/history/$historyId');
      return res;
    } on DioException catch (e) {
      throw Exception('분석 이력 조회 실패: ${e.response?.data ?? e.message}');
    }
  }

  // ================ 공용 유틸 ================

  static void printLong(dynamic data) {
    const int max = 800;
    final text = data.toString();
    for (var i = 0; i < text.length; i += max) {
      debugPrint(
        text.substring(i, i + max > text.length ? text.length : i + max),
      );
    }
  }
}
