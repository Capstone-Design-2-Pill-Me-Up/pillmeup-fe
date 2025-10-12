import 'package:flutter/material.dart';
import 'main_dashboard.dart';

class WarningsList extends StatelessWidget {
  final List<Warning> warnings;

  const WarningsList({Key? key, required this.warnings}) : super(key: key);

  IconData _getWarningIcon(String type) {
    switch (type) {
      case '병용금기':
        return Icons.medication;
      case '연령금기':
        return Icons.people;
      case '임부금기':
        return Icons.child_care;
      case '용량주의':
        return Icons.warning;
      case '투여기간주의':
        return Icons.schedule;
      case '노인주의':
        return Icons.elderly;
      case '신장애환자':
      case '간장애환자':
        return Icons.favorite;
      case '특정기능주의':
        return Icons.security;
      default:
        return Icons.warning;
    }
  }

  Color _getWarningColor(WarningLevel level) {
    switch (level) {
      case WarningLevel.high:
        return Colors.red;
      case WarningLevel.medium:
        return Colors.orange;
      case WarningLevel.low:
        return Colors.yellow[700]!;
    }
  }

  String _getWarningLevelText(WarningLevel level) {
    switch (level) {
      case WarningLevel.high:
        return '고위험';
      case WarningLevel.medium:
        return '중위험';
      case WarningLevel.low:
        return '저위험';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.security,
                    color: Colors.green[600],
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '안전성 검사 결과',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.security,
                        color: Colors.green[600],
                        size: 32,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '안전합니다',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.green[800],
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '현재 확인된 주의사항이 없습니다.',
                      style: TextStyle(
                        color: Colors.green[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 위험도 순으로 정렬
    final sortedWarnings = List<Warning>.from(warnings);
    sortedWarnings.sort((a, b) {
      const levelOrder = {
        WarningLevel.high: 0,
        WarningLevel.medium: 1,
        WarningLevel.low: 2,
      };
      return levelOrder[a.level]! - levelOrder[b.level]!;
    });

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.red[600],
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  '주의사항 (${warnings.length}개)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[600],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // 경고 목록
            ...sortedWarnings.map((warning) => Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: _getWarningColor(warning.level),
                    width: 4,
                  ),
                ),
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getWarningColor(warning.level).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _getWarningIcon(warning.type),
                      color: _getWarningColor(warning.level),
                      size: 16,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              warning.type,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: _getWarningColor(warning.level).withOpacity(0.8),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getWarningColor(warning.level),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getWarningLevelText(warning.level),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          warning.message,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (warning.description != null) ...[
                          SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              warning.description!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),

            // 중요 안내사항
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info,
                    color: Colors.blue[600],
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '중요 안내사항',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[800],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '의약품 복용 전 반드시 의사나 약사와 상담하세요. 이 정보는 참고용이며, 전문의의 진료를 대체할 수 없습니다.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}