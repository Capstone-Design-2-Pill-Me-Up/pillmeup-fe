import 'package:flutter/material.dart';
import 'main_dashboard.dart';

class PillInfoCard extends StatelessWidget {
  final PillInfo pillInfo;

  const PillInfoCard({Key? key, required this.pillInfo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.medical_services,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pillInfo.itemName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '품목코드: ${pillInfo.itemSeq}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.business, size: 12),
                      SizedBox(width: 4),
                      Text(
                        pillInfo.entpName,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // 의약품 이미지
            if (pillInfo.itemImage.isNotEmpty)
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      pillInfo.itemImage,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.medical_services,
                          size: 40,
                          color: Colors.grey[400],
                        );
                      },
                    ),
                  ),
                ),
              ),

            if (pillInfo.itemImage.isNotEmpty) SizedBox(height: 16),

            // 효능효과
            if (pillInfo.efcyQesitm.isNotEmpty) ...[
              _buildInfoSection(
                title: '효능·효과',
                content: pillInfo.efcyQesitm,
                icon: Icons.description,
                backgroundColor: Colors.blue[50]!,
                titleColor: Theme.of(context).primaryColor,
              ),
              SizedBox(height: 16),
            ],

            // 용법용량
            if (pillInfo.useMethodQesitm.isNotEmpty) ...[
              _buildInfoSection(
                title: '용법·용량',
                content: pillInfo.useMethodQesitm,
                icon: Icons.schedule,
                backgroundColor: Colors.green[50]!,
                titleColor: Colors.green[700]!,
              ),
              SizedBox(height: 16),
            ],

            // 사용상의 주의사항
            if (pillInfo.atpnQesitm.isNotEmpty) ...[
              _buildInfoSection(
                title: '사용상의 주의사항',
                content: pillInfo.atpnQesitm,
                icon: Icons.warning,
                backgroundColor: Colors.orange[50]!,
                titleColor: Colors.orange[700]!,
              ),
              SizedBox(height: 16),
            ],

            // 부작용
            if (pillInfo.seQesitm.isNotEmpty) ...[
              _buildInfoSection(
                title: '부작용',
                content: pillInfo.seQesitm,
                icon: Icons.error,
                backgroundColor: Colors.red[50]!,
                titleColor: Colors.red[700]!,
              ),
              SizedBox(height: 16),
            ],

            // 상호작용
            if (pillInfo.intrcQesitm.isNotEmpty) ...[
              _buildInfoSection(
                title: '상호작용',
                content: pillInfo.intrcQesitm,
                icon: Icons.sync,
                backgroundColor: Colors.purple[50]!,
                titleColor: Colors.purple[700]!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required String content,
    required IconData icon,
    required Color backgroundColor,
    required Color titleColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: titleColor),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: titleColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}