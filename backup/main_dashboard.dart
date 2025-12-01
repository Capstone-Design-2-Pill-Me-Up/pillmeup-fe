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

  // 🔽 이번 촬영(사진 한 장) 결과들 (좌우 스와이프용)
  List<AnalysisResult> currentShotResults = [];
  int currentPillIndex = 0;

  // 🔽 "촬영 1번" 단위로 묶어둔 히스토리 (각 요소가 그때 찍힌 알약 리스트)
  List<List<AnalysisResult>> shotHistory = [];

  // 🔽 지금까지 찍어서 누적된 itemSeq (여러 장 찍어도 계속 누적)
  final Set<String> _scannedItemSeqs = {};

  // 🔽 백엔드에서 내려오는 "전체 조합" 기준 종합 주의사항
  String? globalOverallCaution;

  // GPT 분석 상태
  bool isGptAnalyzing = false;
  String? gptAnalysisResult;
  String? gptAnalysisError;

  AnalysisResult _parseDrugCautionResponse(
    dynamic data, {
    String? preferredItemSeq,
  }) {
    final foundList = (data['data']['foundDrugs'] as List<dynamic>? ?? []);

    if (foundList.isEmpty) {
      throw Exception('❌ DUR 응답에 foundDrugs가 비어 있습니다.');
    }

    Map<String, dynamic> found;

    if (preferredItemSeq != null) {
      // preferredItemSeq와 itemSeq가 같은 것을 먼저 찾기
      found = foundList.cast<Map<String, dynamic>>().firstWhere(
        (d) => d['itemSeq'].toString() == preferredItemSeq,
        orElse: () => foundList.first as Map<String, dynamic>,
      );
    } else {
      // 예전처럼 0번째 사용 (fallback)
      found = foundList.first as Map<String, dynamic>;
    }

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

  Future<void> handleAnalyzeMulti(List<File> imageFiles) async {
    setState(() {
      isAnalyzing = true;
      currentShotResults = [];
      currentPillIndex = 0;
    });

    try {
      // 1) 여러 장 업로드
      final uploadRes = await ApiService.uploadMultiplePillImages(
        imageFiles: imageFiles,
      );

      print("📤 /photo/upload (MULTI) 전체 응답 ↓↓↓");
      ApiService.printLong(uploadRes.data);

      // data[] 배열
      final List<dynamic>? photos = uploadRes.data?['data'];

      if (photos == null || photos.isEmpty) {
        throw Exception("❌ 업로드 후 AI 결과가 비어 있음");
      }

      final List<AnalysisResult> allResults = [];
      dynamic firstPhotoId;
      // 🔥 모든 파일의 itemSeqList 처리
      for (final p in photos) {
        firstPhotoId ??= p['photoId'];
        final fileUrl = p['fileUrl'] as String?;
        final photoId = p['photoId'];
        final itemSeqList = (p['itemSeqList'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();

        if (itemSeqList.isEmpty) continue;

        // 전체 전역 스캔 누적
        _scannedItemSeqs.addAll(itemSeqList);

        for (final seq in itemSeqList) {
          try {
            // 1) DUR 조회
            final drugRes = await ApiService.getDrugCaution(
              itemSeqList: [seq],
              photoId: photoId,
            );

            final cautionResult = _parseDrugCautionResponse(
              drugRes.data,
              preferredItemSeq: seq,
            );

            AnalysisResult finalResult = cautionResult;

            // 2) 상세 조회
            try {
              final detailRes = await ApiService.getDrugDetail(seq);
              final detailResult = _parseDrugDetailResponse(detailRes.data);

              final mergedWarnings = <Warning>[
                ...cautionResult.warnings,
                ...detailResult.warnings,
              ];

              final imageUrl =
                  (detailResult.pillInfo.itemImage.isNotEmpty
                      ? detailResult.pillInfo.itemImage
                      : null) ??
                  (fileUrl?.isNotEmpty == true ? fileUrl : null) ??
                  '';

              finalResult = AnalysisResult(
                pillInfo: PillInfo(
                  itemName: detailResult.pillInfo.itemName,
                  itemSeq: detailResult.pillInfo.itemSeq,
                  entpName: detailResult.pillInfo.entpName,
                  itemImage: imageUrl,
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
            } catch (_) {}

            allResults.add(finalResult);
          } catch (e) {
            print("⚠️ itemSeq 처리 실패: $e");
          }
        }
      }

      if (allResults.isEmpty) {
        throw Exception("❌ 어떤 사진에서도 알약을 찾지 못했습니다.");
      }

      // 🟧 화면 반영
      setState(() {
        currentShotResults = allResults;
        currentPillIndex = 0;
        analysisResult = allResults.first;

        // ✅ 1) 촬영 세트 히스토리 (이번 촬영에서 나온 알약들을 통째로 한 묶음으로 추가)
        shotHistory.insert(0, allResults);
        if (shotHistory.length > 10) {
          shotHistory = shotHistory.take(10).toList();
        }

        // ✅ 2) 기존 per-pill 히스토리 (통계용) - 지금 쓰던 로직 그대로 유지
        final List<AnalysisResult> merged = [];
        final Set<String> seenItemSeqs = {};

        for (final r in allResults) {
          final seq = r.pillInfo.itemSeq;
          if (seenItemSeqs.add(seq)) {
            merged.add(r);
          }
        }
        for (final r in analysisHistory) {
          final seq = r.pillInfo.itemSeq;
          if (seenItemSeqs.add(seq)) {
            merged.add(r);
          }
        }
        analysisHistory = merged.take(10).toList();

        viewMode = ViewMode.result;
      });

      // 🔥🔥 여기서부터 GLOBAL overallCaution 디버그 + 계산 코드 추가 🔥🔥
      try {
        if (_scannedItemSeqs.isNotEmpty) {
          final globalDrugRes = await ApiService.getDrugCaution(
            itemSeqList: _scannedItemSeqs.toList(),
            photoId: firstPhotoId, // 멀티 대표 photoId
          );

          print("🌐 [MULTI DEBUG] /drug/caution (GLOBAL) ↓↓↓");
          ApiService.printLong(globalDrugRes.data);
          print("🌐 [MULTI DEBUG] _scannedItemSeqs: $_scannedItemSeqs");

          final data = globalDrugRes.data['data'] as Map<String, dynamic>?;

          // 1순위: data['overallCaution']
          String? oc = data?['overallCaution'] as String?;
          print("🌐 [MULTI DEBUG] data['overallCaution']: $oc");

          // 2순위: foundDrugs[*].overallCaution 합치기
          final foundList = (data?['foundDrugs'] as List<dynamic>? ?? []);
          print("🌐 [MULTI DEBUG] foundDrugs length: ${foundList.length}");

          for (final f in foundList) {
            print(
              "🌐 [MULTI DEBUG] foundDrug overallCaution: ${(f as Map)['overallCaution']}",
            );
          }

          final seen = <String>{};
          final buffer = StringBuffer();
          for (final f in foundList) {
            final m = f as Map<String, dynamic>;
            final c = m['overallCaution'] as String?;
            if (c == null) continue;
            final trimmed = c.trim();
            if (trimmed.isEmpty) continue;
            if (seen.add(trimmed)) buffer.writeln(trimmed);
          }

          final combined = buffer.toString().trim();
          print("🌐 [MULTI DEBUG] combined overallCaution: $combined");

          if (combined.isNotEmpty) {
            oc = combined;
          }

          if (mounted) {
            setState(() {
              print("🌐 [MULTI DEBUG] 최종 globalOverallCaution 저장됨: $oc");
              globalOverallCaution = oc;
            });
          }
        }
      } catch (e) {
        print('⚠️ [MULTI] 글로벌 overallCaution 조회 실패: $e');
      }
      // 🔥🔥 여기까지 추가 🔥🔥
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('🚨 분석 오류: $e')));
    } finally {
      setState(() => isAnalyzing = false);
    }
  }

  Future<void> handleAnalyze(File imageFile) async {
    setState(() {
      isAnalyzing = true;
      currentShotResults = [];
      currentPillIndex = 0;
    });

    try {
      // 1️⃣ 이미지 업로드 → AI 모델이 itemSeq 리스트 반환
      final uploadRes = await ApiService.uploadPillImage(imageFile: imageFile);
      print("📤 [DEBUG] /photo/upload FULL RESPONSE ↓↓↓");
      ApiService.printLong(uploadRes.data);

      // 업로드된 원본 사진 URL (있으면)
      final String? uploadImageUrl =
          uploadRes.data?['data']?['fileUrl'] as String?;

      final List<dynamic>? itemSeqList =
          uploadRes.data?['data']?['itemSeqList'];
      final photoId = uploadRes.data?['data']?['photoId'];

      print(
        "🔎 [DEBUG] itemSeqList: $itemSeqList  photoId: $photoId  uploadImage: $uploadImageUrl",
      );

      if (itemSeqList == null || itemSeqList.isEmpty) {
        throw Exception("❌ AI 분석 실패: item_seq를 가져오지 못함");
      }

      // 문자열 리스트로 변환
      final itemSeqStrings = itemSeqList
          .map((e) => e.toString())
          .toList(growable: false);

      print("🧠 AI 결과 item_seq 전체: $itemSeqStrings");

      // 🔥 지금까지 찍은 전체 약 목록에 이번 사진 itemSeq를 추가 (전역 상호작용용)
      _scannedItemSeqs.addAll(itemSeqStrings);
      print("📚 누적 itemSeq 목록: $_scannedItemSeqs");

      // 2️⃣ 각 itemSeq마다 개별적으로 DUR + 상세 조회 후 AnalysisResult 생성
      final List<AnalysisResult> pillResults = [];

      for (final seq in itemSeqStrings) {
        try {
          print('💊 [$seq] /drug/caution 호출 시작');

          // DUR + overallCaution 조회 (해당 알약 기준)
          final drugRes = await ApiService.getDrugCaution(
            itemSeqList: [seq], // 한 알씩 조회
            photoId: photoId,
          );

          print("💊 [$seq] /drug/caution FULL RESPONSE ↓↓↓");
          ApiService.printLong(drugRes.data);

          // caution 파싱
          final cautionResult = _parseDrugCautionResponse(
            drugRes.data,
            preferredItemSeq: seq,
          );

          AnalysisResult finalResult = cautionResult;

          try {
            // 상세 정보 조회 (/drug/{itemSeq})
            final detailRes = await ApiService.getDrugDetail(seq);
            print("📄 [$seq] /drug/$seq FULL RESPONSE ↓↓↓");
            ApiService.printLong(detailRes.data);

            final detailResult = _parseDrugDetailResponse(detailRes.data);

            // warnings 합치기 (DUR + 상세 상호작용/부작용/주의사항)
            final mergedWarnings = <Warning>[
              ...cautionResult.warnings,
              ...detailResult.warnings,
            ];

            // 사용할 이미지 URL 결정 (DB > 업로드 > caution)
            final String imageUrl =
                (detailResult.pillInfo.itemImage.isNotEmpty
                    ? detailResult.pillInfo.itemImage
                    : null) ??
                (uploadImageUrl?.isNotEmpty == true ? uploadImageUrl : null) ??
                (cautionResult.pillInfo.itemImage.isNotEmpty
                    ? cautionResult.pillInfo.itemImage
                    : '');

            finalResult = AnalysisResult(
              pillInfo: PillInfo(
                itemName: detailResult.pillInfo.itemName,
                itemSeq: detailResult.pillInfo.itemSeq,
                entpName: detailResult.pillInfo.entpName,
                itemImage: imageUrl,
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
            // 상세 조회 실패 시 cautionResult + 이미지 보정만 해서 사용
            print("⚠️ [$seq] /drug/{itemSeq} 상세 병합 실패: $e");

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

          pillResults.add(finalResult);
        } catch (e) {
          print('🚨 [$seq] 약 정보 처리 중 오류: $e');
          // 여기서 continue 해서 나머지 itemSeq는 계속 진행
        }
      }

      if (pillResults.isEmpty) {
        throw Exception('❌ 모든 알약 처리에 실패했습니다.');
      }

      print(
        '🖼 이번 촬영에서 생성된 결과 개수: ${pillResults.length}, 첫 알약 이미지: ${pillResults.first.pillInfo.itemImage}',
      );

      // 3️⃣ 상태 반영: 여러 알약 결과를 currentShotResults에 저장
      setState(() {
        currentShotResults = pillResults;
        currentPillIndex = 0;

        // 기존 로직과 호환을 위해 첫 번째 알약을 analysisResult로 유지
        analysisResult = pillResults.first;

        // ✅ 촬영 세트 히스토리 추가
        shotHistory.insert(0, pillResults);
        if (shotHistory.length > 10) {
          shotHistory = shotHistory.take(10).toList();
        }

        // 🔥 최근 분석 기록을 "알약별"로 모두 추가 + 중복 제거 + 최대 10개까지만 유지
        final List<AnalysisResult> merged = [];
        final Set<String> seenItemSeqs = {};

        // 1) 이번에 새로 나온 알약들부터 앞에 쌓기
        for (final r in pillResults) {
          final seq = r.pillInfo.itemSeq;
          if (seenItemSeqs.add(seq)) {
            merged.add(r);
          }
        }

        // 2) 기존 히스토리도 이어 붙이되, 이미 나온 itemSeq는 건너뛴다
        for (final r in analysisHistory) {
          final seq = r.pillInfo.itemSeq;
          if (seenItemSeqs.add(seq)) {
            merged.add(r);
          }
        }

        // 3) 너무 길어지지 않게 앞에서부터 최대 10개까지만
        analysisHistory = merged.take(10).toList();

        viewMode = ViewMode.result;
      });

      // 🔥 4️⃣ 지금까지 찍은 모든 약 조합 기준으로 전역 overallCaution 계산
      try {
        if (_scannedItemSeqs.isNotEmpty) {
          final globalDrugRes = await ApiService.getDrugCaution(
            itemSeqList: _scannedItemSeqs.toList(),
            photoId: photoId,
          );

          print("🌐 [DEBUG] /drug/caution (GLOBAL) ↓↓↓");
          ApiService.printLong(globalDrugRes.data);

          // 현재 스캔 누적된 itemSeq들
          print("🌐 [DEBUG] _scannedItemSeqs: $_scannedItemSeqs");

          final data = globalDrugRes.data['data'] as Map<String, dynamic>?;

          // 1순위: data['overallCaution']
          String? oc = data?['overallCaution'] as String?;
          print("🌐 [DEBUG] data['overallCaution']: $oc");

          // 2순위: foundDrugs[*].overallCaution 합치기
          final foundList = (data?['foundDrugs'] as List<dynamic>? ?? []);
          print("🌐 [DEBUG] foundDrugs length: ${foundList.length}");

          for (final f in foundList) {
            print(
              "🌐 [DEBUG] foundDrug overallCaution: ${(f as Map)['overallCaution']}",
            );
          }

          // 기존 합치기 로직 유지
          final seen = <String>{};
          final buffer = StringBuffer();

          for (final f in foundList) {
            final m = f as Map<String, dynamic>;
            final c = m['overallCaution'] as String?;
            if (c == null) continue;
            final trimmed = c.trim();
            if (trimmed.isEmpty) continue;
            if (seen.add(trimmed)) buffer.writeln(trimmed);
          }

          final combined = buffer.toString().trim();
          print("🌐 [DEBUG] combined overallCaution: $combined");

          if (combined.isNotEmpty) {
            oc = combined;
          }

          if (mounted) {
            setState(() {
              print("🌐 [DEBUG] 최종 globalOverallCaution 저장됨: $oc");
              globalOverallCaution = oc;
            });
          }
        }
      } catch (e) {
        print('⚠️ 글로벌 overallCaution 조회 실패: $e');
        if (mounted) {
          setState(() {
            globalOverallCaution = null;
          });
        }
      }

      // GPT 종합 분석은 현재 선택된 알약(첫 번째) 기준으로 필요하면 호출
      // await fetchGptOverallCaution(pillResults.first);
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
    // 1순위: 전역 overallCaution (여러 알약 조합 기준)
    String? overall = globalOverallCaution;
    if (overall == null || overall.trim().isEmpty) {
      // 2순위: 현재 선택된 알약 1개 기준
      overall = analysisResult?.overallCaution;
    }

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
                style: TextStyle(color: Colors.grey, fontSize: 14),
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
                  onAnalyzeMulti: handleAnalyzeMulti,
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
    // 이번 촬영에서 나온 알약들 (없으면 기존 analysisResult만 사용)
    final results = currentShotResults.isNotEmpty
        ? currentShotResults
        : (analysisResult != null ? [analysisResult!] : <AnalysisResult>[]);

    if (results.isEmpty) {
      // 방어 코드: 결과가 없으면 대시보드로 돌려보내기
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleBackToDashboard();
      });
      return const SizedBox.shrink();
    }

    // 현재 인덱스가 범위 밖이면 보정
    if (currentPillIndex >= results.length) {
      currentPillIndex = 0;
    }

    print(
      '🖼 resultView pills: ${results.length}, current index: $currentPillIndex, image: ${results[currentPillIndex].pillInfo.itemImage}',
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
          child: Column(
            children: [
              // 헤더
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

              // 인덱스 표시 (여러 개일 때만)
              if (results.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${currentPillIndex + 1} / ${results.length}개 알약',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              // 결과 내용 : PageView로 좌우 스와이프
              Expanded(
                child: PageView.builder(
                  itemCount: results.length,
                  controller: PageController(initialPage: currentPillIndex),
                  onPageChanged: (index) {
                    setState(() {
                      currentPillIndex = index;
                      analysisResult = results[index]; // 다른 화면에서 재사용용
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

                        // ✅ shotHistory 기준으로 렌더링
                        if (shotHistory.isEmpty)
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
                          ...shotHistory.map((shot) {
                            // shot: List<AnalysisResult> (한 번 촬영에서 나온 알약들)
                            final first = shot.first;

                            // 이 촬영에서 발견된 총 주의사항 개수
                            final totalWarnings = shot.fold<int>(
                              0,
                              (sum, r) => sum + r.warnings.length,
                            );

                            return Container(
                              margin: EdgeInsets.only(bottom: 12),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  // 대표 이미지: 첫 번째 알약
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
                                        // 알약 이름 (여러 개면 "외 N종" 붙여도 됨)
                                        Text(
                                          shot.length > 1
                                              ? '${first.pillInfo.itemName} 외 ${shot.length - 1}종'
                                              : first.pillInfo.itemName,
                                          style: TextStyle(
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
                                  if (totalWarnings > 0)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '주의사항 $totalWarnings개',
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
                                        borderRadius: BorderRadius.circular(4),
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
                                        // ✅ 이 촬영 세트 전체를 결과 화면에 넘기기
                                        currentShotResults = shot;
                                        currentPillIndex = 0;
                                        analysisResult = shot.first;
                                        viewMode = ViewMode.result;
                                      });
                                    },
                                    child: Text('상세보기'),
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
