import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'storage_service.dart';
import '../models/user.dart';

// Сервис отвечает за регистрацию, вход и хранение сессии пользователя
class AuthService {
  final StorageService _storage = StorageService();

  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'displayName': displayName,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(data['error'] ?? 'Ошибка регистрации');
    }

    await _storage.saveSession(
      token: data['token'],
      userId: data['user']['id'],
      email: data['user']['email'],
      displayName: data['user']['displayName'],
    );

    return AppUser.fromJson(data['user']);
  }

  Future<AppUser> login({required String email, required String password}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Ошибка входа');
    }

    await _storage.saveSession(
      token: data['token'],
      userId: data['user']['id'],
      email: data['user']['email'],
      displayName: data['user']['displayName'],
    );

    return AppUser.fromJson(data['user']);
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.getToken();
    return token != null;
  }

  Future<AppUser?> getStoredUser() async {
    final userData = await _storage.getUserData();
    if (userData == null || userData['id'] == null) return null;
    return AppUser.fromJson(userData);
  }

  Future<void> logout() async {
    await _storage.clearSession();
  }
}
