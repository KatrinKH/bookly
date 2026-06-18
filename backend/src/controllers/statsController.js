const pool = require('../config/db');

// Карта периодов в формат, понятный date_trunc в PostgreSQL
const PERIOD_MAP = {
  month: 'month',
  season: null, // сезон обрабатывается отдельно, так как его нет в date_trunc
  year: 'year',
};

// Вспомогательный запрос: суммарное время чтения (в часах) за указанный период.
// Считается из reading_sessions как SUM(ended_at - started_at),
// исключая незакрытые сессии (ended_at IS NULL) и сессии дольше 8 часов
// (защита от незакрытых сессий при аварийном выходе).
async function getReadingHoursForPeriod(userId, truncUnit, periodStart) {
  const result = await pool.query(
    `SELECT
       COALESCE(
         EXTRACT(EPOCH FROM SUM(
           CASE
             WHEN ended_at IS NOT NULL
              AND ended_at - started_at < INTERVAL '8 hours'
             THEN ended_at - started_at
             ELSE INTERVAL '0'
           END
         )) / 3600,
         0
       ) AS hours
     FROM reading_sessions
     WHERE user_id = $1
       AND date_trunc('${truncUnit}', started_at) = $2`,
    [userId, periodStart]
  );
  return parseFloat(result.rows[0].hours).toFixed(1);
}

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

    const truncUnit = PERIOD_MAP[period]; // 'month' или 'year' — значения фиксированы и безопасны

    const finishedBooksResult = await pool.query(
      `SELECT
         date_trunc('${truncUnit}', finished_at) AS period_start,
         COUNT(*) AS books_finished,
         COALESCE(AVG(rating), 0) AS avg_rating,
         COUNT(*) FILTER (WHERE liked = true) AS liked_count
       FROM books
       WHERE user_id = $1 AND status = 'finished' AND finished_at IS NOT NULL
       GROUP BY period_start
       ORDER BY period_start DESC`,
      [req.userId]
    );

    // Для каждого периода считаем часы чтения из сессий
    const byPeriod = await Promise.all(
      finishedBooksResult.rows.map(async (row) => {
        const hours = await getReadingHoursForPeriod(req.userId, truncUnit, row.period_start);
        return {
          periodStart: row.period_start,
          booksFinished: parseInt(row.books_finished, 10),
          avgRating: parseFloat(row.avg_rating).toFixed(2),
          readingHours: parseFloat(hours),
          likedCount: parseInt(row.liked_count, 10),
        };
      })
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
      byPeriod,
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

// Сезонная статистика считается отдельно, так как "сезон" не является
// встроенной единицей date_trunc в PostgreSQL.
async function getSeasonStats(userId) {
  const booksResult = await pool.query(
    `SELECT
       EXTRACT(YEAR FROM finished_at) AS year,
       EXTRACT(MONTH FROM finished_at) AS month,
       rating,
       liked
     FROM books
     WHERE user_id = $1 AND status = 'finished' AND finished_at IS NOT NULL`,
    [userId]
  );

  // Считаем суммарное время чтения по сезонам из сессий
  const sessionsResult = await pool.query(
    `SELECT
       EXTRACT(YEAR FROM started_at) AS year,
       EXTRACT(MONTH FROM started_at) AS month,
       EXTRACT(EPOCH FROM (
         CASE
           WHEN ended_at IS NOT NULL
            AND ended_at - started_at < INTERVAL '8 hours'
           THEN ended_at - started_at
           ELSE INTERVAL '0'
         END
       )) / 3600 AS hours
     FROM reading_sessions
     WHERE user_id = $1 AND ended_at IS NOT NULL`,
    [userId]
  );

  const seasons = {};

  const monthToSeason = (month) => {
    if ([12, 1, 2].includes(month)) return 'winter';
    if ([3, 4, 5].includes(month)) return 'spring';
    if ([6, 7, 8].includes(month)) return 'summer';
    return 'autumn';
  };

  const getSeasonKey = (month, year) => {
    const season = monthToSeason(month);
    const seasonYear = month === 12 ? year + 1 : year;
    return { key: `${seasonYear}-${season}`, season, seasonYear };
  };

  booksResult.rows.forEach((row) => {
    const month = parseInt(row.month, 10);
    const year = parseInt(row.year, 10);
    const { key, season, seasonYear } = getSeasonKey(month, year);

    if (!seasons[key]) {
      seasons[key] = { season, year: seasonYear, booksFinished: 0, ratingSum: 0, ratingCount: 0, readingHours: 0, likedCount: 0 };
    }

    seasons[key].booksFinished += 1;
    if (row.rating) { seasons[key].ratingSum += row.rating; seasons[key].ratingCount += 1; }
    if (row.liked) { seasons[key].likedCount += 1; }
  });

  sessionsResult.rows.forEach((row) => {
    const month = parseInt(row.month, 10);
    const year = parseInt(row.year, 10);
    const { key, season, seasonYear } = getSeasonKey(month, year);

    if (!seasons[key]) {
      seasons[key] = { season, year: seasonYear, booksFinished: 0, ratingSum: 0, ratingCount: 0, readingHours: 0, likedCount: 0 };
    }

    seasons[key].readingHours += parseFloat(row.hours) || 0;
  });

  const byPeriod = Object.values(seasons)
    .map((s) => ({
      season: s.season,
      year: s.year,
      booksFinished: s.booksFinished,
      avgRating: s.ratingCount > 0 ? (s.ratingSum / s.ratingCount).toFixed(2) : '0.00',
      readingHours: parseFloat(s.readingHours.toFixed(1)),
      likedCount: s.likedCount,
    }))
    .sort((a, b) => b.year - a.year);

  return { period: 'season', byPeriod };
}

// Сводная статистика "за всё время" — для главного экрана статистики.
// Считает общее время чтения из сессий вместо суммы страниц.
async function getOverallStats(req, res) {
  try {
    const booksResult = await pool.query(
      `SELECT
         COUNT(*) FILTER (WHERE status = 'finished') AS total_finished,
         COUNT(*) FILTER (WHERE status = 'reading') AS currently_reading,
         COALESCE(AVG(rating) FILTER (WHERE status = 'finished'), 0) AS avg_rating,
         COUNT(*) FILTER (WHERE liked = true) AS liked_count
       FROM books
       WHERE user_id = $1`,
      [req.userId]
    );

    // Суммарное время чтения из всех закрытых сессий пользователя
    const hoursResult = await pool.query(
      `SELECT COALESCE(
         EXTRACT(EPOCH FROM SUM(
           CASE
             WHEN ended_at IS NOT NULL
              AND ended_at - started_at < INTERVAL '8 hours'
             THEN ended_at - started_at
             ELSE INTERVAL '0'
           END
         )) / 3600,
         0
       ) AS total_hours
       FROM reading_sessions
       WHERE user_id = $1`,
      [req.userId]
    );

    const row = booksResult.rows[0];

    res.json({
      totalFinished: parseInt(row.total_finished, 10),
      currentlyReading: parseInt(row.currently_reading, 10),
      totalReadingHours: parseFloat(parseFloat(hoursResult.rows[0].total_hours).toFixed(1)),
      avgRating: parseFloat(row.avg_rating).toFixed(2),
      likedCount: parseInt(row.liked_count, 10),
    });
  } catch (err) {
    console.error('Ошибка получения сводной статистики:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

module.exports = { getStats, getOverallStats };
