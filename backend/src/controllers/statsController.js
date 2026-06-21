const pool = require('../config/db');

// Вспомогательная функция: считает часы чтения из reading_sessions
// за промежуток [from, to) для конкретного пользователя.
// Сессии без ended_at и длиннее 8 часов исключаются (защита от "забытых" сессий).
async function getReadingHours(userId, from, to) {
  const result = await pool.query(
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
     ) AS hours
     FROM reading_sessions
     WHERE user_id = $1 AND started_at >= $2 AND started_at < $3`,
    [userId, from, to]
  );
  return parseFloat(parseFloat(result.rows[0].hours).toFixed(1));
}

// Считает книги/оценку/лайки, завершённые в промежутке [from, to)
async function getBookStatsInRange(userId, from, to) {
  const result = await pool.query(
    `SELECT
       COUNT(*) AS books_finished,
       COALESCE(AVG(rating), 0) AS avg_rating,
       COUNT(*) FILTER (WHERE liked = true) AS liked_count
     FROM books
     WHERE user_id = $1 AND status = 'finished'
       AND finished_at >= $2 AND finished_at < $3`,
    [userId, from, to]
  );
  const row = result.rows[0];
  return {
    booksFinished: parseInt(row.books_finished, 10),
    avgRating: parseFloat(row.avg_rating).toFixed(2),
    likedCount: parseInt(row.liked_count, 10),
  };
}

const MONTH_NAMES = [
  'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
  'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
];

// Сокращённые названия — используются только для подписей на оси X
// в режиме "Год", где иначе 12 полных названий месяцев не помещаются на экране.
const MONTH_NAMES_SHORT = [
  'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
  'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек',
];

const SEASON_MONTHS = {
  winter: [12, 1, 2],
  spring: [3, 4, 5],
  summer: [6, 7, 8],
  autumn: [9, 10, 11],
};

function monthToSeason(month) {
  if ([12, 1, 2].includes(month)) return 'winter';
  if ([3, 4, 5].includes(month)) return 'spring';
  if ([6, 7, 8].includes(month)) return 'summer';
  return 'autumn';
}

// Возвращает детальную статистику чтения с разбивкой на подпериоды:
//   period=month  -> по дням выбранного месяца (?year=YYYY&month=MM)
//   period=season -> по месяцам выбранного сезона (?year=YYYY&season=winter|spring|summer|autumn)
//   period=year   -> по месяцам выбранного года (?year=YYYY)
// Если year/month/season не переданы — используется текущая дата.
async function getStats(req, res) {
  const period = req.query.period || 'month';

  if (!['month', 'season', 'year'].includes(period)) {
    return res.status(400).json({ error: 'Параметр period должен быть month, season или year' });
  }

  const now = new Date();
  const year = parseInt(req.query.year, 10) || now.getFullYear();

  try {
    if (period === 'month') {
      const month = parseInt(req.query.month, 10) || now.getMonth() + 1; // 1..12
      return res.json(await getMonthBreakdown(req.userId, year, month));
    }

    if (period === 'season') {
      const season = req.query.season || monthToSeason(now.getMonth() + 1);
      return res.json(await getSeasonBreakdown(req.userId, year, season));
    }

    // period === 'year'
    return res.json(await getYearBreakdown(req.userId, year));
  } catch (err) {
    console.error('Ошибка получения статистики:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Разбивка месяца по дням
async function getMonthBreakdown(userId, year, month) {
  const daysInMonth = new Date(year, month, 0).getDate();
  const byPeriod = [];

  for (let day = 1; day <= daysInMonth; day++) {
    const from = new Date(year, month - 1, day);
    const to = new Date(year, month - 1, day + 1);

    const bookStats = await getBookStatsInRange(userId, from, to);
    const hours = await getReadingHours(userId, from, to);

    byPeriod.push({
      label: `${day}`,
      day,
      booksFinished: bookStats.booksFinished,
      avgRating: bookStats.avgRating,
      readingHours: hours,
      likedCount: bookStats.likedCount,
    });
  }

  const topGenres = await getTopGenresInRange(
    userId,
    new Date(year, month - 1, 1),
    new Date(year, month, 1)
  );

  const finishedBooks = await getFinishedBooksInRange(
    userId,
    new Date(year, month - 1, 1),
    new Date(year, month, 1)
  );

  return {
    period: 'month',
    year,
    month,
    monthLabel: `${MONTH_NAMES[month - 1]} ${year}`,
    byPeriod,
    finishedBooks,
    topGenres,
  };
}

// Разбивка сезона по трём месяцам
async function getSeasonBreakdown(userId, year, season) {
  const months = SEASON_MONTHS[season];
  if (!months) {
    throw new Error('Некорректное название сезона');
  }

  const byPeriod = [];

  for (const month of months) {
    // Зимние месяцы декабрь относится к предыдущему календарному году относительно year сезона
    const calendarYear = season === 'winter' && month === 12 ? year - 1 : year;
    const from = new Date(calendarYear, month - 1, 1);
    const to = new Date(calendarYear, month, 1);

    const bookStats = await getBookStatsInRange(userId, from, to);
    const hours = await getReadingHours(userId, from, to);

    byPeriod.push({
      label: MONTH_NAMES[month - 1],
      month,
      booksFinished: bookStats.booksFinished,
      avgRating: bookStats.avgRating,
      readingHours: hours,
      likedCount: bookStats.likedCount,
    });
  }

  const seasonStart = new Date(
    season === 'winter' ? year - 1 : year,
    months[0] - 1,
    1
  );
  const seasonEnd = new Date(year, months[months.length - 1], 1);

  const topGenres = await getTopGenresInRange(userId, seasonStart, seasonEnd);
  const finishedBooks = await getFinishedBooksInRange(userId, seasonStart, seasonEnd);

  const seasonNames = { winter: 'Зима', spring: 'Весна', summer: 'Лето', autumn: 'Осень' };

  return {
    period: 'season',
    year,
    season,
    seasonLabel: `${seasonNames[season]} ${year}`,
    byPeriod,
    finishedBooks,
    topGenres,
  };
}

// Разбивка года по 12 месяцам
async function getYearBreakdown(userId, year) {
  const byPeriod = [];

  for (let month = 1; month <= 12; month++) {
    const from = new Date(year, month - 1, 1);
    const to = new Date(year, month, 1);

    const bookStats = await getBookStatsInRange(userId, from, to);
    const hours = await getReadingHours(userId, from, to);

    byPeriod.push({
      label: MONTH_NAMES_SHORT[month - 1],
      month,
      booksFinished: bookStats.booksFinished,
      avgRating: bookStats.avgRating,
      readingHours: hours,
      likedCount: bookStats.likedCount,
    });
  }

  const topGenres = await getTopGenresInRange(
    userId,
    new Date(year, 0, 1),
    new Date(year + 1, 0, 1)
  );

  const finishedBooks = await getFinishedBooksInRange(
    userId,
    new Date(year, 0, 1),
    new Date(year + 1, 0, 1)
  );

  return {
    period: 'year',
    year,
    yearLabel: `${year}`,
    byPeriod,
    finishedBooks,
    topGenres,
  };
}

// Список прочитанных книг (id + название + автор) за указанный промежуток,
// отсортирован от самой недавно завершённой к самой ранней.
async function getFinishedBooksInRange(userId, from, to) {
  const result = await pool.query(
    `SELECT id, title, author
     FROM books
     WHERE user_id = $1 AND status = 'finished'
       AND finished_at >= $2 AND finished_at < $3
     ORDER BY finished_at DESC`,
    [userId, from, to]
  );

  return result.rows.map((row) => ({
    id: row.id,
    title: row.title,
    author: row.author,
  }));
}

// Топ жанров за указанный промежуток
async function getTopGenresInRange(userId, from, to) {
  const result = await pool.query(
    `SELECT genre, COUNT(*) AS count
     FROM books
     WHERE user_id = $1 AND status = 'finished' AND genre IS NOT NULL
       AND finished_at >= $2 AND finished_at < $3
     GROUP BY genre
     ORDER BY count DESC
     LIMIT 5`,
    [userId, from, to]
  );

  return result.rows.map((row) => ({
    genre: row.genre,
    count: parseInt(row.count, 10),
  }));
}

// Сводная статистика "за всё время" — для главного экрана статистики.
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
