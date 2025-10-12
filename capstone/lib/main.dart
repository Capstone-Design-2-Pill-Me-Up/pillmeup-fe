import 'package:flutter/material.dart';
import 'login_page.dart';
import 'main_dashboard.dart';

void main() {
  runApp(PillMeUpApp());
}

class PillMeUpApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pill Me Up',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Color(0xFF030213),
        scaffoldBackgroundColor: Colors.white,
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF030213),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF3F3F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
  String? user;

  void handleLogin(String username) {
    setState(() {
      user = username;
    });
  }

  void handleLogout() {
    setState(() {
      user = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return LoginPage(onLogin: handleLogin);
    }

    return MainDashboard(username: user!, onLogout: handleLogout);
  }
}