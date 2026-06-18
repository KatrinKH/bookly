import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';
import 'utils/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.loadSavedTheme();
  runApp(const BooklyApp());
}

// Корневой виджет приложения Bookly.
// Задаёт глобальную тему (светлую/тёмную, с тёплой палитрой и шрифтом Lobster)
// и стартовый экран (SplashScreen). Подписывается на ThemeController, чтобы
// мгновенно перестраиваться при смене темы пользователем из профиля.
class BooklyApp extends StatelessWidget {
  const BooklyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Bookly',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
