import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Глобальный контроллер темы приложения.
// Хранит текущий выбор пользователя (светлая/тёмная) и сохраняет его
// на устройстве, чтобы при следующем запуске приложение его помнило.
// ThemeMode.system технически поддерживается MaterialApp, но в интерфейсе
// настроек пользователю предлагается выбор только между light и dark.
class ThemeController {
  static const _prefsKey = 'theme_mode';

  // ValueNotifier, на который подписан MaterialApp — изменение этого значения
  // мгновенно перестраивает всё приложение в нужном режиме.
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  static Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);

    themeMode.value = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
