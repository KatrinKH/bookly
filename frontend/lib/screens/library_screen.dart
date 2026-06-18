import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import '../utils/app_theme.dart';
import '../widgets/book_card.dart';
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

  @override
  void initState() {
    super.initState();
    _loadBooks();
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
              title: Text(
                'Моя библиотека',
                style: AppTheme.brandFont(
                  fontSize: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              centerTitle: true,
              floating: true,
              automaticallyImplyLeading: false,
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
            else if (_books.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('Пока нет книг', style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Text('Нажмите +, чтобы добавить первую книгу',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final book = _books[index];
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
                  childCount: _books.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
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
