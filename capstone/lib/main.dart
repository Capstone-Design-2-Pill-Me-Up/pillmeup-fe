import 'package:capstone/services/api_service.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'main_dashboard.dart';

void main() {
  ApiService.init();
  runApp(PillMeUpApp());
}

class PillMeUpApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pill Me Up',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF030213),
        scaffoldBackgroundColor: Colors.white,
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF030213),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3F3F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      home: AppRoot(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppRoot extends StatefulWidget {
  @override
  _AppRootState createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  String? userEmail;
  String? username;

  void handleLogin(String email) async {
    setState(() {
      userEmail = email;
      username = '사용자';
    });

    try {
      final res = await ApiService.getProfile();
      final data = res.data;

      // 서버 응답 형태에 따라 수정 필요 (Swagger 참고)
      final realName = data['name'] ?? data['data']?['name'] ?? '사용자';
      final realEmail = data['email'] ?? data['data']?['email'] ?? email;

      setState(() {
        username = realName;
        userEmail = realEmail;
      });

      print('✅ 프로필 정보 로드됨: $realName ($realEmail)');
    } catch (e) {
      print('⚠️ 프로필 불러오기 실패: $e');
    }
  }

  void handleLogout() {
    setState(() {
      userEmail = null;
      username = null;
    });
  }

  void handleProfileUpdate(String email, String newUsername) {
    setState(() {
      userEmail = email;
      username = newUsername;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (userEmail == null) {
      return LoginPage(onLogin: handleLogin);
    }

    return MainDashboard(
      userEmail: userEmail!,
      username: username ?? '사용자',
      onLogout: handleLogout,
      onProfileUpdated: handleProfileUpdate, // (email, username)
    );
  }
}
