import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book.dart';
import 'book_cover_image.dart';

// Карточка книги для сеточного режима отображения (2 книги в ряд).
// В отличие от BookCard (горизонтальная, для списка), здесь обложка
// крупная и расположена сверху, а текст — компактно под ней.
class BookGridCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const BookGridCard({super.key, required this.book, required this.onTap});

  Color _statusColor() {
    switch (book.status) {
      case 'finished':
        return Colors.green;
      case 'reading':
        return Colors.orange;
      case 'abandoned':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _statusLabel() {
    switch (book.status) {
      case 'finished':
        return 'Прочитано';
      case 'reading':
        return 'Читаю';
      case 'abandoned':
        return 'Отложено';
      default:
        return 'Не начато';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: BookCoverImage(
                book: book,
                width: double.infinity,
                height: double.infinity,
                borderRadius: BorderRadius.zero,
              ),
            ),
            // Фиксированная высота текстового блока — одинаковая у всех карточек
            // независимо от длины названия/автора. Если текст не помещается,
            // он обрезается через maxLines + ellipsis, а не растягивает карточку.
            // Все элементы идут плотно сверху, без растяжки между ними.
            SizedBox(
              height: 98,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: GoogleFonts.lobster(fontWeight: FontWeight.bold, fontSize: 13, height: 1.15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      book.author ?? '',
                      style: GoogleFonts.lobster(color: Colors.grey.shade600, fontSize: 12, height: 1.1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor().withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _statusLabel(),
                            style: GoogleFonts.lobster(
                              color: _statusColor(),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              height: 1.0,
                            ),
                          ),
                        ),
                        if (book.rating != null) ...[
                          const SizedBox(width: 5),
                          Icon(Icons.star, size: 12, color: Colors.amber.shade700),
                          Text(
                            '${book.rating}',
                            style: GoogleFonts.lobster(fontSize: 11, height: 1.0),
                          ),
                        ],
                      ],
                    ),
                    if (book.isReading && book.totalPages != null) ...[
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: book.progressPercent,
                        backgroundColor: Colors.grey.shade200,
                        minHeight: 3,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
