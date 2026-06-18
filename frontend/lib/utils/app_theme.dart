import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Цветовая палитра приложения Bookly, основанная на тёплых уютных тонах
// "Dietitan Color Palette": savory sage, avocado smoothie, blush beet,
// peach protein, oat latte, honey oatmilk, coconut cream.
class AppColors {
  // Светлая тема — исходная палитра
  static const savorySage = Color(0xFF818263);
  static const avocadoSmoothie = Color(0xFFC2C395);
  static const blushBeet = Color(0xFFDDBAAE);
  static const peachProtein = Color(0xFFEFD7CF);
  static const oatLatte = Color(0xFFDCD4C1);
  static const honeyOatmilk = Color(0xFFF6EAD4);
  static const coconutCream = Color(0xFFFFFAF2);

  // Тёмная тема — приглушённые тёмно-оливковые тона в той же гамме
  static const darkBackground = Color(0xFF2C2E22); // глубокий тёмно-оливковый фон
  static const darkSurface = Color(0xFF3A3D2E); // поверхности карточек
  static const darkSage = Color(0xFFA3A584); // акцент, светлее чем savorySage для контраста
  static const darkBeet = Color(0xFFC79C8E); // приглушённый blushBeet
  static const darkTextPrimary = Color(0xFFF1ECDD); // основной текст на тёмном фоне
}

// Центральный класс темы приложения. Используется в main.dart для задания
// светлой и тёмной темы с учётом единого шрифта Lobster.
class AppTheme {
  // Lobster используется как основной шрифт во всём приложении —
  // для текста, заголовков, карточек списков и т.д.
  static TextStyle _lobster({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    return GoogleFonts.lobster(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  // Pacifico используется только для названия бренда "Bookly" —
  // временная бесплатная замена платного шрифта Good Vibes Pro.
  static TextStyle brandFont({required double fontSize, Color? color}) {
    return GoogleFonts.pacifico(fontSize: fontSize, color: color);
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.coconutCream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.savorySage,
        brightness: Brightness.light,
        primary: AppColors.savorySage,
        secondary: AppColors.avocadoSmoothie,
        surface: AppColors.honeyOatmilk,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.coconutCream,
        foregroundColor: AppColors.savorySage,
        centerTitle: true, // заголовки страниц строго по центру
        elevation: 0,
        titleTextStyle: _lobster(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.savorySage,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.honeyOatmilk,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.all(_lobster(fontSize: 12)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.honeyOatmilk,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: _buildTextTheme(Brightness.light),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.savorySage,
          textStyle: _lobster(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.darkSage,
        brightness: Brightness.dark,
        primary: AppColors.darkSage,
        secondary: AppColors.darkBeet,
        surface: AppColors.darkSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkSage,
        centerTitle: true, // заголовки страниц строго по центру
        elevation: 0,
        titleTextStyle: _lobster(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.darkSage,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.all(
          _lobster(fontSize: 12, color: AppColors.darkTextPrimary),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: _buildTextTheme(Brightness.dark),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.darkSage,
          foregroundColor: AppColors.darkBackground,
          textStyle: _lobster(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Общая текстовая тема Lobster для обоих режимов, с поправкой на цвет текста
  static TextTheme _buildTextTheme(Brightness brightness) {
    final textColor = brightness == Brightness.light
        ? const Color(0xFF3A3D2E)
        : AppColors.darkTextPrimary;

    return GoogleFonts.lobsterTextTheme().apply(
      bodyColor: textColor,
      displayColor: textColor,
    );
  }
}
