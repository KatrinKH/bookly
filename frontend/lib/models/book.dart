// Модель книги в библиотеке пользователя.
// Соответствует объекту, который возвращает backend (см. booksController.js -> formatBook).
class Book {
  final int id;
  final String title;
  final String? author;
  final String? description; // описание книги, указанное при добавлении
  final String fileFormat; // 'pdf' или 'epub'
  final String? genre;
  final int? totalPages;
  final int currentPage;
  final String status; // not_started | reading | finished | abandoned
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int? rating; // 1..5
  final bool? liked;
  final String? review; // текстовый отзыв пользователя после прочтения
  final bool hasCover; // есть ли загруженная/извлечённая обложка
  final DateTime createdAt;

  Book({
    required this.id,
    required this.title,
    this.author,
    this.description,
    required this.fileFormat,
    this.genre,
    this.totalPages,
    required this.currentPage,
    required this.status,
    this.startedAt,
    this.finishedAt,
    this.rating,
    this.liked,
    this.review,
    this.hasCover = false,
    required this.createdAt,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      description: json['description'],
      fileFormat: json['fileFormat'],
      genre: json['genre'],
      totalPages: json['totalPages'],
      currentPage: json['currentPage'] ?? 0,
      status: json['status'],
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
      finishedAt: json['finishedAt'] != null ? DateTime.parse(json['finishedAt']) : null,
      rating: json['rating'],
      liked: json['liked'],
      review: json['review'],
      hasCover: json['hasCover'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  double get progressPercent {
    if (totalPages == null || totalPages == 0) return 0;
    return (currentPage / totalPages!).clamp(0, 1).toDouble();
  }

  bool get isFinished => status == 'finished';
  bool get isReading => status == 'reading';
}
