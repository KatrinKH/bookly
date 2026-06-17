import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const BooklyApp());
}

// Корневой виджет приложения Bookly.
// Задаёт глобальную тему и стартовый экран (SplashScreen).
class BooklyApp extends StatelessWidget {
  const BooklyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bookly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        appBarTheme: const AppBarTheme(centerTitle: false),
        navigationBarTheme: const NavigationBarThemeData(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
