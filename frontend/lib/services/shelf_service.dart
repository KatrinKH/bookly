import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'storage_service.dart';
import '../models/shelf.dart';
import '../models/book.dart';

// Сервис управления пользовательскими полками книг:
// создание, переименование, удаление полок, а также добавление/удаление книг на них.
class ShelfService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  // sort: 'newest' | 'oldest' | 'recently_updated'
  Future<List<Shelf>> getShelves({String sort = 'newest'}) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${ApiConfig.baseUrl}/shelves').replace(
      queryParameters: {'sort': sort},
    );

    final response = await http.get(uri, headers: headers);
    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Не удалось загрузить полки (код ${response.statusCode})');
    }

    return (data as List).map((json) => Shelf.fromJson(json)).toList();
  }

  Future<Shelf> createShelf(String name) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/shelves'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(data['error'] ?? 'Не удалось создать полку');
    }

    return Shelf.fromJson(data);
  }

  Future<Shelf> renameShelf({required int shelfId, required String name}) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/shelves/$shelfId'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Не удалось переименовать полку');
    }

    return Shelf.fromJson(data);
  }

  Future<void> deleteShelf(int shelfId) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/shelves/$shelfId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Не удалось удалить полку');
    }
  }

  Future<List<Book>> getShelfBooks(int shelfId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/shelves/$shelfId/books'),
      headers: headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Не удалось загрузить книги полки');
    }

    return (data as List).map((json) => Book.fromJson(json)).toList();
  }

  Future<void> addBookToShelf({required int shelfId, required int bookId}) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/shelves/$shelfId/books'),
      headers: headers,
      body: jsonEncode({'bookId': bookId}),
    );

    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Не удалось добавить книгу на полку');
    }
  }

  Future<void> removeBookFromShelf({required int shelfId, required int bookId}) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/shelves/$shelfId/books/$bookId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Не удалось удалить книгу с полки');
    }
  }
}
