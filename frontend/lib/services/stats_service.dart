import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'storage_service.dart';
import '../models/stats.dart';

// Сервис получения статистики чтения по периодам (месяц/сезон/год) и сводной статистики
class StatsService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {'Authorization': 'Bearer $token'};
  }

  // period: 'month' | 'season' | 'year'
  Future<List<PeriodStat>> getPeriodStats(String period) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/stats?period=$period'),
      headers: headers,
    );

    final data = jsonDecode(response.body);
    final List byPeriod = data['byPeriod'];
    return byPeriod.map((json) => PeriodStat.fromJson(json)).toList();
  }

  Future<List<GenreStat>> getTopGenres() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/stats?period=month'),
      headers: headers,
    );

    final data = jsonDecode(response.body);
    final List topGenres = data['topGenres'] ?? [];
    return topGenres.map((json) => GenreStat.fromJson(json)).toList();
  }

  Future<OverallStats> getOverallStats() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/stats/overall'),
      headers: headers,
    );

    return OverallStats.fromJson(jsonDecode(response.body));
  }
}
