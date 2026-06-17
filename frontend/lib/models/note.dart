// Модель заметки, привязанной к конкретной книге и (опционально) странице
class Note {
  final int id;
  final int bookId;
  final int? pageNumber;
  final String content;
  final String? highlightedText;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.bookId,
    this.pageNumber,
    required this.content,
    this.highlightedText,
    required this.createdAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      bookId: json['bookId'],
      pageNumber: json['pageNumber'],
      content: json['content'],
      highlightedText: json['highlightedText'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
