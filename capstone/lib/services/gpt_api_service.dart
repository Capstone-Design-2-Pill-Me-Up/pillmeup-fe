import 'package:dio/dio.dart';

class GptApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://wonsandbox.cloud/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// ✅ GPT를 통한 알약 종합 주의사항 분석 요청 (Spring Boot와 일치)
  static Future<String> generateOverallCaution({
    required List<String> itemNames,
    required List<String> typeNames,
  }) async {
    try {
      final response = await _dio.get(
        '/test/gpt/overall',
        queryParameters: {'itemNames': itemNames, 'typeNames': typeNames},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data.containsKey('data')) {
          return data['data'] ?? '결과가 없습니다.';
        } else if (data is String) {
          return data;
        } else {
          return '⚠️ 응답 형식이 올바르지 않습니다.';
        }
      } else {
        return '❌ 서버 응답 오류: ${response.statusCode}';
      }
    } on DioException catch (e) {
      if (e.response != null) {
        return '🚨 서버 오류: ${e.response?.statusCode} (${e.response?.data})';
      } else {
        return '⚠️ 네트워크 오류: ${e.message}';
      }
    } catch (e) {
      return '❗ 예외 발생: $e';
    }
  }

  /// (옵션) 개별 약품 필드 생성 요청
  static Future<String> generateDetailField({
    required String itemName,
    required String entpName,
    required String fieldName,
  }) async {
    try {
      final res = await _dio.get(
        '/test/gpt/detail',
        queryParameters: {
          'itemName': itemName,
          'entpName': entpName,
          'fieldName': fieldName,
        },
      );

      return res.data['data'] ?? '결과 없음';
    } catch (e) {
      return '에러: $e';
    }
  }

  /// (옵션) DUR 주의사항 문장 생성 요청
  static Future<String> generateDrugTypeDescription({
    required String itemName,
    required String typeCode,
    required String typeName,
  }) async {
    try {
      final res = await _dio.get(
        '/test/gpt/type',
        queryParameters: {
          'itemName': itemName,
          'typeCode': typeCode,
          'typeName': typeName,
        },
      );

      return res.data['data'] ?? '결과 없음';
    } catch (e) {
      return '에러: $e';
    }
  }
}
