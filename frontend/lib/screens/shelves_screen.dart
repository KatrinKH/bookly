import 'package:flutter/material.dart';
import '../models/shelf.dart';
import '../services/shelf_service.dart';
import '../utils/app_theme.dart';
import 'shelf_detail_screen.dart';

// Экран со списком полок пользователя.
// Поддерживает сортировку: новые сначала, старые сначала,
// либо полка с последним добавлением книги — первая.
class ShelvesScreen extends StatefulWidget {
  const ShelvesScreen({super.key});

  @override
  State<ShelvesScreen> createState() => _ShelvesScreenState();
}

class _ShelvesScreenState extends State<ShelvesScreen> {
  final ShelfService _shelfService = ShelfService();

  List<Shelf> _shelves = [];
  bool _isLoading = true;
  String _sort = 'newest'; // newest | oldest | recently_updated

  @override
  void initState() {
    super.initState();
    _loadShelves();
  }

  Future<void> _loadShelves() async {
    setState(() => _isLoading = true);
    try {
      final shelves = await _shelfService.getShelves(sort: _sort);
      setState(() => _shelves = shelves);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить полки: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSortChanged(String sort) {
    setState(() => _sort = sort);
    _loadShelves();
  }

  Future<void> _showCreateShelfDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая полка'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Название полки',
            hintText: 'Например: Хочу прочитать',
            border: OutlineInputBorder(),
          ),
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
                await _shelfService.createShelf(name);
                if (context.mounted) Navigator.of(context).pop();
                _loadShelves();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                  );
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Мои полки',
          style: AppTheme.brandFont(
            fontSize: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateShelfDialog,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadShelves,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildSortSelector(),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _shelves.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _shelves.length,
                            itemBuilder: (context, index) => _buildShelfCard(_shelves[index]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortSelector() {
    const options = [
      ('newest', 'Новые'),
      ('oldest', 'Старые'),
      ('recently_updated', 'По обновлению'),
    ];

    return Row(
      children: [
        for (final (value, label) in options) ...[
          Expanded(
            child: _SortOptionButton(
              label: label,
              selected: _sort == value,
              color: Theme.of(context).colorScheme.primary,
              onTap: () => _onSortChanged(value),
            ),
          ),
          if (value != options.last.$1) const SizedBox(width: 8),
        ],
      ],
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
                    Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('Пока нет полок', style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(
                      'Нажмите +, чтобы создать первую полку',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
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

  Widget _buildShelfCard(Shelf shelf) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
          child: Icon(Icons.menu_book_outlined, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(shelf.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${shelf.bookCount ?? 0} книг'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ShelfDetailScreen(shelf: shelf)),
          );
          _loadShelves();
        },
      ),
    );
  }
}

// Кнопка выбора варианта сортировки — переиспользует тот же визуальный стиль,
// что и переключатели периода в статистике, для единообразия интерфейса.
class _SortOptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SortOptionButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withOpacity(0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.grey.shade400,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : Colors.grey.shade700,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
