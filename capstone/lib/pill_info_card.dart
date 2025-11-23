import 'package:flutter/material.dart';
import 'main_dashboard.dart';

class PillInfoCard extends StatefulWidget {
  final PillInfo pillInfo;

  const PillInfoCard({Key? key, required this.pillInfo}) : super(key: key);

  @override
  _PillInfoCardState createState() => _PillInfoCardState();
}

class _PillInfoCardState extends State<PillInfoCard> {
  // 섹션별 접기 상태 관리
  final Map<String, bool> _expanded = {
    '효능·효과': true,
    '용법·용량': true,
    '경고사항': true,
    '사용상의 주의사항': true,
    '상호작용': true,
    '부작용': true,
  };

  @override
  Widget build(BuildContext context) {
    final pillInfo = widget.pillInfo;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------
            // 헤더
            // -------------------
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
                      Text(pillInfo.entpName, style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // -------------------
            // 이미지
            // -------------------
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
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.medical_services,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ),

            if (pillInfo.itemImage.isNotEmpty) SizedBox(height: 16),

            // -------------------
            // 접기/펼치기 가능한 섹션들
            // -------------------
            if (pillInfo.efcyQesitm.isNotEmpty)
              _buildCollapsibleSection(
                title: '효능·효과',
                content: pillInfo.efcyQesitm,
                icon: Icons.description,
                backgroundColor: Colors.blue[50]!,
                titleColor: Theme.of(context).primaryColor,
              ),
            if (pillInfo.useMethodQesitm.isNotEmpty)
              _buildCollapsibleSection(
                title: '용법·용량',
                content: pillInfo.useMethodQesitm,
                icon: Icons.schedule,
                backgroundColor: Colors.green[50]!,
                titleColor: Colors.green[700]!,
              ),
            if (pillInfo.atpnWarnQesitm.isNotEmpty)
              _buildCollapsibleSection(
                title: '경고사항',
                content: pillInfo.atpnWarnQesitm,
                icon: Icons.error_outline,
                backgroundColor: Colors.orange[50]!,
                titleColor: Colors.orange[700]!,
              ),
            if (pillInfo.atpnQesitm.isNotEmpty)
              _buildCollapsibleSection(
                title: '사용상의 주의사항',
                content: pillInfo.atpnQesitm,
                icon: Icons.warning,
                backgroundColor: Colors.yellow[50]!,
                titleColor: Colors.amber[800]!,
              ),
            if (pillInfo.intrcQesitm.isNotEmpty)
              _buildCollapsibleSection(
                title: '상호작용',
                content: pillInfo.intrcQesitm,
                icon: Icons.sync,
                backgroundColor: Colors.purple[50]!,
                titleColor: Colors.purple[700]!,
              ),
            if (pillInfo.seQesitm.isNotEmpty)
              _buildCollapsibleSection(
                title: '부작용',
                content: pillInfo.seQesitm,
                icon: Icons.healing,
                backgroundColor: Colors.red[50]!,
                titleColor: Colors.red[700]!,
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------
  // 접기/펼치기 가능한 섹션 위젯
  // --------------------------
  Widget _buildCollapsibleSection({
    required String title,
    required String content,
    required IconData icon,
    required Color backgroundColor,
    required Color titleColor,
  }) {
    final isOpen = _expanded[title] ?? true;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: backgroundColor.withOpacity(0.6)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _expanded[title] = !isOpen;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: titleColor),
                      SizedBox(width: 8),
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    isOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: titleColor,
                  ),
                ],
              ),
            ),
          ),
          if (isOpen)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                content,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
