import 'package:shared_preferences/shared_preferences.dart';

// Сервис для сохранения и получения JWT-токена и данных пользователя на устройстве.
// Используется, чтобы пользователь не вводил пароль при каждом запуске приложения.
class StorageService {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _userEmailKey = 'user_email';
  static const _userNameKey = 'user_name';

  Future<void> saveSession({
    required String token,
    required int userId,
    required String email,
    required String displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setInt(_userIdKey, userId);
    await prefs.setString(_userEmailKey, email);
    await prefs.setString(_userNameKey, displayName);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) return null;

    return {
      'id': prefs.getInt(_userIdKey),
      'email': prefs.getString(_userEmailKey),
      'displayName': prefs.getString(_userNameKey),
    };
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
