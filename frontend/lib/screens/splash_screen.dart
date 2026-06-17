import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'library_screen.dart';

// Экран-заглушка при запуске приложения: проверяет, есть ли сохранённый
// токен авторизации, и направляет пользователя либо в библиотеку,
// либо на экран входа.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final isLoggedIn = await _authService.isLoggedIn();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isLoggedIn ? const LibraryScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Icon(Icons.menu_book_rounded, size: 80, color: Colors.indigo),
      ),
    );
  }
}
