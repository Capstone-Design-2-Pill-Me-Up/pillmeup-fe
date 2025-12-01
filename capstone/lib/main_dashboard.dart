import 'package:flutter/material.dart';
import 'dart:io';
import 'camera_capture.dart';
import 'pill_info_card.dart';
import 'warnings_list.dart';
import 'profile_page.dart';
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

/// 🔹 historyId 1개(한 번 분석)를 나타내는 모델
class AnalysisShot {
  final int historyId;
  final String? gptSummary; // history 단위 GPT 요약
  final List<String> imageUrls; // 이 분석에서 사용된 사진들
  final List<AnalysisResult> results; // 감지된 약들

  AnalysisShot({
    required this.historyId,
    required this.results,
    required this.imageUrls,
    this.gptSummary,
  });
}

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

  /// 현재 선택된 약(페이지뷰에서 현재 페이지)
  AnalysisResult? analysisResult;

  /// 현재 보고 있는 분석 세트 (historyId 1개)
  AnalysisShot? currentShot;

  /// 최근 분석 기록 (history 단위 리스트)
  List<AnalysisShot> shotHistory = [];

  int currentPillIndex = 0;

  // ---------------- 공통 유틸 ----------------

  WarningLevel _warningLevelFromString(String? s) {
    switch (s?.toLowerCase()) {
      // 🔥 소문자로 통일
      case 'high':
        return WarningLevel.high;
      case 'medium':
        return WarningLevel.medium;
      case 'low':
      default:
        return WarningLevel.low;
    }
  }

  /// 🔥 GET /api/drug/history/{historyId} 응답 → AnalysisShot 으로 변환
  AnalysisShot _parseHistoryResponse(dynamic json) {
    final dynamic raw = json['data'];

    Map<String, dynamic> data;

    if (raw is Map<String, dynamic>) {
      data = raw;
    } else if (raw is List &&
        raw.isNotEmpty &&
        raw.first is Map<String, dynamic>) {
      data = raw.first as Map<String, dynamic>;
    } else {
      throw Exception('예상치 못한 history 응답 형식입니다: ${raw.runtimeType}');
    }

    final int historyId = data['historyId'] as int;
    final String? gptSummary = data['gptSummary'] as String?;

    // 🔥 history 전체 이미지 리스트
    final List<String> imageUrls = (data['imageUrls'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    final List<dynamic> drugsJson = data['drugs'] as List<dynamic>? ?? [];

    // 🔥 index 기반으로 drug <-> image 매핑
    final List<AnalysisResult> results = [];
    for (int i = 0; i < drugsJson.length; i++) {
      final m = drugsJson[i] as Map<String, dynamic>;

      // 약 이미지 우선순위:
      // 1) drug.fileUrl
      // 2) imageUrls[i]
      // 3) imageUrls.first
      String itemImage = '';
      if (m['fileUrl'] != null && (m['fileUrl'] as String).isNotEmpty) {
        itemImage = m['fileUrl'] as String;
      } else if (imageUrls.isNotEmpty) {
        if (i < imageUrls.length) {
          itemImage = imageUrls[i];
        } else {
          itemImage = imageUrls.first;
        }
      }

      final pillInfo = PillInfo(
        itemName: m['itemName'] ?? '',
        itemSeq: m['itemSeq']?.toString() ?? '',
        entpName: m['entpName'] ?? '',
        itemImage: itemImage, // ✅ 여기!
        efcyQesitm: m['efcyQesitm'] ?? '',
        useMethodQesitm: m['useMethodQesitm'] ?? '',
        atpnWarnQesitm: m['atpnQesitm'] ?? '',
        atpnQesitm: m['atpnQesitm'] ?? '',
        intrcQesitm: m['intrcQesitm'] ?? '',
        seQesitm: m['seQesitm'] ?? '',
      );

      final warnings = <Warning>[];
      for (final w in (m['cautions'] as List<dynamic>? ?? [])) {
        final wm = w as Map<String, dynamic>;
        warnings.add(
          Warning(
            type: wm['typeName'] ?? wm['typeCode'] ?? '주의',
            level: _warningLevelFromString(wm['level'] as String?),
            message: wm['message'] ?? '',
            description: wm['description'],
          ),
        );
      }

      results.add(
        AnalysisResult(
          pillInfo: pillInfo,
          warnings: warnings,
          overallCaution: m['gptCautionSummary'] as String?,
        ),
      );
    }

    return AnalysisShot(
      historyId: historyId,
      gptSummary: gptSummary,
      imageUrls: imageUrls,
      results: results,
    );
  }

  Future<void> handleAnalyzeMulti(List<File> imageFiles) async {
    setState(() {
      isAnalyzing = true;
      currentShot = null;
      analysisResult = null;
      currentPillIndex = 0;
    });

    try {
      // 1) 사진 여러 장 업로드
      final uploadRes = await ApiService.uploadMultiplePillImages(
        imageFiles: imageFiles,
      );

      debugPrint("📤 [MULTI] /photo/upload 전체 응답 ↓↓↓");
      ApiService.printLong(uploadRes.data);

      final dynamic rawData = uploadRes.data['data'];

      // ✅ itemSeqList, historyId 둘 다 뽑기
      final List<String> itemSeqList = [];
      int? historyId;

      if (rawData is List) {
        for (final item in rawData) {
          final m = item as Map<String, dynamic>;

          // itemSeqList 모으기
          final seqs = m['itemSeqList'] as List<dynamic>? ?? [];
          itemSeqList.addAll(seqs.map((e) => e.toString()));

          // historyId는 한 번만 세팅 (모든 요소가 같은 값일 것)
          if (historyId == null && m['historyId'] != null) {
            historyId = m['historyId'] as int;
          }
        }
      } else if (rawData is Map<String, dynamic>) {
        final seqs = rawData['itemSeqList'] as List<dynamic>? ?? [];
        itemSeqList.addAll(seqs.map((e) => e.toString()));

        if (rawData['historyId'] != null) {
          historyId = rawData['historyId'] as int;
        }
      } else {
        throw Exception(
          'photo/upload data 형식이 예상과 다릅니다: ${rawData.runtimeType}',
        );
      }

      if (itemSeqList.isEmpty) {
        throw Exception('업로드 응답에서 itemSeqList를 찾지 못했습니다.');
      }
      if (historyId == null) {
        throw Exception('업로드 응답에서 historyId를 찾지 못했습니다.');
      }

      debugPrint('📸 [MULTI] historyId=$historyId, itemSeqList=$itemSeqList');

      // 2) 주의사항 분석 트리거 (❗ 더 이상 0 넣지 말고, 진짜 historyId 사용)
      final cautionRes = await ApiService.requestDrugCaution(
        historyId: historyId!,
        itemSeqList: itemSeqList,
      );

      debugPrint("⚠️ [MULTI] /drug/caution 응답 ↓↓↓");
      ApiService.printLong(cautionRes.data);

      // 3) history 상세 조회
      final historyRes = await ApiService.getDrugHistory(historyId!);
      debugPrint("📄 [MULTI] /drug/history 응답 ↓↓↓");
      ApiService.printLong(historyRes.data);

      final shot = _parseHistoryResponse(historyRes.data);

      setState(() {
        currentShot = shot;
        currentPillIndex = 0;
        analysisResult = shot.results.isNotEmpty ? shot.results.first : null;

        shotHistory.insert(0, shot);
        if (shotHistory.length > 10) {
          shotHistory = shotHistory.take(10).toList();
        }

        viewMode = ViewMode.result;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('🚨 분석 오류: $e')));
    } finally {
      setState(() => isAnalyzing = false);
    }
  }

  /// 단일 사진 분석
  Future<void> handleAnalyze(File imageFile) async {
    setState(() {
      isAnalyzing = true;
      currentShot = null;
      analysisResult = null;
      currentPillIndex = 0;
    });

    try {
      // 1) 사진 1장 업로드
      final uploadRes = await ApiService.uploadPillImage(imageFile: imageFile);

      debugPrint("📤 [SINGLE] /photo/upload 전체 응답 ↓↓↓");
      ApiService.printLong(uploadRes.data);

      final dynamic rawData = uploadRes.data['data'];

      final List<String> itemSeqList = [];
      int? historyId;

      if (rawData is List && rawData.isNotEmpty) {
        final m = rawData.first as Map<String, dynamic>;
        final seqs = m['itemSeqList'] as List<dynamic>? ?? [];
        itemSeqList.addAll(seqs.map((e) => e.toString()));
        if (m['historyId'] != null) {
          historyId = m['historyId'] as int;
        }
      } else if (rawData is Map<String, dynamic>) {
        final seqs = rawData['itemSeqList'] as List<dynamic>? ?? [];
        itemSeqList.addAll(seqs.map((e) => e.toString()));
        if (rawData['historyId'] != null) {
          historyId = rawData['historyId'] as int;
        }
      } else {
        throw Exception(
          'photo/upload data 형식이 예상과 다릅니다: ${rawData.runtimeType}',
        );
      }

      if (itemSeqList.isEmpty) {
        throw Exception('업로드 응답에서 itemSeqList를 찾지 못했습니다.');
      }
      if (historyId == null) {
        throw Exception('업로드 응답에서 historyId를 찾지 못했습니다.');
      }

      debugPrint('📸 [SINGLE] historyId=$historyId, itemSeqList=$itemSeqList');

      // 2) 주의사항 분석 트리거
      final cautionRes = await ApiService.requestDrugCaution(
        historyId: historyId!,
        itemSeqList: itemSeqList,
      );

      debugPrint("⚠️ [SINGLE] /drug/caution 응답 ↓↓↓");
      ApiService.printLong(cautionRes.data);

      // 3) history 상세 조회
      final historyRes = await ApiService.getDrugHistory(historyId!);
      debugPrint("📄 [SINGLE] /drug/history 응답 ↓↓↓");
      ApiService.printLong(historyRes.data);

      final shot = _parseHistoryResponse(historyRes.data);

      setState(() {
        currentShot = shot;
        currentPillIndex = 0;
        analysisResult = shot.results.isNotEmpty ? shot.results.first : null;

        shotHistory.insert(0, shot);
        if (shotHistory.length > 10) {
          shotHistory = shotHistory.take(10).toList();
        }

        viewMode = ViewMode.result;
      });
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
      currentShot = null;
      viewMode = ViewMode.camera;
    });
  }

  void handleBackToDashboard() {
    setState(() {
      viewMode = ViewMode.dashboard;
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
    widget.onLogout();
  }

  // ---------------- UI 빌더들 ----------------

  /// AI 종합 분석 카드
  Widget _buildGptAnalysisCard() {
    String? overall = currentShot?.gptSummary;
    overall ??= analysisResult?.overallCaution;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: false, // 기본은 접힌 상태
        title: Row(
          children: const [
            Icon(Icons.smart_toy, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Text(
              'AI 종합 분석',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        subtitle: const Text(
          'AI/DUR 기반 전반적 주의사항 안내',
          style: TextStyle(fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFFE9D5FF)),
            ),
            padding: const EdgeInsets.all(12),
            child: Text(
              (overall == null || overall.trim().isEmpty)
                  ? '아직 종합 주의사항 정보가 없습니다.'
                  : overall!,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (viewMode == ViewMode.camera) {
      return _buildCameraView();
    }

    if (viewMode == ViewMode.result && currentShot != null) {
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0F4FF), Color(0xFFE0E7FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: handleBackToDashboard,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('대시보드로'),
                    ),
                    const Text(
                      '알약 촬영',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 100),
                  ],
                ),
              ),
              Expanded(
                child: CameraCapture(
                  onAnalyzeMulti: handleAnalyzeMulti,
                  isAnalyzing: isAnalyzing,
                ),
              ),
              if (isAnalyzing)
                Container(
                  margin: const EdgeInsets.all(24),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          const Text(
                            'AI가 알약을 분석 중입니다',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
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
    final results = currentShot?.results ?? <AnalysisResult>[];

    if (results.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleBackToDashboard();
      });
      return const SizedBox.shrink();
    }

    if (currentPillIndex >= results.length) {
      currentPillIndex = 0;
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0F4FF), Color(0xFFE0E7FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 상단 헤더
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: handleBackToDashboard,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('대시보드로'),
                    ),
                    const Text(
                      '분석 결과',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: handleNewScan,
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: const Text('새 촬영'),
                    ),
                  ],
                ),
              ),
              if (results.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      Text(
                        '${currentPillIndex + 1} / ${results.length}개 알약',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(width: 4),
                          Text(
                            '옆으로 스와이프하여 다른 알약 보기 ',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.swipe_right, size: 14, color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                ),

              // ✅ 여기 추가: historyId 기준 AI 종합 분석 카드
              if (currentShot != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _buildGptAnalysisCard(),
                ),

              // 약별 상세 카드 + 경고 리스트
              Expanded(
                child: PageView.builder(
                  itemCount: results.length,
                  controller: PageController(initialPage: currentPillIndex),
                  onPageChanged: (index) {
                    setState(() {
                      currentPillIndex = index;
                      analysisResult = results[index];
                    });
                  },
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          PillInfoCard(pillInfo: result.pillInfo),
                          const SizedBox(height: 16),
                          WarningsList(warnings: result.warnings),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardView() {
    // 통계 계산용
    final int totalAnalyses = shotHistory.length;
    final int totalWarnings = shotHistory.fold<int>(
      0,
      (sum, shot) =>
          sum + shot.results.fold<int>(0, (s, r) => s + r.warnings.length),
    );
    final int highRiskCount = shotHistory.fold<int>(
      0,
      (sum, shot) =>
          sum +
          shot.results
              .where((r) => r.warnings.any((w) => w.level == WarningLevel.high))
              .length,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0F4FF), Color(0xFFE0E7FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.medical_services,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
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
                          icon: const Icon(Icons.person_outline),
                        ),
                        IconButton(
                          onPressed: widget.onLogout,
                          icon: const Icon(Icons.logout),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 메인 액션 카드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
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
                      const SizedBox(height: 16),
                      const Text(
                        '알약을 촬영하세요',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AI가 알약을 분석하여 안전한 복용 정보를 제공합니다',
                        style: TextStyle(color: Colors.white.withOpacity(0.9)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            viewMode = ViewMode.camera;
                          });
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('알약 촬영하기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 통계 카드들
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$totalAnalyses',
                                style: const TextStyle(
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.warning,
                                color: Colors.orange,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$totalWarnings',
                                style: const TextStyle(
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

                const SizedBox(height: 8),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.cancel, color: Colors.red, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          '$highRiskCount',
                          style: const TextStyle(
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

                const SizedBox(height: 24),

                // if (currentShot != null) _buildGptAnalysisCard(),
                // if (currentShot != null) const SizedBox(height: 24),

                // 최근 분석 기록 (history 단위)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
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
                        const SizedBox(height: 8),
                        Text(
                          '최근에 분석한 의약품 목록입니다',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        if (shotHistory.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.medical_services,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '아직 분석한 알약이 없습니다',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '첫 번째 알약을 촬영해보세요!',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...shotHistory.map((shot) {
                            final first = shot.results.first;
                            final totalWarningsForShot = shot.results.fold<int>(
                              0,
                              (sum, r) => sum + r.warnings.length,
                            );

                            // ✅ 썸네일 URL: 약 이미지가 있으면 그걸 쓰고, 없으면 history 이미지 사용
                            String thumbUrl = first.pillInfo.itemImage;
                            if (thumbUrl.isEmpty && shot.imageUrls.isNotEmpty) {
                              thumbUrl = shot.imageUrls.first;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      first.pillInfo.itemImage,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              width: 48,
                                              height: 48,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.medical_services,
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          shot.results.length > 1
                                              ? '${first.pillInfo.itemName} 외 ${shot.results.length - 1}종'
                                              : first.pillInfo.itemName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          first.pillInfo.entpName,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (totalWarningsForShot > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '주의사항 $totalWarningsForShot개',
                                        style: TextStyle(
                                          color: Colors.red[800],
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '안전',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () async {
                                      // 필요하면 최신 상태를 위해 서버에서 다시 조회해도 됨
                                      try {
                                        final res =
                                            await ApiService.getDrugHistory(
                                              shot.historyId,
                                            );
                                        final latestShot =
                                            _parseHistoryResponse(res.data);
                                        setState(() {
                                          currentShot = latestShot;
                                          currentPillIndex = 0;
                                          analysisResult =
                                              latestShot.results.isNotEmpty
                                              ? latestShot.results.first
                                              : null;
                                          viewMode = ViewMode.result;
                                        });
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('상세 분석 조회 실패: $e'),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('상세보기'),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
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
