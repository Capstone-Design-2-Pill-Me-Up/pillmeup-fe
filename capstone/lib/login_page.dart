import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://wonsandbox.cloud/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  final _storage = const FlutterSecureStorage();

  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    print('🟢 handleSubmit() 호출됨');
    bool valid = _formKey.currentState!.validate();
    print('✅ 폼 검증 결과: $valid');
    if (!valid) {
      print('❌ 폼 유효성 실패, 요청 중단');
      return;
    }

    print('🛰️ 로그인 시도 시작');

    try {
      // 회원가입 모드일 경우
      if (authMode == AuthMode.signup) {
        print('🧩 회원가입 요청 보냄...');
        final res = await _dio.post('/auth/sign-up', data: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'name': _usernameController.text.trim(),
        });

        print('📩 회원가입 응답: ${res.statusCode} → ${res.data}');

        if (res.statusCode == 200 && res.data['result'] == 'SUCCESS') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('회원가입 성공 ✅ 이제 로그인하세요.')),
          );
          setState(() => authMode = AuthMode.login);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '회원가입 실패: ${res.data['error'] ?? '서버 응답 오류'}',
              ),
            ),
          );
        }
        return;
      }

      // 로그인 모드일 경우
      print('🔐 로그인 요청 보냄...');
      final res = await _dio.post('/auth/sign-in', data: {
        'email': _usernameController.text.trim(),
        'password': _passwordController.text.trim(),
      });

      print('📩 로그인 응답 코드: ${res.statusCode}');
      print('📩 로그인 응답 데이터: ${res.data}');

      // ✅ 로그인 성공일 때만 다음 화면 이동
      if (res.statusCode == 200 && res.data['result'] == 'SUCCESS') {
        final token = res.data['data']?['accessToken'];

        if (token != null && token.isNotEmpty) {
          await _storage.write(key: 'accessToken', value: token);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인 성공 ✅')),
          );
          print('✅ 로그인 성공, 토큰 저장 완료');
          widget.onLogin(_usernameController.text); // ✅ 성공 시에만 호출
        } else {
          print('❌ 로그인 실패 - accessToken 없음');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인 실패: 토큰이 없습니다.')),
          );
        }
      } else {
        print('❌ 로그인 실패 응답: ${res.data}');
        final err = res.data['error'] ?? '잘못된 자격 정보입니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: $err')),
        );
      }
    } on DioException catch (e) {
      // Dio 전용 예외 (서버 응답 or 연결 실패)
      if (e.response != null) {
        print('🚨 Dio 예외 발생: ${e.response?.statusCode}');
        print('🚨 Dio 응답 데이터: ${e.response?.data}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 오류: ${e.response?.statusCode}')),
        );
      } else {
        print('🚨 네트워크 예외: ${e.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 연결 실패: ${e.message}')),
        );
      }
    } catch (e, s) {
      // 기타 예외
      print('🚨 알 수 없는 예외 발생: $e');
      print('Stack: $s');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('예외 발생: $e')),
      );
    }
  }


  void toggleAuthMode() {
    setState(() {
      authMode = authMode == AuthMode.login ? AuthMode.signup : AuthMode.login;
      _usernameController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _emailController.clear();
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
            colors: [
              Color(0xFFF0F4FF),
              Color(0xFFE0E7FF),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 로고
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.medical_services, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 24),
                  Text('Pill Me Up',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      )),
                  const SizedBox(height: 8),
                  Text('Vision AI 기반 의약품 식별 시스템',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                  const SizedBox(height: 40),

                  // 로그인 / 회원가입 폼
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  authMode == AuthMode.login ? Icons.login : Icons.person_add,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  authMode == AuthMode.login ? '로그인' : '회원가입',
                                  style: const TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            if (authMode == AuthMode.signup) ...[
                              const Text('이메일'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(hintText: '이메일 입력'),
                                validator: (value) =>
                                (value == null || value.isEmpty) ? '이메일을 입력하세요' : null,
                              ),
                              const SizedBox(height: 16),
                            ],

                            Text('이메일(로그인 시 사용자명 대신 이메일 사용)'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(hintText: '이메일을 입력하세요'),
                              validator: (v) =>
                              (v == null || v.isEmpty) ? '이메일을 입력해주세요' : null,
                            ),
                            const SizedBox(height: 16),

                            const Text('비밀번호'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(hintText: '비밀번호를 입력하세요'),
                              obscureText: true,
                              validator: (v) =>
                              (v == null || v.isEmpty) ? '비밀번호를 입력해주세요' : null,
                            ),
                            const SizedBox(height: 16),

                            if (authMode == AuthMode.signup) ...[
                              const Text('비밀번호 확인'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _confirmPasswordController,
                                decoration:
                                const InputDecoration(hintText: '비밀번호를 다시 입력하세요'),
                                obscureText: true,
                                validator: (v) =>
                                (v == null || v.isEmpty) ? '비밀번호 확인을 입력해주세요' : null,
                              ),
                              const SizedBox(height: 24),
                            ] else
                              const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: handleSubmit,
                                child: Text(authMode == AuthMode.login ? '로그인' : '회원가입'),
                              ),
                            ),
                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: toggleAuthMode,
                                child: Text(authMode == AuthMode.login
                                    ? '계정이 없으신가요? 회원가입'
                                    : '이미 계정이 있으신가요? 로그인'),
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
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
