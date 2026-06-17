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
    final data = jsonDecode(response.body) as List;

    return data.map((json) => Book.fromJson(json)).toList();
  }

  Future<Book> getBookById(int id) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/books/$id'),
      headers: headers,
    );
    return Book.fromJson(jsonDecode(response.body));
  }

  // URL для открытия файла книги в просмотрщике (PDF/EPUB)
  Future<String> getBookFileUrl(int bookId) async {
    final token = await _storage.getToken();
    return '${ApiConfig.baseUrl}/books/$bookId/file?token=$token';
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

    return Book.fromJson(jsonDecode(response.body));
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

    return Book.fromJson(jsonDecode(response.body));
  }

  Future<void> deleteBook(int bookId) async {
    final headers = await _authHeaders();
    await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/books/$bookId'),
      headers: headers,
    );
  }
}
