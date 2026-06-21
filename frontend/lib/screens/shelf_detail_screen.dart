import 'package:flutter/material.dart';
import '../models/shelf.dart';
import '../models/book.dart';
import '../services/shelf_service.dart';
import '../services/book_service.dart';
import '../widgets/book_card.dart';
import 'book_detail_screen.dart';

// Экран одной полки: список книг на ней, возможность убрать книгу с полки,
// переименовать или удалить саму полку.
class ShelfDetailScreen extends StatefulWidget {
  final Shelf shelf;

  const ShelfDetailScreen({super.key, required this.shelf});

  @override
  State<ShelfDetailScreen> createState() => _ShelfDetailScreenState();
}

class _ShelfDetailScreenState extends State<ShelfDetailScreen> {
  final ShelfService _shelfService = ShelfService();
  final BookService _bookService = BookService();

  late String _shelfName;
  List<Book> _books = [];
  bool _isLoading = true;
  String _sort = 'date_added'; // date_added | title

  @override
  void initState() {
    super.initState();
    _shelfName = widget.shelf.name;
    _loadBooks();
  }

  // Список книг с учётом выбранной сортировки.
  // 'date_added' — порядок, в котором их вернул backend (по дате добавления на полку, новые сверху).
  // 'title' — по алфавиту названия книги (без учёта регистра).
  List<Book> get _sortedBooks {
    if (_sort == 'title') {
      final sorted = [..._books];
      sorted.sort((a, b) {
        final titleA = _normalizeForSort(a.title);
        final titleB = _normalizeForSort(b.title);
        return titleA.compareTo(titleB);
      });
      return sorted;
    }
    return _books;
  }

  // Некоторые названия книг содержат "й"/"ё" в разложенной Unicode-форме
  // (например, "и" + U+0306 combining breve вместо единого символа "й").
  // Это приводит к неправильному алфавитному сравнению, так как "и"
  // оказывается "меньше" любой другой буквы, идущей после полного "й".
  // Приводим такие сочетания к стандартной составной форме перед сравнением.
  String _normalizeForSort(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll('и\u0306', 'й') // и + combining breve -> й
        .replaceAll('е\u0308', 'ё'); // е + combining diaeresis -> ё (на всякий случай)
  }

  void _onSortChanged(String sort) {
    setState(() => _sort = sort);
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    try {
      final books = await _shelfService.getShelfBooks(widget.shelf.id);
      setState(() => _books = books);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить книги полки: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeBook(Book book) async {
    try {
      await _shelfService.removeBookFromShelf(shelfId: widget.shelf.id, bookId: book.id);
      _loadBooks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось убрать книгу с полки: $e')),
        );
      }
    }
  }

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: _shelfName);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Переименовать полку'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              try {
                await _shelfService.renameShelf(shelfId: widget.shelf.id, name: name);
                if (context.mounted) Navigator.of(context).pop();
                setState(() => _shelfName = name);
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

  Future<void> _showDeleteShelfConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить полку?'),
        content: Text(
          'Полка «$_shelfName» будет удалена. Книги на ней останутся в библиотеке.',
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
      await _shelfService.deleteShelf(widget.shelf.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить полку: $e')),
        );
      }
    }
  }

  // Диалог выбора книг из всей библиотеки для добавления на эту полку.
  // Отмечает чекбоксами книги, которые уже есть на полке.
  Future<void> _showAddBooksDialog() async {
    List<Book> allBooks;
    try {
      allBooks = await _bookService.getBooks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить книги: $e')),
        );
      }
      return;
    }

    if (allBooks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('В вашей библиотеке пока нет книг')),
        );
      }
      return;
    }

    final selectedBookIds = _books.map((b) => b.id).toSet();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Добавить книги на полку'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: allBooks.map((book) {
                    final isSelected = selectedBookIds.contains(book.id);
                    return CheckboxListTile(
                      title: Text(book.title),
                      subtitle: book.author != null ? Text(book.author!) : null,
                      value: isSelected,
                      onChanged: (checked) async {
                        try {
                          if (checked == true) {
                            await _shelfService.addBookToShelf(
                              shelfId: widget.shelf.id,
                              bookId: book.id,
                            );
                            setDialogState(() => selectedBookIds.add(book.id));
                          } else {
                            await _shelfService.removeBookFromShelf(
                              shelfId: widget.shelf.id,
                              bookId: book.id,
                            );
                            setDialogState(() => selectedBookIds.remove(book.id));
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

    _loadBooks(); // Обновляем список книг полки после закрытия диалога
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_shelfName),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Сортировка',
            onSelected: _onSortChanged,
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'date_added',
                checked: _sort == 'date_added',
                child: const Text('По дате добавления'),
              ),
              CheckedPopupMenuItem(
                value: 'title',
                checked: _sort == 'title',
                child: const Text('По названию'),
              ),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'add_books') {
                _showAddBooksDialog();
              } else if (value == 'rename') {
                _showRenameDialog();
              } else if (value == 'delete') {
                _showDeleteShelfConfirmation();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_books',
                child: ListTile(
                  leading: Icon(Icons.add_circle_outline),
                  title: Text('Добавить книги'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Переименовать'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('Удалить полку', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBooks,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _books.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _sortedBooks.length,
                      itemBuilder: (context, index) {
                        final book = _sortedBooks[index];
                        return Dismissible(
                          key: ValueKey(book.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          confirmDismiss: (_) async => true,
                          onDismissed: (_) => _removeBook(book),
                          child: BookCard(
                            book: book,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
                              );
                              _loadBooks();
                            },
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('На этой полке пока нет книг', style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(
                      'Добавьте книгу через меню сверху',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _showAddBooksDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить книги'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
