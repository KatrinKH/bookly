import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'storage_service.dart';
import '../models/note.dart';

// Сервис для создания, получения, обновления и удаления заметок к книгам
class NoteService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  Future<Note> createNote({
    required int bookId,
    int? pageNumber,
    required String content,
    String? highlightedText,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/notes'),
      headers: headers,
      body: jsonEncode({
        'bookId': bookId,
        if (pageNumber != null) 'pageNumber': pageNumber,
        'content': content,
        if (highlightedText != null) 'highlightedText': highlightedText,
      }),
    );

    return Note.fromJson(jsonDecode(response.body));
  }

  Future<List<Note>> getNotesByBook(int bookId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/notes/book/$bookId'),
      headers: headers,
    );

    final data = jsonDecode(response.body) as List;
    return data.map((json) => Note.fromJson(json)).toList();
  }

  Future<Note> updateNote({required int noteId, required String content}) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/notes/$noteId'),
      headers: headers,
      body: jsonEncode({'content': content}),
    );

    return Note.fromJson(jsonDecode(response.body));
  }

  Future<void> deleteNote(int noteId) async {
    final headers = await _authHeaders();
    await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/notes/$noteId'),
      headers: headers,
    );
  }
}
