const pool = require('../config/db');

// Карта периодов в формат, понятный date_trunc в PostgreSQL
const PERIOD_MAP = {
  month: 'month',
  season: null, // сезон обрабатывается отдельно, так как его нет в date_trunc
  year: 'year',
};

// Возвращает общую статистику за заданный период: month | season | year
async function getStats(req, res) {
  const period = req.query.period || 'month';

  if (!['month', 'season', 'year'].includes(period)) {
    return res.status(400).json({ error: 'Параметр period должен быть month, season или year' });
  }

  try {
    if (period === 'season') {
      return res.json(await getSeasonStats(req.userId));
    }

    const truncUnit = PERIOD_MAP[period];

    const finishedBooksResult = await pool.query(
      `SELECT
         date_trunc($1, finished_at) AS period_start,
         COUNT(*) AS books_finished,
         COALESCE(AVG(rating), 0) AS avg_rating,
         COALESCE(SUM(total_pages), 0) AS total_pages,
         COUNT(*) FILTER (WHERE liked = true) AS liked_count
       FROM books
       WHERE user_id = $2 AND status = 'finished' AND finished_at IS NOT NULL
       GROUP BY period_start
       ORDER BY period_start DESC`,
      [truncUnit, req.userId]
    );

    const genreResult = await pool.query(
      `SELECT genre, COUNT(*) AS count
       FROM books
       WHERE user_id = $1 AND status = 'finished' AND genre IS NOT NULL
       GROUP BY genre
       ORDER BY count DESC
       LIMIT 5`,
      [req.userId]
    );

    res.json({
      period,
      byPeriod: finishedBooksResult.rows.map((row) => ({
        periodStart: row.period_start,
        booksFinished: parseInt(row.books_finished, 10),
        avgRating: parseFloat(row.avg_rating).toFixed(2),
        totalPages: parseInt(row.total_pages, 10),
        likedCount: parseInt(row.liked_count, 10),
      })),
      topGenres: genreResult.rows.map((row) => ({
        genre: row.genre,
        count: parseInt(row.count, 10),
      })),
    });
  } catch (err) {
    console.error('Ошибка получения статистики:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Сезонная статистика считается отдельно: группируем по году и кварталу-сезону вручную,
// поскольку в PostgreSQL "сезон" не является встроенной единицей date_trunc.
async function getSeasonStats(userId) {
  const result = await pool.query(
    `SELECT
       EXTRACT(YEAR FROM finished_at) AS year,
       EXTRACT(MONTH FROM finished_at) AS month,
       rating,
       liked,
       total_pages
     FROM books
     WHERE user_id = $1 AND status = 'finished' AND finished_at IS NOT NULL`,
    [userId]
  );

  const seasons = {}; // ключ вида "2026-winter"

  const monthToSeason = (month) => {
    if ([12, 1, 2].includes(month)) return 'winter';
    if ([3, 4, 5].includes(month)) return 'spring';
    if ([6, 7, 8].includes(month)) return 'summer';
    return 'autumn';
  };

  result.rows.forEach((row) => {
    const month = parseInt(row.month, 10);
    const year = parseInt(row.year, 10);
    const season = monthToSeason(month);
    // Зима условно относится к году, в котором она заканчивается (январь/февраль)
    const seasonYear = month === 12 ? year + 1 : year;
    const key = `${seasonYear}-${season}`;

    if (!seasons[key]) {
      seasons[key] = {
        season,
        year: seasonYear,
        booksFinished: 0,
        ratingSum: 0,
        ratingCount: 0,
        totalPages: 0,
        likedCount: 0,
      };
    }

    seasons[key].booksFinished += 1;
    seasons[key].totalPages += row.total_pages || 0;
    if (row.rating) {
      seasons[key].ratingSum += row.rating;
      seasons[key].ratingCount += 1;
    }
    if (row.liked) {
      seasons[key].likedCount += 1;
    }
  });

  const byPeriod = Object.values(seasons)
    .map((s) => ({
      season: s.season,
      year: s.year,
      booksFinished: s.booksFinished,
      avgRating: s.ratingCount > 0 ? (s.ratingSum / s.ratingCount).toFixed(2) : '0.00',
      totalPages: s.totalPages,
      likedCount: s.likedCount,
    }))
    .sort((a, b) => b.year - a.year);

  return { period: 'season', byPeriod };
}

// Сводная статистика "за всё время" — для главного экрана статистики
async function getOverallStats(req, res) {
  try {
    const result = await pool.query(
      `SELECT
         COUNT(*) FILTER (WHERE status = 'finished') AS total_finished,
         COUNT(*) FILTER (WHERE status = 'reading') AS currently_reading,
         COALESCE(SUM(total_pages) FILTER (WHERE status = 'finished'), 0) AS total_pages_read,
         COALESCE(AVG(rating) FILTER (WHERE status = 'finished'), 0) AS avg_rating,
         COUNT(*) FILTER (WHERE liked = true) AS liked_count
       FROM books
       WHERE user_id = $1`,
      [req.userId]
    );

    const row = result.rows[0];

    res.json({
      totalFinished: parseInt(row.total_finished, 10),
      currentlyReading: parseInt(row.currently_reading, 10),
      totalPagesRead: parseInt(row.total_pages_read, 10),
      avgRating: parseFloat(row.avg_rating).toFixed(2),
      likedCount: parseInt(row.liked_count, 10),
    });
  } catch (err) {
    console.error('Ошибка получения сводной статистики:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

module.exports = { getStats, getOverallStats };
