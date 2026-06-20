import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/book.dart';
import '../models/note.dart';
import '../services/book_service.dart';
import '../services/note_service.dart';
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

  Future<void> _showFinishDialog() async {
    int rating = _book!.rating ?? 3;
    bool liked = _book!.liked ?? true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Завершить книгу'),
              content: Column(
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
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Понравилась книга'),
                    value: liked,
                    onChanged: (value) => setDialogState(() => liked = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () async {
                    await _bookService.finishBook(
                      bookId: widget.bookId,
                      rating: rating,
                      liked: liked,
                    );
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
              }
            },
            itemBuilder: (context) => [
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
                  onPressed: _showFinishDialog,
                  child: const Text('Завершить'),
                ),
              ],
            ],
          ),
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
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать книгу'),
        content: Form(
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
              if (!formKey.currentState!.validate()) return;

              try {
                await _bookService.updateMetadata(
                  bookId: widget.bookId,
                  title: titleController.text.trim(),
                  author: authorController.text.trim(),
                  genre: genreController.text.trim(),
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
