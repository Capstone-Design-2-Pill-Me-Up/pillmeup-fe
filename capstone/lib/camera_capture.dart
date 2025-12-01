import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CameraCapture extends StatefulWidget {
  final Future<void> Function(List<File>) onAnalyzeMulti;
  final bool isAnalyzing;

  const CameraCapture({
    Key? key,
    required this.onAnalyzeMulti,
    this.isAnalyzing = false,
  }) : super(key: key);

  @override
  _CameraCaptureState createState() => _CameraCaptureState();
}

class _CameraCaptureState extends State<CameraCapture> {
  final ImagePicker _picker = ImagePicker();

  // 🔥 여러 장 이미지 저장 리스트
  final List<File> selectedImages = [];

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          selectedImages.add(File(photo.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카메라 오류: $e')));
    }
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      final List<XFile> files = await _picker.pickMultiImage(imageQuality: 80);

      if (files.isNotEmpty) {
        setState(() {
          selectedImages.addAll(files.map((f) => File(f.path)));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('갤러리 오류: $e')));
    }
  }

  void _handleAnalyze() async {
    if (selectedImages.isNotEmpty) {
      widget.onAnalyzeMulti(selectedImages);
    }
  }

  void _clearImages() {
    setState(() {
      selectedImages.clear();
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
              const Text(
                '알약 촬영/업로드',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '여러 장의 사진을 촬영하거나 업로드할 수 있습니다.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // ----------------------
              // 🔥 선택된 이미지들 미리보기
              // ----------------------
              if (selectedImages.isNotEmpty) ...[
                Container(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedImages.length,
                    separatorBuilder: (_, __) => SizedBox(width: 10),
                    itemBuilder: (_, index) {
                      final img = selectedImages[index];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              img,
                              width: 160,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: CircleAvatar(
                              backgroundColor: Colors.red,
                              radius: 14,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.close, size: 14),
                                color: Colors.white,
                                onPressed: widget.isAnalyzing
                                    ? null
                                    : () {
                                        setState(() {
                                          selectedImages.removeAt(index);
                                        });
                                      },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

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
                        : Text('${selectedImages.length}장 분석하기'),
                  ),
                ),

                const SizedBox(height: 8),

                TextButton.icon(
                  onPressed: _clearImages,
                  icon: Icon(Icons.delete),
                  label: Text("모두 삭제"),
                ),
              ],

              // ----------------------
              // ❌ 선택된 사진 없을 때
              // ----------------------
              if (selectedImages.isEmpty) ...[
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '사진을 여러 장 선택하거나 촬영해보세요',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _pickImageFromCamera,
                        icon: Icon(Icons.camera_alt),
                        label: Text('사진 촬영'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _pickImagesFromGallery,
                    icon: Icon(Icons.upload_file),
                    label: Text('갤러리에서 여러 장 선택'),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 팁
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text('💡'),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '밝은 곳에서 선명하게 찍을수록 AI 분석 정확도가 높아집니다.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
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
