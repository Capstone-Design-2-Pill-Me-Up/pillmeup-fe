import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'services/api_service.dart';

class ProfilePage extends StatefulWidget {
  final String userEmail;
  final String username;
  final VoidCallback onBack;
  final Function(String email, String username) onUpdateProfile;
  final VoidCallback onDeleteAccount;

  const ProfilePage({
    Key? key,
    required this.userEmail,
    required this.username,
    required this.onBack,
    required this.onUpdateProfile,
    required this.onDeleteAccount,
  }) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _emailController;
  late TextEditingController _usernameController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.userEmail);
    _usernameController = TextEditingController(text: widget.username);
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleUpdateProfile() async {
    // 사용자명 검사
    if (_usernameController.text.trim().isEmpty) {
      _showAlert('사용자명을 입력해주세요.');
      return;
    }
    try {
      await ApiService.updateName(name: _usernameController.text.trim());
      // AppRoot/대시보드로 "name"만 반영. email은 변경 불가라 기존 값 유지
      widget.onUpdateProfile(
        _emailController.text.trim(),
        _usernameController.text.trim(),
      );
      _showAlert('프로필이 업데이트되었습니다.');

      setState(() {
        _isEditing = false;
      });
    } on DioException catch (e) {
      _showAlert('프로필 업데이트 실패: ${e.response?.data ?? e.message}');
    } catch (e) {
      _showAlert('네트워크 오류가 발생했습니다.');
    }
  }

  void _handleChangePassword() async {
    // 현재 비밀번호 확인
    if (_currentPasswordController.text.isEmpty) {
      _showAlert('현재 비밀번호를 입력해주세요.');
      return;
    }

    // 새 비밀번호 검증
    if (_newPasswordController.text.length < 6) {
      _showAlert('새 비밀번호는 최소 6자 이상이어야 합니다.');
      return;
    }

    // 비밀번호 확인 검증
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showAlert('새 비밀번호가 일치하지 않습니다.');
      return;
    }

    try {
      await ApiService.updatePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      _showAlert('비밀번호가 변경되었습니다.');

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] ?? e.message ?? '비밀번호 변경 중 오류가 발생했습니다.';
      _showAlert('비밀번호 변경 실패: $message');
    } catch (e) {
      _showAlert('네트워크 오류가 발생했습니다.');
    }
  }

  Future<void> _handleDeleteAccount() async {
    try {
      await ApiService.deleteAccount(); // DELETE /api/member
      _showAlert('회원 탈퇴가 완료되었습니다.');
      await ApiService.signOut();

      widget.onDeleteAccount();
    } on DioException catch (e) {
      final msg =
          (e.response?.data is Map && e.response?.data['message'] != null)
          ? e.response!.data['message'].toString()
          : '회원 탈퇴에 실패했습니다.';
      _showAlert(msg);
    } catch (_) {
      _showAlert('네트워크 오류가 발생했습니다.');
    }
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('정말 탈퇴하시겠습니까?'),
          content: Text(
            '이 작업은 되돌릴 수 없습니다. 회원님의 모든 데이터가 영구적으로 삭제되며, 분석 기록과 저장된 정보를 복구할 수 없습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleDeleteAccount();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('탈퇴하기'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: widget.onBack,
                      icon: Icon(Icons.arrow_back),
                      label: Text('대시보드로'),
                    ),
                    SizedBox(width: 16),
                    Text(
                      '프로필 설정',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // 기본 정보 카드
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '기본 정보',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          '회원님의 기본 정보를 관리합니다',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 16),

                        // 이메일
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.email, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  '이메일',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: _emailController,
                              enabled: false,
                              decoration: InputDecoration(
                                hintText: 'example@email.com',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        // 사용자명
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  '사용자명',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: _usernameController,
                              enabled: _isEditing,
                              decoration: InputDecoration(
                                hintText: '사용자명',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: _isEditing
                                    ? Colors.white
                                    : Colors.grey[100],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        // 버튼
                        if (!_isEditing)
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = true;
                              });
                            },
                            child: Text('수정하기'),
                          )
                        else
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _handleUpdateProfile,
                                icon: Icon(Icons.save, size: 16),
                                label: Text('저장'),
                              ),
                              SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditing = false;
                                    _emailController.text = widget.userEmail;
                                    _usernameController.text = '사용자';
                                  });
                                },
                                child: Text('취소'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // 비밀번호 변경 카드
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lock, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '비밀번호 변경',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          '보안을 위해 주기적으로 비밀번호를 변경해주세요',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 16),

                        // 현재 비밀번호
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '현재 비밀번호',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: _currentPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                hintText: '현재 비밀번호를 입력하세요',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        // 새 비밀번호
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '새 비밀번호',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: _newPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                hintText: '새 비밀번호 (최소 6자)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        // 비밀번호 확인
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '새 비밀번호 확인',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                hintText: '새 비밀번호를 다시 입력하세요',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        ElevatedButton.icon(
                          onPressed: _handleChangePassword,
                          icon: Icon(Icons.lock, size: 16),
                          label: Text('비밀번호 변경'),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // 회원 탈퇴 카드
                Card(
                  color: Colors.red[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red[200]!),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.delete,
                              size: 20,
                              color: Colors.red[600],
                            ),
                            SizedBox(width: 8),
                            Text(
                              '회원 탈퇴',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[600],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          '회원 탈퇴 시 모든 데이터가 삭제되며 복구할 수 없습니다',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 16),

                        Divider(),

                        SizedBox(height: 16),

                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '탈퇴 전 확인사항',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[800],
                                ),
                              ),
                              SizedBox(height: 8),
                              _buildWarningItem('모든 분석 기록이 영구적으로 삭제됩니다'),
                              _buildWarningItem('저장된 의약품 정보가 모두 삭제됩니다'),
                              _buildWarningItem(
                                '탈퇴 후 동일 이메일로 재가입이 불가능할 수 있습니다',
                              ),
                              _buildWarningItem('탈퇴 처리는 즉시 이루어지며 취소할 수 없습니다'),
                            ],
                          ),
                        ),

                        SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showDeleteConfirmDialog,
                            icon: Icon(Icons.delete, size: 16),
                            label: Text('회원 탈퇴하기'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
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

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.red[700], fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.red[700], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
