import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/stats.dart';
import '../services/stats_service.dart';
import '../utils/app_theme.dart';

const _seasonOrder = ['winter', 'spring', 'summer', 'autumn'];
const _seasonNamesRu = {
  'winter': 'Зима',
  'spring': 'Весна',
  'summer': 'Лето',
  'autumn': 'Осень',
};

// Экран статистики чтения: сводные показатели, переключение периода
// (месяц/сезон/год) и график по дням/месяцам с навигацией вперёд-назад
// для просмотра конкретного прошлого периода.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final StatsService _statsService = StatsService();

  String _selectedPeriod = 'month'; // month | season | year

  // Текущий выбранный "якорь" периода — по умолчанию сегодняшняя дата
  late int _year;
  late int _month; // 1..12, актуально для period == month
  late String _season; // актуально для period == season

  OverallStats? _overall;
  StatsResponse? _statsResponse;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _season = _monthToSeason(now.month);
    _loadStats();
  }

  String _monthToSeason(int month) {
    if ([12, 1, 2].contains(month)) return 'winter';
    if ([3, 4, 5].contains(month)) return 'spring';
    if ([6, 7, 8].contains(month)) return 'summer';
    return 'autumn';
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    OverallStats? overall;
    StatsResponse? statsResponse;
    String? errorMessage;

    try {
      overall = await _statsService.getOverallStats();
    } catch (e) {
      errorMessage = 'Сводная статистика: $e';
    }

    try {
      statsResponse = await _statsService.getStats(
        period: _selectedPeriod,
        year: _year,
        month: _selectedPeriod == 'month' ? _month : null,
        season: _selectedPeriod == 'season' ? _season : null,
      );
    } catch (e) {
      errorMessage = 'Статистика по периодам: $e';
    }

    if (mounted) {
      setState(() {
        _overall = overall;
        _statsResponse = statsResponse;
        _isLoading = false;
      });

      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки статистики: $errorMessage')),
        );
      }
    }
  }

  // Переключение на предыдущий/следующий период того же типа (месяц/сезон/год)
  void _goToPreviousPeriod() {
    setState(() {
      switch (_selectedPeriod) {
        case 'month':
          if (_month == 1) {
            _month = 12;
            _year -= 1;
          } else {
            _month -= 1;
          }
          break;
        case 'season':
          final index = _seasonOrder.indexOf(_season);
          if (index == 0) {
            _season = _seasonOrder.last;
            _year -= 1;
          } else {
            _season = _seasonOrder[index - 1];
          }
          break;
        case 'year':
          _year -= 1;
          break;
      }
    });
    _loadStats();
  }

  void _goToNextPeriod() {
    setState(() {
      switch (_selectedPeriod) {
        case 'month':
          if (_month == 12) {
            _month = 1;
            _year += 1;
          } else {
            _month += 1;
          }
          break;
        case 'season':
          final index = _seasonOrder.indexOf(_season);
          if (index == _seasonOrder.length - 1) {
            _season = _seasonOrder.first;
            _year += 1;
          } else {
            _season = _seasonOrder[index + 1];
          }
          break;
        case 'year':
          _year += 1;
          break;
      }
    });
    _loadStats();
  }

  // Возвращает к текущему месяцу/сезону/году
  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _year = now.year;
      _month = now.month;
      _season = _monthToSeason(now.month);
    });
    _loadStats();
  }

  void _onPeriodTypeChanged(String period) {
    setState(() => _selectedPeriod = period);
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Статистика чтения',
          style: AppTheme.brandFont(
            fontSize: 22,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        children: [
                          if (_overall != null) _buildOverallCards(_overall!),
                          const SizedBox(height: 12),
                          _buildPeriodTypeSelector(),
                          const SizedBox(height: 12),
                          _buildPeriodNavigator(),
                        ],
                      ),
                    ),
                    if (_statsResponse == null || _statsResponse!.byPeriod.every((s) => s.booksFinished == 0))
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: constraints.maxHeight,
                                  child: Center(
                                    child: Text(
                                      'Пока нет завершённых книг за этот период',
                                      style: TextStyle(color: Colors.grey.shade600),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    else
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          children: [
                            _buildChart(_statsResponse!),
                            const SizedBox(height: 24),
                            if (_statsResponse!.topGenres.isNotEmpty) _buildGenresList(_statsResponse!),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildOverallCards(OverallStats stats) {
    final hours = stats.totalReadingHours;
    final hoursLabel = hours == 0
        ? '0'
        : hours < 1
            ? '${(hours * 60).round()} мин'
            : '${hours.toStringAsFixed(1)} ч';

    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Прочитано книг', value: '${stats.totalFinished}')),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Часов чтения', value: hoursLabel)),
      ],
    );
  }

  Widget _buildPeriodTypeSelector() {
    const periods = [
      ('month', 'Месяц'),
      ('season', 'Сезон'),
      ('year', 'Год'),
    ];

    return Row(
      children: [
        for (final (value, label) in periods) ...[
          Expanded(
            child: _PeriodOptionButton(
              label: label,
              selected: _selectedPeriod == value,
              color: Theme.of(context).colorScheme.primary,
              onTap: () => _onPeriodTypeChanged(value),
            ),
          ),
          if (value != periods.last.$1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  // Строка навигации: ⬅ название текущего периода ➡, плюс кнопка "Сегодня"
  // если сейчас просматривается не текущий период.
  Widget _buildPeriodNavigator() {
    final isCurrentPeriod = _isViewingCurrentPeriod();

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _goToPreviousPeriod,
          tooltip: 'Предыдущий период',
        ),
        Expanded(
          child: Center(
            child: Text(
              _statsResponse?.periodLabel ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _goToNextPeriod,
          tooltip: 'Следующий период',
        ),
        if (!isCurrentPeriod)
          IconButton(
            icon: const Icon(Icons.today_outlined),
            onPressed: _goToToday,
            tooltip: 'Текущий период',
          ),
      ],
    );
  }

  bool _isViewingCurrentPeriod() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'month':
        return _year == now.year && _month == now.month;
      case 'season':
        return _year == now.year && _season == _monthToSeason(now.month);
      case 'year':
        return _year == now.year;
      default:
        return true;
    }
  }

  Widget _buildChart(StatsResponse response) {
    final stats = response.byPeriod;
    final maxBooks = stats
        .map((s) => s.booksFinished)
        .fold<int>(1, (a, b) => a > b ? a : b);

    // Для месяца (до 31 точки) подписи показываем не на каждом делении,
    // чтобы они не слипались — например каждое 5-е число.
    final showEveryLabel = response.period != 'month' || stats.length <= 14;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: (maxBooks + 1).toDouble(),
          barGroups: List.generate(stats.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: stats[i].booksFinished.toDouble(),
                  color: Colors.indigo,
                  width: response.period == 'month' ? 8 : 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) return const SizedBox.shrink();
                  return Text(value.toInt().toString(), style: const TextStyle(fontSize: 11));
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= stats.length) {
                    return const SizedBox.shrink();
                  }
                  // Прячем часть подписей для месяца, чтобы избежать слипания текста
                  if (!showEveryLabel && (index + 1) % 5 != 0 && index != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      stats[index].label,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildGenresList(StatsResponse response) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Любимые жанры', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...response.topGenres.map((genre) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(genre.genre)),
                  Text('${genre.count} книг', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            )),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// Кнопка выбора типа периода (Месяц/Сезон/Год).
// Используется внутри Row+Expanded, поэтому все три кнопки всегда
// получают строго одинаковую ширину и не меняют размер при выборе.
class _PeriodOptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _PeriodOptionButton({
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
          padding: const EdgeInsets.symmetric(vertical: 12),
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
            ),
          ),
        ),
      ),
    );
  }
}
