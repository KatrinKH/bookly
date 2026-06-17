// Модели для экрана статистики чтения

class PeriodStat {
  final String? periodStart; // для month/year
  final String? season; // для season
  final int? year;
  final int booksFinished;
  final double avgRating;
  final int totalPages;
  final int likedCount;

  PeriodStat({
    this.periodStart,
    this.season,
    this.year,
    required this.booksFinished,
    required this.avgRating,
    required this.totalPages,
    required this.likedCount,
  });

  factory PeriodStat.fromJson(Map<String, dynamic> json) {
    return PeriodStat(
      periodStart: json['periodStart'],
      season: json['season'],
      year: json['year'],
      booksFinished: json['booksFinished'] ?? 0,
      avgRating: double.tryParse(json['avgRating'].toString()) ?? 0,
      totalPages: json['totalPages'] ?? 0,
      likedCount: json['likedCount'] ?? 0,
    );
  }

  // Понятная подпись для оси графика / списка
  String get label {
    if (season != null) {
      const seasonNames = {
        'winter': 'Зима',
        'spring': 'Весна',
        'summer': 'Лето',
        'autumn': 'Осень',
      };
      return '${seasonNames[season] ?? season} $year';
    }
    if (periodStart != null) {
      final date = DateTime.parse(periodStart!);
      return '${date.month}.${date.year}';
    }
    return '';
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
  final int totalPagesRead;
  final double avgRating;
  final int likedCount;

  OverallStats({
    required this.totalFinished,
    required this.currentlyReading,
    required this.totalPagesRead,
    required this.avgRating,
    required this.likedCount,
  });

  factory OverallStats.fromJson(Map<String, dynamic> json) {
    return OverallStats(
      totalFinished: json['totalFinished'] ?? 0,
      currentlyReading: json['currentlyReading'] ?? 0,
      totalPagesRead: json['totalPagesRead'] ?? 0,
      avgRating: double.tryParse(json['avgRating'].toString()) ?? 0,
      likedCount: json['likedCount'] ?? 0,
    );
  }
}
