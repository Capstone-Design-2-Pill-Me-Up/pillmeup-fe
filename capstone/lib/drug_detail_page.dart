import 'package:flutter/material.dart';

class DrugDetailPage extends StatelessWidget {
  final Map<String, dynamic> detail;

  const DrugDetailPage({Key? key, required this.detail}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = detail['data'];
    return Scaffold(
      appBar: AppBar(title: Text(data['itemName'] ?? "약품 상세")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("제조사: ${data['entpName'] ?? ''}"),
            SizedBox(height: 10),
            Text("효능: ${data['efcyQesitm'] ?? '정보 없음'}"),
            SizedBox(height: 10),
            Text("주의사항: ${data['atpnQesitm'] ?? '정보 없음'}"),
          ],
        ),
      ),
    );
  }
}
