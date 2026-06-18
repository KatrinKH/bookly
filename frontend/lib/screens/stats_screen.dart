import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/stats.dart';
import '../services/stats_service.dart';
import '../utils/app_theme.dart';

// Экран статистики чтения: сводные показатели, переключение периода
// (месяц/сезон/год) и график количества прочитанных книг.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final StatsService _statsService = StatsService();

  String _selectedPeriod = 'month';
  OverallStats? _overall;
  List<PeriodStat> _periodStats = [];
  List<GenreStat> _topGenres = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    OverallStats? overall;
    List<PeriodStat> periodStats = [];
    List<GenreStat> genres = [];
    String? errorMessage;

    // Каждый запрос обрабатывается отдельно: если один из них упадёт
    // (например, статистика по жанрам), это не должно скрыть данные,
    // которые успешно загрузились из других запросов.
    try {
      overall = await _statsService.getOverallStats();
    } catch (e) {
      errorMessage = 'Сводная статистика: $e';
    }

    try {
      periodStats = await _statsService.getPeriodStats(_selectedPeriod);
    } catch (e) {
      errorMessage = 'Статистика по периодам: $e';
    }

    try {
      genres = await _statsService.getTopGenres();
    } catch (e) {
      errorMessage ??= 'Жанры: $e';
    }

    if (mounted) {
      setState(() {
        _overall = overall;
        _periodStats = periodStats;
        _topGenres = genres;
        _isLoading = false;
      });

      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки статистики: $errorMessage')),
        );
      }
    }
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
                          const SizedBox(height: 8),
                          _buildPeriodSelector(),
                        ],
                      ),
                    ),
                    if (_periodStats.isEmpty)
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
                            _buildChart(),
                            const SizedBox(height: 24),
                            if (_topGenres.isNotEmpty) _buildGenresList(),
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
    final hoursLabel = hours < 1
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

  Widget _buildPeriodSelector() {
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
              onTap: () {
                setState(() => _selectedPeriod = value);
                _loadStats();
              },
            ),
          ),
          if (value != periods.last.$1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildChart() {
    final reversedStats = _periodStats.reversed.toList();
    final maxBooks = reversedStats
        .map((s) => s.booksFinished)
        .fold<int>(1, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: (maxBooks + 1).toDouble(),
          barGroups: List.generate(reversedStats.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: reversedStats[i].booksFinished.toDouble(),
                  color: Colors.indigo,
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= reversedStats.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      reversedStats[index].label,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildGenresList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Любимые жанры', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ..._topGenres.map((genre) => Padding(
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

// Одна кнопка выбора периода статистики (Месяц/Сезон/Год).
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
