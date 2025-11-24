import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'services/drug_api_service.dart';

class CameraCapture extends StatefulWidget {
  final Function(File, Map<String, dynamic>) onAnalyzeComplete;
  final bool isAnalyzing;

  const CameraCapture({
    Key? key,
    required this.onAnalyzeComplete,
    this.isAnalyzing = false,
  }) : super(key: key);

  @override
  _CameraCaptureState createState() => _CameraCaptureState();
}

class _CameraCaptureState extends State<CameraCapture> {
  File? selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickImageFromCamera() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (photo != null) setState(() => selectedImage = File(photo.path));
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) setState(() => selectedImage = File(image.path));
  }

  Future<void> _handleAnalyze() async {
    if (selectedImage == null) return;
    setState(() => _isUploading = true);

    try {
      // 🚧 TODO: 실제 AI 분석 API 호출로 대체
      await Future.delayed(Duration(seconds: 2));

      // 예시용 itemSeq
      final mockItemSeqs = ["195700013", "202002850"];
      final result = await DrugApiService.getDrugCautions(
        itemSeqList: mockItemSeqs,
      );

      widget.onAnalyzeComplete(selectedImage!, result);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('분석 실패: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '알약 촬영',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            if (selectedImage != null)
              Stack(
                children: [
                  Image.file(selectedImage!, height: 240, fit: BoxFit.cover),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => selectedImage = null),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Icon(Icons.camera_alt, size: 48, color: Colors.grey[500]),
                  SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickImageFromCamera,
                    icon: Icon(Icons.camera),
                    label: Text('사진 촬영'),
                  ),
                  TextButton.icon(
                    onPressed: _pickImageFromGallery,
                    icon: Icon(Icons.upload),
                    label: Text('갤러리에서 선택'),
                  ),
                ],
              ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _handleAnalyze,
              icon: Icon(Icons.search),
              label: Text(_isUploading ? '분석 중...' : 'AI 분석 및 약 정보 가져오기'),
            ),
          ],
        ),
      ),
    );
  }
}
