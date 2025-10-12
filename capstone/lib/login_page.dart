import 'package:flutter/material.dart';

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

  void handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    if (authMode == AuthMode.signup) {
      // 회원가입 유효성 검사
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
        );
        return;
      }
      if (_passwordController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('비밀번호는 최소 6자리 이상이어야 합니다.')),
        );
        return;
      }
      if (!_emailController.text.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('유효한 이메일 주소를 입력해주세요.')),
        );
        return;
      }
    }

    if (_usernameController.text.trim().isNotEmpty) {
      widget.onLogin(_usernameController.text);
    }
  }

  void toggleAuthMode() {
    setState(() {
      authMode = authMode == AuthMode.login ? AuthMode.signup : AuthMode.login;
      // 폼 초기화
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
        decoration: BoxDecoration(
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
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 앱 로고 및 제목
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.medical_services,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Pill Me Up',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Vision AI 기반 의약품 식별 시스템',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 40),

                  // 로그인/회원가입 카드
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 제목
                            Row(
                              children: [
                                Icon(
                                  authMode == AuthMode.login 
                                    ? Icons.login 
                                    : Icons.person_add,
                                  color: Theme.of(context).primaryColor,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  authMode == AuthMode.login ? '로그인' : '회원가입',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              authMode == AuthMode.login
                                  ? '안전한 의약품 복용을 위해 로그인해주세요'
                                  : '새 계정을 만들어 Pill Me Up을 시작하세요',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 24),

                            // 이메일 필드 (회원가입 시에만)
                            if (authMode == AuthMode.signup) ...[
                              Text('이메일', style: TextStyle(fontWeight: FontWeight.w500)),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  hintText: '이메일 주소를 입력하세요',
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '이메일을 입력해주세요';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),
                            ],

                            // 사용자명 필드
                            Text('사용자명', style: TextStyle(fontWeight: FontWeight.w500)),
                            SizedBox(height: 8),
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                hintText: '사용자명을 입력하세요',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '사용자명을 입력해주세요';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),

                            // 비밀번호 필드
                            Text('비밀번호', style: TextStyle(fontWeight: FontWeight.w500)),
                            SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                hintText: authMode == AuthMode.signup 
                                  ? '비밀번호 (최소 6자)' 
                                  : '비밀번호를 입력하세요',
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '비밀번호를 입력해주세요';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),

                            // 비밀번호 확인 필드 (회원가입 시에만)
                            if (authMode == AuthMode.signup) ...[
                              Text('비밀번호 확인', style: TextStyle(fontWeight: FontWeight.w500)),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: _confirmPasswordController,
                                decoration: InputDecoration(
                                  hintText: '비밀번호를 다시 입력하세요',
                                ),
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '비밀번호 확인을 입력해주세요';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 24),
                            ] else
                              SizedBox(height: 24),

                            // 로그인/회원가입 버튼
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: handleSubmit,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      authMode == AuthMode.login 
                                        ? Icons.login 
                                        : Icons.person_add,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(authMode == AuthMode.login ? '로그인' : '회원가입'),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: 24),

                            // 구분선
                            Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    '또는',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),

                            SizedBox(height: 16),

                            // 모드 전환 버튼
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: toggleAuthMode,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      authMode == AuthMode.login 
                                        ? Icons.person_add 
                                        : Icons.login,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      authMode == AuthMode.login
                                          ? '계정이 없으신가요? 회원가입'
                                          : '이미 계정이 있으신가요? 로그인',
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

                  // 개인정보 처리방침 안내 (회원가입 시에만)
                  if (authMode == AuthMode.signup)
                    Container(
                      margin: EdgeInsets.only(top: 24),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Color(0xFFBFDBFE)),
                      ),
                      child: Text(
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