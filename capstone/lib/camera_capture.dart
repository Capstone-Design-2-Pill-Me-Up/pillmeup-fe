import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CameraCapture extends StatefulWidget {
  final Future<void> Function(File) onAnalyze;
  final bool isAnalyzing;

  const CameraCapture({
    Key? key,
    required this.onAnalyze,
    this.isAnalyzing = false,
  }) : super(key: key);

  @override
  _CameraCaptureState createState() => _CameraCaptureState();
}

class _CameraCaptureState extends State<CameraCapture> {
  File? selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          selectedImage = File(photo.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카메라를 열 수 없습니다: $e')));
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('갤러리를 열 수 없습니다: $e')));
    }
  }

  void _handleAnalyze() async {
    if (selectedImage != null) {
      widget.onAnalyze(selectedImage!);
    }
  }

  void _clearImage() {
    setState(() {
      selectedImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // 제목
              Text(
                '알약 촬영',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '알약을 촬영하거나 이미지를 업로드해주세요',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),

              // 이미지 표시 영역
              if (selectedImage != null) ...[
                // 선택된 이미지 표시
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        selectedImage!,
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: widget.isAnalyzing ? null : _clearImage,
                        icon: Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // 분석 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.isAnalyzing ? null : _handleAnalyze,
                    child: widget.isAnalyzing
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('AI 분석 중...'),
                            ],
                          )
                        : Text('알약 분석하기'),
                  ),
                ),
              ] else ...[
                // 이미지 선택 영역
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 48, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        '카메라로 알약을 촬영하거나\n파일을 선택하세요',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _pickImageFromCamera,
                        icon: Icon(Icons.camera_alt),
                        label: Text('사진 촬영'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // 파일 선택 버튼
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _pickImageFromGallery,
                    icon: Icon(Icons.upload_file),
                    label: Text('파일에서 선택'),
                  ),
                ),
              ],

              SizedBox(height: 16),

              // 팁
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text('💡'),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '팁: 알약을 밝은 곳에서 선명하게 촬영해주세요',
                        style: TextStyle(color: Colors.blue[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
