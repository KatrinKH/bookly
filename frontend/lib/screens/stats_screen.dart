import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/stats.dart';
import '../services/stats_service.dart';

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
    try {
      final overall = await _statsService.getOverallStats();
      final periodStats = await _statsService.getPeriodStats(_selectedPeriod);
      final genres = await _statsService.getTopGenres();

      setState(() {
        _overall = overall;
        _periodStats = periodStats;
        _topGenres = genres;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки статистики: $e')),
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
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Статистика чтения',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_overall != null) _buildOverallCards(_overall!),
              const SizedBox(height: 24),
              _buildPeriodSelector(),
              const SizedBox(height: 16),
              if (_periodStats.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Пока нет завершённых книг за этот период',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ),
                )
              else
                _buildChart(),
              const SizedBox(height: 24),
              if (_topGenres.isNotEmpty) _buildGenresList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverallCards(OverallStats stats) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Прочитано книг', value: '${stats.totalFinished}')),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Страниц всего', value: '${stats.totalPagesRead}')),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'month', label: Text('Месяц')),
        ButtonSegment(value: 'season', label: Text('Сезон')),
        ButtonSegment(value: 'year', label: Text('Год')),
      ],
      selected: {_selectedPeriod},
      onSelectionChanged: (selection) {
        setState(() => _selectedPeriod = selection.first);
        _loadStats();
      },
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
