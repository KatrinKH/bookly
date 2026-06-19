import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/book_service.dart';

// Виджет отображения обложки книги.
// Если у книги есть обложка (hasCover) — загружает её с backend с заголовком
// авторизации. Если нет — показывает иконку-заглушку по формату файла.
class BookCoverImage extends StatelessWidget {
  final Book book;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const BookCoverImage({
    super.key,
    required this.book,
    this.width = 56,
    this.height = 80,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(8);

    if (!book.hasCover) {
      return _buildPlaceholder(context, radius);
    }

    final bookService = BookService();

    return ClipRRect(
      borderRadius: radius,
      child: FutureBuilder<Map<String, String>>(
        future: bookService.getCoverHeaders(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _buildPlaceholder(context, radius, transparent: true);
          }

          return Image.network(
            bookService.getCoverUrl(book.id),
            headers: snapshot.data,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildPlaceholder(context, radius),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _buildPlaceholder(context, radius, transparent: true);
            },
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, BorderRadius radius, {bool transparent = false}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: transparent
            ? Colors.transparent
            : Theme.of(context).colorScheme.secondary.withOpacity(0.3),
        borderRadius: radius,
      ),
      child: transparent
          ? null
          : Icon(
              book.fileFormat == 'pdf' ? Icons.picture_as_pdf : Icons.menu_book,
              color: Theme.of(context).colorScheme.primary,
            ),
    );
  }
}
