import 'package:flutter/material.dart';
import '../models/book.dart';
import 'book_cover_image.dart';

// Карточка книги в списке библиотеки.
// Показывает обложку-заглушку, название, автора, статус и прогресс чтения.
class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const BookCard({super.key, required this.book, required this.onTap});

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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              BookCoverImage(book: book, width: 56, height: 80),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (book.author != null)
                      Text(
                        book.author!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor().withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _statusLabel(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: _statusColor(),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (book.rating != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                          Text(
                            ' ${book.rating}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                    if (book.isReading && book.totalPages != null) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: book.progressPercent,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
