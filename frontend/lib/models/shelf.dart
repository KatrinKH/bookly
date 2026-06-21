// Модель пользовательской полки книг (коллекции типа "Хочу прочитать", "Любимое")
class Shelf {
  final int id;
  final String name;
  final int? bookCount;
  final DateTime createdAt;

  Shelf({
    required this.id,
    required this.name,
    this.bookCount,
    required this.createdAt,
  });

  factory Shelf.fromJson(Map<String, dynamic> json) {
    return Shelf(
      id: json['id'],
      name: json['name'],
      bookCount: json['bookCount'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
