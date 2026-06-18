import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'storage_service.dart';
import '../models/book.dart';

// Сервис отвечает за все операции с книгами: загрузка, получение списка,
// обновление прогресса чтения, завершение книги, удаление.
class BookService {
  final StorageService _storage = StorageService();
  final Dio _dio = Dio();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();

    if (token == null) {
      throw Exception('Не выполнен вход: токен авторизации отсутствует');
    }

    return {'Authorization': 'Bearer $token'};
  }

  // Загрузка новой книги (файл PDF/EPUB + опционально обложка)
  Future<Book> uploadBook({
    required String title,
    String? author,
    String? genre,
    required String filePath,
    String? coverPath,
  }) async {
    final token = await _storage.getToken();

    final formData = FormData.fromMap({
      'title': title,
      if (author != null) 'author': author,
      if (genre != null) 'genre': genre,
      'book': await MultipartFile.fromFile(filePath),
      if (coverPath != null) 'cover': await MultipartFile.fromFile(coverPath),
    });

    final response = await _dio.post(
      '${ApiConfig.baseUrl}/books',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    return Book.fromJson(response.data);
  }

  // Получение списка книг, опционально с фильтром по статусу
  Future<List<Book>> getBooks({String? status}) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${ApiConfig.baseUrl}/books').replace(
      queryParameters: status != null ? {'status': status} : null,
    );

    final response = await http.get(uri, headers: headers);
    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Не удалось загрузить книги (код ${response.statusCode})');
    }

    return (data as List).map((json) => Book.fromJson(json)).toList();
  }

  Future<Book> getBookById(int id) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/books/$id'),
      headers: headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Не удалось загрузить книгу (код ${response.statusCode})');
    }

    return Book.fromJson(data);
  }

  // URL для открытия файла книги в просмотрщике (PDF/EPUB)
  Future<String> getBookFileUrl(int bookId) async {
    final token = await _storage.getToken();
    return '${ApiConfig.baseUrl}/books/$bookId/file?token=$token';
  }

  // Открывает сессию чтения при входе в читалку.
  // Возвращает sessionId, который нужно передать в endReadingSession при выходе.
  Future<int> startReadingSession(int bookId) async {
    final headers = await _authHeaders();
    headers['Content-Type'] = 'application/json';

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/books/$bookId/session/start'),
      headers: headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['error'] ?? 'Не удалось открыть сессию чтения');
    }

    return data['sessionId'];
  }

  // Закрывает сессию чтения при выходе из читалки.
  // После закрытия разница ended_at - started_at идёт в статистику часов чтения.
  Future<void> endReadingSession(int bookId, int sessionId) async {
    final headers = await _authHeaders();
    headers['Content-Type'] = 'application/json';

    await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/books/$bookId/session/end'),
      headers: headers,
      body: jsonEncode({'sessionId': sessionId}),
    );
  }

  // Обновление текущей страницы при чтении.
  // Backend автоматически фиксирует дату начала чтения при первом вызове.
  Future<Book> updateProgress({
    required int bookId,
    required int currentPage,
    int? totalPages,
  }) async {
    final headers = await _authHeaders();
    headers['Content-Type'] = 'application/json';

    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/books/$bookId/progress'),
      headers: headers,
      body: jsonEncode({
        'currentPage': currentPage,
        if (totalPages != null) 'totalPages': totalPages,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Не удалось обновить прогресс (код ${response.statusCode})');
    }

    return Book.fromJson(data);
  }

  // Отметить книгу прочитанной, поставить оценку и лайк
  Future<Book> finishBook({
    required int bookId,
    int? rating,
    bool? liked,
  }) async {
    final headers = await _authHeaders();
    headers['Content-Type'] = 'application/json';

    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/books/$bookId/finish'),
      headers: headers,
      body: jsonEncode({
        if (rating != null) 'rating': rating,
        if (liked != null) 'liked': liked,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Не удалось завершить книгу (код ${response.statusCode})');
    }

    return Book.fromJson(data);
  }

  Future<void> deleteBook(int bookId) async {
    final headers = await _authHeaders();
    await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/books/$bookId'),
      headers: headers,
    );
  }
}
