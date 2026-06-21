// Модели для экрана статистики чтения.
// Backend возвращает детальную разбивку на подпериоды:
//   month  -> по дням месяца
//   season -> по трём месяцам сезона
//   year   -> по 12 месяцам года

class PeriodStat {
  final String label; // готовая подпись для оси графика (день/месяц), приходит с backend
  final int booksFinished;
  final double avgRating;
  final double readingHours;
  final int likedCount;

  PeriodStat({
    required this.label,
    required this.booksFinished,
    required this.avgRating,
    required this.readingHours,
    required this.likedCount,
  });

  factory PeriodStat.fromJson(Map<String, dynamic> json) {
    return PeriodStat(
      label: json['label']?.toString() ?? '',
      booksFinished: json['booksFinished'] ?? 0,
      avgRating: double.tryParse(json['avgRating'].toString()) ?? 0,
      readingHours: double.tryParse(json['readingHours'].toString()) ?? 0,
      likedCount: json['likedCount'] ?? 0,
    );
  }
}

// Полный ответ backend для одного запроса статистики: разбивка + заголовок периода + жанры
class StatsResponse {
  final String period; // month | season | year
  final int year;
  final int? month; // только для period == month
  final String? season; // только для period == season
  final String periodLabel; // готовый заголовок: "Июнь 2026", "Лето 2026", "2026"
  final List<PeriodStat> byPeriod;
  final List<GenreStat> topGenres;

  StatsResponse({
    required this.period,
    required this.year,
    this.month,
    this.season,
    required this.periodLabel,
    required this.byPeriod,
    required this.topGenres,
  });

  factory StatsResponse.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as String;
    final label = switch (period) {
      'month' => json['monthLabel'],
      'season' => json['seasonLabel'],
      _ => json['yearLabel'],
    };

    return StatsResponse(
      period: period,
      year: json['year'],
      month: json['month'],
      season: json['season'],
      periodLabel: label?.toString() ?? '',
      byPeriod: (json['byPeriod'] as List? ?? [])
          .map((item) => PeriodStat.fromJson(item))
          .toList(),
      topGenres: (json['topGenres'] as List? ?? [])
          .map((item) => GenreStat.fromJson(item))
          .toList(),
    );
  }
}

class GenreStat {
  final String genre;
  final int count;

  GenreStat({required this.genre, required this.count});

  factory GenreStat.fromJson(Map<String, dynamic> json) {
    return GenreStat(genre: json['genre'], count: json['count']);
  }
}

class OverallStats {
  final int totalFinished;
  final int currentlyReading;
  final double totalReadingHours;
  final double avgRating;
  final int likedCount;

  OverallStats({
    required this.totalFinished,
    required this.currentlyReading,
    required this.totalReadingHours,
    required this.avgRating,
    required this.likedCount,
  });

  factory OverallStats.fromJson(Map<String, dynamic> json) {
    return OverallStats(
      totalFinished: json['totalFinished'] ?? 0,
      currentlyReading: json['currentlyReading'] ?? 0,
      totalReadingHours: double.tryParse(json['totalReadingHours'].toString()) ?? 0,
      avgRating: double.tryParse(json['avgRating'].toString()) ?? 0,
      likedCount: json['likedCount'] ?? 0,
    );
  }
}
