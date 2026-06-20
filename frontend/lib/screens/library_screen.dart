import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import '../utils/app_theme.dart';
import '../widgets/book_card.dart';
import '../widgets/book_grid_card.dart';
import 'book_detail_screen.dart';
import 'upload_book_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';

// Главный экран приложения: список книг библиотеки пользователя
// с фильтром по статусу и нижней навигацией между разделами.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const _LibraryTab(),
      const StatsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: tabs[_currentTab],
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              onPressed: () async {
                final added = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const UploadBookScreen()),
                );
                if (added == true && mounted) {
                  setState(() {}); // Обновляем список после добавления книги
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) => setState(() => _currentTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Библиотека'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Статистика'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Профиль'),
        ],
      ),
    );
  }
}

// Вкладка со списком книг и фильтром по статусу
class _LibraryTab extends StatefulWidget {
  const _LibraryTab();

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab> {
  final BookService _bookService = BookService();
  List<Book> _books = [];
  bool _isLoading = true;
  String? _statusFilter;
  bool _isGridView = false; // false = список, true = сетка 2 в ряд

  // Поиск по названию — фильтрует уже загруженный список локально,
  // без дополнительных запросов к серверу.
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  static const _viewModeKey = 'library_view_mode';

  @override
  void initState() {
    super.initState();
    _loadViewMode();
    _loadBooks();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isGrid = prefs.getBool(_viewModeKey) ?? false;
    if (mounted) setState(() => _isGridView = isGrid);
  }

  Future<void> _toggleViewMode() async {
    setState(() => _isGridView = !_isGridView);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_viewModeKey, _isGridView);
  }

  void _openSearch() {
    setState(() => _isSearching = true);
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  // Список книг с учётом поискового запроса по названию (без учёта регистра)
  List<Book> get _filteredBooks {
    if (_searchQuery.isEmpty) return _books;
    final query = _searchQuery.toLowerCase();
    return _books.where((book) => book.title.toLowerCase().contains(query)).toList();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    try {
      final books = await _bookService.getBooks(status: _statusFilter);
      setState(() => _books = books);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить книги: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadBooks,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              leading: _isSearching
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: 'Поиск по названию',
                      onPressed: _openSearch,
                    ),
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Поиск по названию...',
                        border: InputBorder.none,
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    )
                  : Text(
                      'Моя библиотека',
                      style: AppTheme.brandFont(
                        fontSize: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
              centerTitle: !_isSearching,
              floating: true,
              automaticallyImplyLeading: false,
              actions: [
                if (_isSearching)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Закрыть поиск',
                    onPressed: _closeSearch,
                  )
                else
                  IconButton(
                    icon: Icon(_isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined),
                    tooltip: _isGridView ? 'Список' : 'Сетка',
                    onPressed: _toggleViewMode,
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _FilterChip(label: 'Все', selected: _statusFilter == null, onTap: () {
                      setState(() => _statusFilter = null);
                      _loadBooks();
                    }),
                    _FilterChip(label: 'Читаю', selected: _statusFilter == 'reading', onTap: () {
                      setState(() => _statusFilter = 'reading');
                      _loadBooks();
                    }),
                    _FilterChip(label: 'Прочитано', selected: _statusFilter == 'finished', onTap: () {
                      setState(() => _statusFilter = 'finished');
                      _loadBooks();
                    }),
                    _FilterChip(label: 'Не начато', selected: _statusFilter == 'not_started', onTap: () {
                      setState(() => _statusFilter = 'not_started');
                      _loadBooks();
                    }),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (_isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_filteredBooks.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty ? Icons.search_off : Icons.menu_book_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty ? 'Ничего не найдено' : 'Пока нет книг',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Попробуйте изменить запрос'
                            : 'Нажмите +, чтобы добавить первую книгу',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else if (_isGridView)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    // Ширина одной колонки = (доступная ширина - отступ между колонками) / 2
                    final columnWidth = (constraints.crossAxisExtent - 12) / 2;
                    // Высота обложки определяется аспектом 3:4 от ширины колонки
                    final coverHeight = columnWidth * 4 / 3;
                    // Текстовый блок имеет фиксированную высоту 92 (см. book_grid_card.dart)
                    const textBlockHeight = 98.0;
                    final cardHeight = coverHeight + textBlockHeight;
                    final aspectRatio = columnWidth / cardHeight;

                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: aspectRatio,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final book = _filteredBooks[index];
                          return BookGridCard(
                            book: book,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
                              );
                              _loadBooks();
                            },
                          );
                        },
                        childCount: _filteredBooks.length,
                      ),
                    );
                  },
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final book = _filteredBooks[index];
                    return BookCard(
                      book: book,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
                        );
                        _loadBooks();
                      },
                    );
                  },
                  childCount: _filteredBooks.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
