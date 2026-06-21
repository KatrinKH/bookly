import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/book.dart';
import '../models/note.dart';
import '../models/shelf.dart';
import '../services/book_service.dart';
import '../services/note_service.dart';
import '../services/shelf_service.dart';
import '../widgets/book_cover_image.dart';
import 'reader_screen.dart';

// Экран с подробной информацией о книге: статус, прогресс, заметки и оценка.
// Отсюда пользователь переходит непосредственно к чтению.
class BookDetailScreen extends StatefulWidget {
  final int bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final BookService _bookService = BookService();
  final NoteService _noteService = NoteService();
  final ShelfService _shelfService = ShelfService();

  Book? _book;
  List<Note> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final book = await _bookService.getBookById(widget.bookId);
      final notes = await _noteService.getNotesByBook(widget.bookId);
      setState(() {
        _book = book;
        _notes = notes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки книги: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openReader() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(book: _book!)),
    );
    _loadData(); // Обновляем прогресс после возврата из читалки
  }

  // Диалог оценки книги: звёзды, лайк/дизлайк и текстовый отзыв.
  // Если книга ещё не была завершена — вызывается finishBook (фиксирует дату завершения).
  // Если книга уже прочитана (редактирование отзыва) — вызывается updateReview,
  // которая не трогает дату завершения.
  Future<void> _showReviewDialog() async {
    int rating = _book!.rating ?? 3;
    bool liked = _book!.liked ?? true;
    final reviewController = TextEditingController(text: _book!.review ?? '');
    final isFirstTime = !_book!.isFinished;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isFirstTime ? 'Завершить книгу' : 'Редактировать отзыв'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Оценка:'),
                    Row(
                      children: List.generate(5, (i) {
                        final starIndex = i + 1;
                        return IconButton(
                          icon: Icon(
                            starIndex <= rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                          onPressed: () => setDialogState(() => rating = starIndex),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    const Text('Понравилась книга?'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: liked ? Colors.green.withOpacity(0.15) : null,
                              side: BorderSide(color: liked ? Colors.green : Colors.grey.shade400),
                            ),
                            onPressed: () => setDialogState(() => liked = true),
                            child: Text(
                              'Да',
                              style: TextStyle(
                                color: liked ? Colors.green.shade700 : null,
                                fontWeight: liked ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: !liked ? Colors.red.withOpacity(0.15) : null,
                              side: BorderSide(color: !liked ? Colors.red : Colors.grey.shade400),
                            ),
                            onPressed: () => setDialogState(() => liked = false),
                            child: Text(
                              'Нет',
                              style: TextStyle(
                                color: !liked ? Colors.red.shade700 : null,
                                fontWeight: !liked ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Ваше мнение о книге:'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reviewController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Что понравилось, что не понравилось, кому бы вы посоветовали...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (isFirstTime) {
                      await _bookService.finishBook(
                        bookId: widget.bookId,
                        rating: rating,
                        liked: liked,
                        review: reviewController.text.trim(),
                      );
                    } else {
                      await _bookService.updateReview(
                        bookId: widget.bookId,
                        rating: rating,
                        liked: liked,
                        review: reviewController.text.trim(),
                      );
                    }
                    if (context.mounted) Navigator.of(context).pop();
                    _loadData();
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addNoteDialog() async {
    final controller = TextEditingController();
    final pageController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая заметка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Страница (опционально)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Ваши мысли',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await _noteService.createNote(
                bookId: widget.bookId,
                pageNumber: int.tryParse(pageController.text),
                content: controller.text.trim(),
              );
              if (context.mounted) Navigator.of(context).pop();
              _loadData();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final book = _book!;

    return Scaffold(
      appBar: AppBar(
        title: Text(book.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showEditDialog();
              } else if (value == 'delete') {
                _showDeleteConfirmation();
              } else if (value == 'shelves') {
                _showAddToShelfDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'shelves',
                child: ListTile(
                  leading: Icon(Icons.bookmark_add_outlined),
                  title: Text('Добавить на полку'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Редактировать'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('Удалить книгу', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNoteDialog,
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Заметка'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                BookCoverImage(
                  book: book,
                  width: 140,
                  height: 200,
                  borderRadius: BorderRadius.circular(12),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Material(
                    color: Theme.of(context).colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _changeCover,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.edit, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (book.author != null)
            Text(book.author!, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (book.genre != null) Chip(label: Text(book.genre!)),
              Chip(label: Text(book.fileFormat.toUpperCase())),
            ],
          ),
          const SizedBox(height: 16),
          if (book.startedAt != null)
            _InfoRow(label: 'Начато', value: _formatDate(book.startedAt!)),
          if (book.finishedAt != null)
            _InfoRow(label: 'Завершено', value: _formatDate(book.finishedAt!)),
          if (book.totalPages != null)
            _InfoRow(label: 'Прогресс', value: '${book.currentPage} / ${book.totalPages} стр.'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openReader,
                  icon: const Icon(Icons.menu_book),
                  label: Text(book.status == 'not_started' ? 'Начать чтение' : 'Продолжить'),
                ),
              ),
              if (!book.isFinished) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _showReviewDialog,
                  child: const Text('Завершить'),
                ),
              ],
            ],
          ),
          if (book.isFinished) _buildReviewSection(book),
          if (book.description != null && book.description!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Описание', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(book.description!, style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
          const SizedBox(height: 24),
          Text('Заметки (${_notes.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (_notes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Пока нет заметок', style: TextStyle(color: Colors.grey.shade500)),
            )
          else
            ..._notes.map((note) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(note.content),
                    subtitle: note.pageNumber != null
                        ? Text('Страница ${note.pageNumber}')
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () async {
                        await _noteService.deleteNote(note.id);
                        _loadData();
                      },
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  // Диалог редактирования названия, автора и жанра книги
  Future<void> _showEditDialog() async {
    final titleController = TextEditingController(text: _book!.title);
    final authorController = TextEditingController(text: _book!.author ?? '');
    final genreController = TextEditingController(text: _book!.genre ?? '');
    final descriptionController = TextEditingController(text: _book!.description ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать книгу'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Название *'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Введите название' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: authorController,
                  decoration: const InputDecoration(labelText: 'Автор'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: genreController,
                  decoration: const InputDecoration(labelText: 'Жанр'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                await _bookService.updateMetadata(
                  bookId: widget.bookId,
                  title: titleController.text.trim(),
                  author: authorController.text.trim(),
                  genre: genreController.text.trim(),
                  description: descriptionController.text.trim(),
                );
                if (context.mounted) Navigator.of(context).pop();
                _loadData();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                  );
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  // Диалог подтверждения удаления книги. После удаления возвращаемся
  // на экран библиотеки, передавая true, чтобы список обновился.
  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить книгу?'),
        content: Text(
          'Книга «${_book!.title}» будет удалена вместе с файлом, заметками и историей чтения. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _bookService.deleteBook(widget.bookId);
      if (mounted) Navigator.of(context).pop(true); // возвращаемся в библиотеку
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить книгу: $e')),
        );
      }
    }
  }

  // Диалог выбора полок: показывает чекбоксы всех полок пользователя,
  // отмечая те, на которых книга уже находится. Изменения применяются
  // сразу при переключении (добавление/удаление с полки).
  Future<void> _showAddToShelfDialog() async {
    List<Shelf> shelves;
    try {
      shelves = await _shelfService.getShelves();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить полки: $e')),
        );
      }
      return;
    }

    if (shelves.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('У вас пока нет полок. Создайте полку на вкладке «Полки».')),
        );
      }
      return;
    }

    // Узнаём, на каких полках уже есть эта книга — проверяем книги каждой полки.
    // Для простоты делаем это последовательно (полок обычно немного).
    final selectedShelfIds = <int>{};
    for (final shelf in shelves) {
      try {
        final books = await _shelfService.getShelfBooks(shelf.id);
        if (books.any((b) => b.id == widget.bookId)) {
          selectedShelfIds.add(shelf.id);
        }
      } catch (_) {}
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Добавить на полку'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: shelves.map((shelf) {
                    final isSelected = selectedShelfIds.contains(shelf.id);
                    return CheckboxListTile(
                      title: Text(shelf.name),
                      value: isSelected,
                      onChanged: (checked) async {
                        try {
                          if (checked == true) {
                            await _shelfService.addBookToShelf(
                              shelfId: shelf.id,
                              bookId: widget.bookId,
                            );
                            setDialogState(() => selectedShelfIds.add(shelf.id));
                          } else {
                            await _shelfService.removeBookFromShelf(
                              shelfId: shelf.id,
                              bookId: widget.bookId,
                            );
                            setDialogState(() => selectedShelfIds.remove(shelf.id));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                            );
                          }
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Готово'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _changeCover() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85, // сжимаем, чтобы не грузить на сервер огромные фото с камеры
    );
    if (pickedFile == null) return;

    try {
      await _bookService.updateCover(
        bookId: widget.bookId,
        imagePath: pickedFile.path,
      );
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сменить обложку: $e')),
        );
      }
    }
  }

  // Блок с сохранённым отзывом: оценка, лайк/дизлайк, текст отзыва и кнопка редактирования.
  // Показывается только для уже прочитанных книг.
  Widget _buildReviewSection(Book book) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Мой отзыв', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (book.rating != null)
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < book.rating! ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        );
                      }),
                    ),
                  if (book.liked != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      book.liked! ? Icons.thumb_up : Icons.thumb_down,
                      color: book.liked! ? Colors.green : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      book.liked! ? 'Понравилась' : 'Не понравилась',
                      style: TextStyle(
                        color: book.liked! ? Colors.green.shade700 : Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
              if (book.review != null && book.review!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(book.review!, style: const TextStyle(fontSize: 14)),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _showReviewDialog,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Редактировать отзыв'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
