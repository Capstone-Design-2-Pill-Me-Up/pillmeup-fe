import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/api_service.dart';

enum AuthMode { login, signup }

class LoginPage extends StatefulWidget {
  final Function(String) onLogin;

  const LoginPage({Key? key, required this.onLogin}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  AuthMode authMode = AuthMode.login;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://wonsandbox.cloud/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  final _storage = const FlutterSecureStorage();

  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (authMode == AuthMode.signup) {
        final res = await _dio.post(
          '/auth/sign-up',
          data: {
            'email': _emailController.text.trim(),
            'password': _passwordController.text.trim(),
            'name': _usernameController.text.trim(),
          },
        );

        if (res.statusCode == 200 && res.data['result'] == 'SUCCESS') {
          // ✅ 회원가입 응답에서 memberId 꺼내서 저장
          final memberId = res.data['data']?['memberId'];
          if (memberId != null) {
            await _storage.write(key: 'memberId', value: memberId.toString());
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('회원가입 성공 ✅ 이제 로그인하세요.')));
          setState(() => authMode = AuthMode.login);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('회원가입 실패: ${res.data['error'] ?? '서버 오류'}')),
          );
        }
        return;
      }

      final res = await _dio.post(
        '/auth/sign-in',
        data: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        },
      );

      if (res.statusCode == 200 && res.data['result'] == 'SUCCESS') {
        final token = res.data['data']?['accessToken'];
        if (token != null && token.isNotEmpty) {
          // ✅ 토큰 저장
          await _storage.write(key: 'accessToken', value: token);

          // ✅ 프로필 API를 통해 memberId 가져와서 저장
          try {
            final profileRes = await ApiService.getProfile();
            final profileData = profileRes.data['data'];
            final memberId =
                profileData['memberId']; // 실제 키 이름은 프로필 응답 보고 맞춰야 함!

            if (memberId != null) {
              await _storage.write(key: 'memberId', value: memberId.toString());
            }
          } catch (e) {
            // memberId 못 가져와도 일단 로그인은 계속 진행
            debugPrint('memberId 불러오기 실패: $e');
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('로그인 성공 ✅')));
          widget.onLogin(_emailController.text);
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인 실패: 잘못된 정보입니다.')));
      }
    } on DioException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('서버 오류: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('예외 발생: $e')));
    }
  }

  void toggleAuthMode() {
    setState(() {
      authMode = authMode == AuthMode.login ? AuthMode.signup : AuthMode.login;
      _emailController.clear();
      _usernameController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 로고
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.medical_services,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Pill Me Up',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vision AI 기반 의약품 식별 시스템',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 40),

                  // 로그인 카드
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  authMode == AuthMode.login
                                      ? Icons.login
                                      : Icons.person_add,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  authMode == AuthMode.login ? '로그인' : '회원가입',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // 이메일
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                hintText: '이메일 주소를 입력하세요',
                              ),
                              validator: (v) =>
                                  v == null || v.isEmpty ? '이메일을 입력해주세요' : null,
                            ),
                            const SizedBox(height: 16),

                            // 사용자명 (회원가입 시)
                            if (authMode == AuthMode.signup)
                              TextFormField(
                                controller: _usernameController,
                                decoration: const InputDecoration(
                                  hintText: '사용자명을 입력하세요',
                                ),
                              ),
                            if (authMode == AuthMode.signup)
                              const SizedBox(height: 16),

                            // 비밀번호
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: '비밀번호를 입력하세요',
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 비밀번호 확인 (회원가입 시)
                            if (authMode == AuthMode.signup)
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  hintText: '비밀번호를 다시 입력하세요',
                                ),
                              ),

                            const SizedBox(height: 24),

                            // 로그인 버튼
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: handleSubmit,
                                icon: Icon(
                                  authMode == AuthMode.login
                                      ? Icons.login
                                      : Icons.person_add,
                                  size: 18,
                                ),
                                label: Text(
                                  authMode == AuthMode.login ? '로그인' : '회원가입',
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 소셜 로그인 (로그인 모드일 때만)
                            if (authMode == AuthMode.login) ...[
                              Row(
                                children: [
                                  Expanded(child: Divider()),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text('간편 로그인'),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 카카오 로그인
                              ElevatedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('카카오 로그인 준비 중입니다.'),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFEE500),
                                  foregroundColor: Colors.black,
                                  minimumSize: const Size.fromHeight(50),
                                ),
                                child: const Text('카카오 로그인'),
                              ),
                              const SizedBox(height: 8),

                              // 네이버 로그인
                              ElevatedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('네이버 로그인 준비 중입니다.'),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF03C75A),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(50),
                                ),
                                child: const Text('네이버 로그인'),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // 모드 전환
                            TextButton.icon(
                              onPressed: toggleAuthMode,
                              icon: Icon(
                                authMode == AuthMode.login
                                    ? Icons.person_add
                                    : Icons.login,
                                size: 18,
                              ),
                              label: Text(
                                authMode == AuthMode.login
                                    ? '계정이 없으신가요? 회원가입'
                                    : '이미 계정이 있으신가요? 로그인',
                              ),
                            ),

                            // 개인정보 안내 (회원가입 시)
                            if (authMode == AuthMode.signup)
                              Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F4FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '회원가입 시 개인정보 처리방침 및 서비스 약관에 동의하게 됩니다.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1E40AF),
                                  ),
                                  textAlign: TextAlign.center,
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
