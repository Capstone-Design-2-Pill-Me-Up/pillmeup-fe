import 'package:flutter/material.dart';
import 'dart:io';
import 'camera_capture.dart';
import 'pill_info_card.dart';
import 'warnings_list.dart';
import 'profile_page.dart';
import 'services/gpt_api_service.dart';
import 'services/api_service.dart';

enum ViewMode { dashboard, camera, result, profile }

class AnalysisResult {
  final PillInfo pillInfo;
  final List<Warning> warnings;
  final String? overallCaution;
  AnalysisResult({
    required this.pillInfo,
    required this.warnings,
    this.overallCaution,
  });
}

class PillInfo {
  final String itemName;
  final String itemSeq;
  final String entpName;
  final String itemImage;
  final String efcyQesitm;
  final String useMethodQesitm;
  final String atpnWarnQesitm;
  final String atpnQesitm;
  final String intrcQesitm;
  final String seQesitm;

  PillInfo({
    required this.itemName,
    required this.itemSeq,
    required this.entpName,
    required this.itemImage,
    required this.efcyQesitm,
    required this.useMethodQesitm,
    required this.atpnWarnQesitm,
    required this.atpnQesitm,
    required this.intrcQesitm,
    required this.seQesitm,
  });
}

class Warning {
  final String type;
  final WarningLevel level;
  final String message;
  final String? description;

  Warning({
    required this.type,
    required this.level,
    required this.message,
    this.description,
  });
}

enum WarningLevel { high, medium, low }

class MainDashboard extends StatefulWidget {
  final String userEmail;
  final String username;
  final VoidCallback onLogout;
  final void Function(String email, String username) onProfileUpdated;

  const MainDashboard({
    Key? key,
    required this.userEmail,
    required this.username,
    required this.onLogout,
    required this.onProfileUpdated,
  }) : super(key: key);

  @override
  _MainDashboardState createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  ViewMode viewMode = ViewMode.dashboard;
  bool isAnalyzing = false;
  AnalysisResult? analysisResult;
  List<AnalysisResult> analysisHistory = [];

  // GPT 분석 상태
  bool isGptAnalyzing = false;
  String? gptAnalysisResult;
  String? gptAnalysisError;

  AnalysisResult _parseDrugCautionResponse(dynamic data) {
    final found = data['data']['foundDrugs'][0] as Map<String, dynamic>;

    final warnings = <Warning>[];

    // 1) 기본 warnings (DUR 기반)
    for (final w in (found['warnings'] as List<dynamic>? ?? [])) {
      final m = w as Map<String, dynamic>;
      warnings.add(
        Warning(
          type: m['typeName'] ?? m['typeCode'] ?? '주의',
          level: _warningLevelFromString(m['level'] as String?),
          message: m['message'] ?? '',
          description: m['description'],
        ),
      );
    }

    // 2) 상호작용
    if ((found['intrcQesitm'] as String?)?.trim().isNotEmpty == true) {
      warnings.add(
        Warning(
          type: '상호작용',
          level: WarningLevel.medium,
          message: found['intrcQesitm'],
        ),
      );
    }

    // 3) 부작용
    if ((found['seQesitm'] as String?)?.trim().isNotEmpty == true) {
      warnings.add(
        Warning(
          type: '부작용',
          level: WarningLevel.low,
          message: found['seQesitm'],
        ),
      );
    }

    // 4) 일반 주의사항
    if ((found['atpnQesitm'] as String?)?.trim().isNotEmpty == true) {
      warnings.add(
        Warning(
          type: '주의사항',
          level: WarningLevel.low,
          message: found['atpnQesitm'],
        ),
      );
    }

    return AnalysisResult(
      pillInfo: PillInfo(
        itemSeq: found['itemSeq'].toString(),
        itemName: found['itemName'] ?? '',
        entpName: found['entpName'] ?? '',
        itemImage: found['fileUrl'] ?? found['photo'] ?? '',
        efcyQesitm: found['efcyQesitm'] ?? '',
        useMethodQesitm: found['useMethodQesitm'] ?? '',
        atpnWarnQesitm: found['atpnWarnQesitm'] ?? '',
        atpnQesitm: found['atpnQesitm'] ?? '',
        intrcQesitm: found['intrcQesitm'] ?? '',
        seQesitm: found['seQesitm'] ?? '',
      ),
      overallCaution: found['overallCaution'],
      warnings: warnings,
    );
  }

  // 문자열 level -> enum WarningLevel 변환
  WarningLevel _warningLevelFromString(String? s) {
    switch (s) {
      case 'high':
        return WarningLevel.high;
      case 'medium':
        return WarningLevel.medium;
      case 'low':
      default:
        return WarningLevel.low;
    }
  }

  // /api/drug/{itemSeq} 응답 JSON -> AnalysisResult 로 변환
  AnalysisResult _parseDrugDetailResponse(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;

    final cautions = (data['cautions'] as List<dynamic>? ?? []);

    // cautions를 한 줄씩 정리해서 atpnWarnQesitm에 넣어주기 (UI용)
    final atpnWarnText = cautions
        .map((c) {
          final m = c as Map<String, dynamic>;
          final typeName = m['typeName'] ?? '';
          final msg = m['message'] ?? '';
          return '- $typeName: $msg';
        })
        .join('\n');

    // 🔹 기본 약 정보
    final pillInfo = PillInfo(
      itemName: data['itemName'] ?? '',
      itemSeq: data['itemSeq'] ?? '',
      entpName: data['entpName'] ?? '',
      itemImage: data['fileUrl'] ?? '',
      efcyQesitm: data['efcyQesitm'] ?? '',
      useMethodQesitm: data['useMethodQesitm'] ?? '',
      atpnWarnQesitm: atpnWarnText,
      atpnQesitm: data['atpnQesitm'] ?? '',
      intrcQesitm: data['intrcQesitm'] ?? '',
      seQesitm: data['seQesitm'] ?? '',
    );

    // 🔥 여기부터가 핵심: warnings를 확장해서 상호작용/부작용/주의사항도 넣기
    final warnings = <Warning>[];

    // 1) 백엔드 DUR cautions 그대로 반영
    for (final w in cautions) {
      final m = w as Map<String, dynamic>;
      warnings.add(
        Warning(
          type: m['typeName'] ?? m['typeCode'] ?? '주의',
          level: _warningLevelFromString(m['level'] as String?),
          message: m['message'] ?? '추가 정보를 확인하세요.',
          description: m['description'],
        ),
      );
    }

    // 2) 상호작용 (intrcQesitm)
    final intrc = data['intrcQesitm'] as String?;
    if (intrc != null && intrc.trim().isNotEmpty) {
      warnings.add(
        Warning(
          type: '상호작용',
          level: WarningLevel.medium,
          message: intrc,
          description: null,
        ),
      );
    }

    // 3) 부작용 (seQesitm)
    final se = data['seQesitm'] as String?;
    if (se != null && se.trim().isNotEmpty) {
      warnings.add(
        Warning(
          type: '부작용',
          level: WarningLevel.low,
          message: se,
          description: null,
        ),
      );
    }

    // 4) 일반 주의사항 (atpnQesitm)
    final atpn = data['atpnQesitm'] as String?;
    if (atpn != null && atpn.trim().isNotEmpty) {
      warnings.add(
        Warning(
          type: '주의사항',
          level: WarningLevel.low,
          message: atpn,
          description: null,
        ),
      );
    }

    return AnalysisResult(pillInfo: pillInfo, warnings: warnings);
  }

  /* 모의 데이터를 반환하는 함수
  AnalysisResult getMockAnalysisResult() {
    final mockResults = [
      AnalysisResult(
        pillInfo: PillInfo(
          itemName: '아세트아미노펜정 500mg',
          itemSeq: 'ITEM202301001',
          entpName: '한국제약',
          itemImage:
              'https://images.unsplash.com/photo-1596522016734-8e6136fe5cfa?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxtZWRpY2FsJTIwcGlsbHMlMjBwaGFybWFjeXxlbnwxfHx8fDE3NTkxNDY1MzB8MA&ixlib=rb-4.1.0&q=80&w=200',
          efcyQesitm: '감기로 인한 발열 및 동통(통증), 두통, 신경통, 근육통, 월경통, 염좌통(삠)',
          useMethodQesitm: '성인 : 아세트아미노펜으로서 1회 300~1000mg을 1일 3~4회 경구투여한다.',
          atpnWarnQesitm: '간독성 주의, 알코올과 병용 금지',
          atpnQesitm: '간질환 환자, 신장질환 환자는 의사와 상담 후 복용',
          intrcQesitm: '와파린과 병용시 출혈 위험 증가',
          seQesitm: '구역, 구토, 식욕부진, 간기능 이상',
        ),
        warnings: [
          Warning(
            type: '병용금기',
            level: WarningLevel.high,
            message: '알코올과 함께 복용하지 마세요',
            description: '간독성이 증가할 수 있습니다.',
          ),
          Warning(
            type: '간장애환자',
            level: WarningLevel.medium,
            message: '간질환 환자는 주의하여 복용하세요',
            description: '의사와 상담 후 복용량을 조절하세요.',
          ),
        ],
      ),
      AnalysisResult(
        pillInfo: PillInfo(
          itemName: '이부프로펜정 200mg',
          itemSeq: 'ITEM202301002',
          entpName: '대한약품',
          itemImage:
              'https://images.unsplash.com/photo-1596522016734-8e6136fe5cfa?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxtZWRpY2FsJTIwcGlsbHMlMjBwaGFybWFjeXxlbnwxfHx8fDE3NTkxNDY1MzB8MA&ixlib=rb-4.1.0&q=80&w=200',
          efcyQesitm: '류마티스성 관절염, 골관절염, 근육통, 요통, 급성 통풍',
          useMethodQesitm: '성인 : 1회 200~400mg을 1일 3~4회 복용',
          atpnWarnQesitm: '위장 출혈 위험, 심혈관계 주의',
          atpnQesitm: '위궤양, 심장질환 환자 주의',
          intrcQesitm: '아스피린, 와파린과 병용 주의',
          seQesitm: '위장 장애, 두통, 현기증',
        ),
        warnings: [],
      ),
    ];

    return mockResults[(DateTime.now().millisecondsSinceEpoch ~/ 1000) %
        mockResults.length];
  } */

  // GPT API 호출 함수
  Future<void> fetchGptOverallCaution(AnalysisResult result) async {
    setState(() {
      isGptAnalyzing = true;
      gptAnalysisResult = null;
      gptAnalysisError = null;
    });

    try {
      // 약품명 추출
      final itemNames = [result.pillInfo.itemName];

      // 주의사항 타입명 추출
      final typeNames = result.warnings.map((w) => w.type).toList();

      // GPT API 호출
      final gptResponse = await GptApiService.generateOverallCaution(
        itemNames: itemNames,
        typeNames: typeNames,
      );

      setState(() {
        gptAnalysisResult = gptResponse;
        isGptAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        gptAnalysisError = e.toString();
        isGptAnalyzing = false;
      });
    }
  }

  Future<void> handleAnalyze(File imageFile) async {
    setState(() => isAnalyzing = true);

    try {
      // 1️⃣ 이미지 업로드 → AI 모델이 itemSeq 리스트 반환
      final uploadRes = await ApiService.uploadPillImage(imageFile: imageFile);
      print("📤 업로드 응답: ${uploadRes.data}");

      // 업로드된 원본 사진 URL (있으면)
      final String? uploadImageUrl =
          uploadRes.data?['data']?['fileUrl'] as String?;

      final List<dynamic>? itemSeqList =
          uploadRes.data?['data']?['itemSeqList'];
      final photoId = uploadRes.data?['data']?['photoId'];

      if (itemSeqList == null || itemSeqList.isEmpty) {
        throw Exception("❌ AI 분석 실패: item_seq를 가져오지 못함");
      }

      print("🧠 AI 결과 item_seq: $itemSeqList");

      // 2️⃣ DUR + overallCaution 조회 (/drug/caution)
      final drugRes = await ApiService.getDrugCaution(
        itemSeqList: itemSeqList.map((e) => e.toString()).toList(),
        photoId: photoId,
      );

      print("💊 약품 분석 응답 (/drug/caution): ${drugRes.data}");

      final cautionResult = _parseDrugCautionResponse(drugRes.data);

      // 기본 finalResult는 cautionResult
      AnalysisResult finalResult = cautionResult;

      try {
        // 3️⃣ 첫 번째 itemSeq 기준으로 상세 정보 조회 (/drug/{itemSeq})
        final firstItemSeq = itemSeqList.first.toString();
        final detailRes = await ApiService.getDrugDetail(firstItemSeq);
        print("📄 상세 정보 응답 (/drug/$firstItemSeq): ${detailRes.data}");

        final detailResult = _parseDrugDetailResponse(detailRes.data);

        // 3-1️⃣ warnings 합치기 (DUR + 상세 상호작용/부작용/주의사항)
        final mergedWarnings = <Warning>[
          ...cautionResult.warnings,
          ...detailResult.warnings,
        ];

        // 3-2️⃣ 사용할 이미지 URL 결정 (DB > 업로드 > caution)
        final String imageUrl =
            (detailResult.pillInfo.itemImage.isNotEmpty
                ? detailResult.pillInfo.itemImage
                : null) ??
            (uploadImageUrl?.isNotEmpty == true ? uploadImageUrl : null) ??
            (cautionResult.pillInfo.itemImage.isNotEmpty
                ? cautionResult.pillInfo.itemImage
                : '');

        // 3-3️⃣ 최종 결과 구성
        finalResult = AnalysisResult(
          pillInfo: PillInfo(
            itemName: detailResult.pillInfo.itemName,
            itemSeq: detailResult.pillInfo.itemSeq,
            entpName: detailResult.pillInfo.entpName,
            itemImage: imageUrl, // 🔥 여기서 최종 확정
            efcyQesitm: detailResult.pillInfo.efcyQesitm,
            useMethodQesitm: detailResult.pillInfo.useMethodQesitm,
            atpnWarnQesitm: detailResult.pillInfo.atpnWarnQesitm,
            atpnQesitm: detailResult.pillInfo.atpnQesitm,
            intrcQesitm: detailResult.pillInfo.intrcQesitm,
            seQesitm: detailResult.pillInfo.seQesitm,
          ),
          warnings: mergedWarnings,
          overallCaution: cautionResult.overallCaution,
        );
      } catch (e) {
        // 상세 조회/머지 실패해도 cautionResult + 업로드/기타 이미지로 최대한 채움
        print("⚠️ /drug/{itemSeq} 상세 병합 실패: $e");

        final String imageUrl =
            (cautionResult.pillInfo.itemImage.isNotEmpty
                ? cautionResult.pillInfo.itemImage
                : null) ??
            (uploadImageUrl?.isNotEmpty == true ? uploadImageUrl : null) ??
            '';

        finalResult = AnalysisResult(
          pillInfo: PillInfo(
            itemName: cautionResult.pillInfo.itemName,
            itemSeq: cautionResult.pillInfo.itemSeq,
            entpName: cautionResult.pillInfo.entpName,
            itemImage: imageUrl,
            efcyQesitm: cautionResult.pillInfo.efcyQesitm,
            useMethodQesitm: cautionResult.pillInfo.useMethodQesitm,
            atpnWarnQesitm: cautionResult.pillInfo.atpnWarnQesitm,
            atpnQesitm: cautionResult.pillInfo.atpnQesitm,
            intrcQesitm: cautionResult.pillInfo.intrcQesitm,
            seQesitm: cautionResult.pillInfo.seQesitm,
          ),
          warnings: cautionResult.warnings,
          overallCaution: cautionResult.overallCaution,
        );
      }

      print('🖼 최종 finalResult image: ${finalResult.pillInfo.itemImage}');

      // 4️⃣ 상태 반영
      setState(() {
        analysisResult = finalResult;
        analysisHistory = [finalResult, ...analysisHistory.take(4).toList()];
        viewMode = ViewMode.result;
      });

      // GPT는 백에서 overallCaution 돌리고 있으니 생략 가능
      // await fetchGptOverallCaution(finalResult);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('🚨 분석 오류: $e')));
    } finally {
      setState(() => isAnalyzing = false);
    }
  }

  void handleNewScan() {
    setState(() {
      analysisResult = null;
      viewMode = ViewMode.camera;
    });
  }

  void handleBackToDashboard() {
    setState(() {
      viewMode = ViewMode.dashboard;
      //analysisResult = null;
    });
  }

  void handleOpenProfile() {
    setState(() {
      viewMode = ViewMode.profile;
    });
  }

  void handleUpdateProfile(String email, String username) {
    widget.onProfileUpdated(email, username);
  }

  void handleDeleteAccount() {
    // 백엔드 API 호출 예정
    // 계정 삭제 후 로그아웃
    widget.onLogout();
  }

  Widget _buildGptAnalysisCard() {
    final overall = analysisResult?.overallCaution;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3E8FF), Color(0xFFE0E7FF)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD8B4FE), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🤖 AI 종합 분석',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'AI/DUR 기반으로 생성된 전반적인 주의사항 안내',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (overall == null || overall.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                  ),
                  child: Text(
                    '아직 종합 주의사항 정보가 없습니다.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    overall,
                    style: const TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (viewMode == ViewMode.camera) {
      return _buildCameraView();
    }

    if (viewMode == ViewMode.result && analysisResult != null) {
      return _buildResultView();
    }

    if (viewMode == ViewMode.profile) {
      return ProfilePage(
        userEmail: widget.userEmail,
        username: widget.username,
        onBack: handleBackToDashboard,
        onUpdateProfile: handleUpdateProfile,
        onDeleteAccount: handleDeleteAccount,
      );
    }

    return _buildDashboardView();
  }

  Widget _buildCameraView() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0F4FF), Color(0xFFE0E7FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 헤더
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: handleBackToDashboard,
                      icon: Icon(Icons.arrow_back),
                      label: Text('대시보드로'),
                    ),
                    Text(
                      '알약 촬영',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 100), // 여백
                  ],
                ),
              ),

              // 카메라 캡처
              Expanded(
                child: CameraCapture(
                  onAnalyze: handleAnalyze,
                  isAnalyzing: isAnalyzing,
                ),
              ),

              // 분석 중 표시
              if (isAnalyzing)
                Container(
                  margin: EdgeInsets.all(24),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'AI가 알약을 분석 중입니다',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '잠시만 기다려주세요...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultView() {
    print('🖼 resultView image: ${analysisResult?.pillInfo.itemImage}');

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0F4FF), Color(0xFFE0E7FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 헤더
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: handleBackToDashboard,
                      icon: Icon(Icons.arrow_back),
                      label: Text('대시보드로'),
                    ),
                    Text(
                      '분석 결과',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: handleNewScan,
                      icon: Icon(Icons.camera_alt, size: 16),
                      label: Text('새 촬영'),
                    ),
                  ],
                ),
              ),

              // 결과 내용
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 🔥 약 사진 썸네일
                      /*if (analysisResult!.pillInfo.itemImage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              analysisResult!.pillInfo.itemImage,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.medical_services,
                                    size: 40,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),*/
                      PillInfoCard(pillInfo: analysisResult!.pillInfo),
                      const SizedBox(height: 16),
                      WarningsList(warnings: analysisResult!.warnings),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardView() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0F4FF), Color(0xFFE0E7FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.medical_services,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pill Me Up',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '안녕하세요, ${widget.username}님',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: handleOpenProfile,
                          icon: Icon(Icons.person_outline),
                        ),
                        IconButton(
                          onPressed: widget.onLogout,
                          icon: Icon(Icons.logout),
                        ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // 메인 액션 카드
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.indigo],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.camera_alt,
                        color: Colors.white.withOpacity(0.9),
                        size: 64,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '알약을 촬영하세요',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'AI가 알약을 분석하여 안전한 복용 정보를 제공합니다',
                        style: TextStyle(color: Colors.white.withOpacity(0.9)),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            viewMode = ViewMode.camera;
                          });
                        },
                        icon: Icon(Icons.camera_alt),
                        label: Text('알약 촬영하기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // 통계 카드들
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${analysisHistory.length}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '분석 완료',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.warning,
                                color: Colors.orange,
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${analysisHistory.fold(0, (sum, result) => sum + result.warnings.length)}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '발견된 주의사항',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8),

                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.cancel, color: Colors.red, size: 32),
                        SizedBox(height: 8),
                        Text(
                          '${analysisHistory.where((result) => result.warnings.any((w) => w.level == WarningLevel.high)).length}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '고위험 경고',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // GPT API 전반적인 주의사항
                if (analysisResult != null) _buildGptAnalysisCard(),

                if (analysisResult != null) SizedBox(height: 24),

                // 최근 분석 기록
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history),
                            SizedBox(width: 8),
                            Text(
                              '최근 분석 기록',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '최근에 분석한 의약품 목록입니다',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        SizedBox(height: 16),
                        if (analysisHistory.isEmpty)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.medical_services,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '아직 분석한 알약이 없습니다',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '첫 번째 알약을 촬영해보세요!',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...analysisHistory
                              .map(
                                (result) => Container(
                                  margin: EdgeInsets.only(bottom: 12),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          result.pillInfo.itemImage,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  width: 48,
                                                  height: 48,
                                                  color: Colors.grey[300],
                                                  child: Icon(
                                                    Icons.medical_services,
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              result.pillInfo.itemName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              result.pillInfo.entpName,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (result.warnings.isNotEmpty)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red[100],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '주의사항 ${result.warnings.length}개',
                                            style: TextStyle(
                                              color: Colors.red[800],
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '안전',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            analysisResult =
                                                result; // 이 기록을 현재 선택된 결과로 설정
                                            viewMode =
                                                ViewMode.result; // 결과 화면으로 전환
                                          });
                                        },
                                        child: Text('상세보기'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
