import 'package:flutter/material.dart';
import 'dart:io';
import 'camera_capture.dart';
import 'pill_info_card.dart';
import 'warnings_list.dart';

enum ViewMode { dashboard, camera, result }

class AnalysisResult {
  final PillInfo pillInfo;
  final List<Warning> warnings;

  AnalysisResult({required this.pillInfo, required this.warnings});
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
  final String username;
  final VoidCallback onLogout;

  const MainDashboard({
    Key? key,
    required this.username,
    required this.onLogout,
  }) : super(key: key);

  @override
  _MainDashboardState createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  ViewMode viewMode = ViewMode.dashboard;
  bool isAnalyzing = false;
  AnalysisResult? analysisResult;
  List<AnalysisResult> analysisHistory = [];

  // 모의 데이터를 반환하는 함수
  AnalysisResult getMockAnalysisResult() {
    final mockResults = [
      AnalysisResult(
        pillInfo: PillInfo(
          itemName: '아세트아미노펜정 500mg',
          itemSeq: 'ITEM202301001',
          entpName: '한국제약',
          itemImage: 'https://images.unsplash.com/photo-1596522016734-8e6136fe5cfa?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxtZWRpY2FsJTIwcGlsbHMlMjBwaGFybWFjeXxlbnwxfHx8fDE3NTkxNDY1MzB8MA&ixlib=rb-4.1.0&q=80&w=200',
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
          itemImage: 'https://images.unsplash.com/photo-1596522016734-8e6136fe5cfa?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxtZWRpY2FsJTIwcGlsbHMlMjBwaGFybWFjeXxlbnwxfHx8fDE3NTkxNDY1MzB8MA&ixlib=rb-4.1.0&q=80&w=200',
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
    
    return mockResults[(DateTime.now().millisecondsSinceEpoch ~/ 1000) % mockResults.length];
  }

  Future<void> handleAnalyze(File imageFile) async {
    setState(() {
      isAnalyzing = true;
    });

    // 모의 AI 분석 지연
    await Future.delayed(Duration(seconds: 3));
    
    final result = getMockAnalysisResult();
    setState(() {
      analysisResult = result;
      analysisHistory = [result, ...analysisHistory.take(4).toList()];
      isAnalyzing = false;
      viewMode = ViewMode.result;
    });
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
      analysisResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (viewMode == ViewMode.camera) {
      return _buildCameraView();
    }

    if (viewMode == ViewMode.result && analysisResult != null) {
      return _buildResultView();
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
            colors: [
              Color(0xFFF0F4FF),
              Color(0xFFE0E7FF),
            ],
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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0F4FF),
              Color(0xFFE0E7FF),
            ],
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
                      PillInfoCard(pillInfo: analysisResult!.pillInfo),
                      SizedBox(height: 16),
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
            colors: [
              Color(0xFFF0F4FF),
              Color(0xFFE0E7FF),
            ],
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
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {},
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
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                        ),
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
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
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
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
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
                        Icon(
                          Icons.cancel,
                          color: Colors.red,
                          size: 32,
                        ),
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
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24),

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
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
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
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
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
                          ...analysisHistory.map((result) => Container(
                            margin: EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
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
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 48,
                                        height: 48,
                                        color: Colors.grey[300],
                                        child: Icon(Icons.medical_services),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                      borderRadius: BorderRadius.circular(4),
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
                                  onPressed: () {},
                                  child: Text('상세보기'),
                                ),
                              ],
                            ),
                          )).toList(),
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