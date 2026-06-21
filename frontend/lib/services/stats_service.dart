import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'storage_service.dart';
import '../models/stats.dart';

// Сервис получения статистики чтения по периодам (месяц/сезон/год) и сводной статистики.
// Для месяца/сезона/года можно запросить конкретный период через year/month/season,
// иначе backend вернёт статистику за текущий период.
class StatsService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {'Authorization': 'Bearer $token'};
  }

  // period: 'month' | 'season' | 'year'
  // year/month/season — опциональные параметры для просмотра конкретного периода.
  // season принимает значения: winter | spring | summer | autumn
  Future<StatsResponse> getStats({
    required String period,
    int? year,
    int? month,
    String? season,
  }) async {
    final headers = await _authHeaders();

    final queryParams = {
      'period': period,
      if (year != null) 'year': year.toString(),
      if (month != null) 'month': month.toString(),
      if (season != null) 'season': season,
    };

    final uri = Uri.parse('${ApiConfig.baseUrl}/stats').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Не удалось загрузить статистику (код ${response.statusCode})');
    }

    return StatsResponse.fromJson(data);
  }

  Future<OverallStats> getOverallStats() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/stats/overall'),
      headers: headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Не удалось загрузить сводную статистику (код ${response.statusCode})');
    }

    return OverallStats.fromJson(data);
  }
}
