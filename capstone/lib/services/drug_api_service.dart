import 'package:dio/dio.dart';

class DrugApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://wonsandbox.cloud/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// AI 인식 결과 기반 DUR 주의사항 조회
  static Future<Map<String, dynamic>> getDrugCautions({
    required List<String> itemSeqList,
    int? memberId,
    int? photoId,
  }) async {
    final response = await _dio.post(
      '/drug/caution',
      queryParameters: {
        if (memberId != null) 'memberId': memberId,
        if (photoId != null) 'photoId': photoId,
      },
      data: {"itemSeqList": itemSeqList},
    );
    if (response.statusCode == 200) {
      return response.data['data'] ?? {};
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  }

  /// 개별 약품 상세정보 조회
  static Future<Map<String, dynamic>> getDrugDetail(
    String itemSeq, {
    int? historyId,
  }) async {
    final response = await _dio.get(
      '/drug/$itemSeq',
      queryParameters: {if (historyId != null) 'historyId': historyId},
    );

    if (response.statusCode == 200) {
      return response.data['data'] ?? {};
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  }
}
