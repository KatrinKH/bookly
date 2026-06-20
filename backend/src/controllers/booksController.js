const path = require('path');
const fs = require('fs');
const pool = require('../config/db');
const { extractEpubCover, saveCoverToFile } = require('../utils/epubCover');
const { coversDir } = require('../middleware/upload');

// Загрузка новой книги (PDF/EPUB) в библиотеку пользователя.
// Если пользователь не приложил свою обложку и файл в формате EPUB,
// обложка автоматически извлекается из самого файла книги.
// Перед сохранением проверяется, нет ли у пользователя уже такой же книги
// (совпадение названия и автора без учёта регистра и лишних пробелов).
async function uploadBook(req, res) {
  const { title, author, genre } = req.body;

  if (!req.files || !req.files.book) {
    return res.status(400).json({ error: 'Файл книги обязателен' });
  }

  if (!title) {
    return res.status(400).json({ error: 'Название книги обязательно' });
  }

  const bookFile = req.files.book[0];
  const coverFile = req.files.cover ? req.files.cover[0] : null;
  const fileFormat = path.extname(bookFile.originalname).toLowerCase().replace('.', '');

  // Проверяем дубликат до сохранения файла и извлечения обложки,
  // чтобы не тратить ресурсы и не оставлять файл-сироту при отказе.
  try {
    const duplicateCheck = await pool.query(
      `SELECT id FROM books
       WHERE user_id = $1
         AND LOWER(TRIM(title)) = LOWER(TRIM($2))
         AND LOWER(TRIM(COALESCE(author, ''))) = LOWER(TRIM(COALESCE($3, '')))`,
      [req.userId, title, author || null]
    );

    if (duplicateCheck.rows.length > 0) {
      // Загруженный файл уже сохранён middleware multer на диск до вызова контроллера —
      // удаляем его, раз книга не будет создана.
      if (fs.existsSync(bookFile.path)) fs.unlinkSync(bookFile.path);
      if (coverFile && fs.existsSync(coverFile.path)) fs.unlinkSync(coverFile.path);

      return res.status(409).json({
        error: author
          ? `Книга «${title}» автора ${author} уже есть в вашей библиотеке`
          : `Книга «${title}» уже есть в вашей библиотеке`,
      });
    }
  } catch (err) {
    console.error('Ошибка проверки дубликата книги:', err);
    return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }

  let coverPath = coverFile ? coverFile.path : null;

  // Если пользователь не загрузил свою обложку — пробуем извлечь из EPUB
  if (!coverPath && fileFormat === 'epub') {
    try {
      const extracted = await extractEpubCover(bookFile.path);
      if (extracted) {
        const baseName = path.basename(bookFile.filename, path.extname(bookFile.filename));
        coverPath = saveCoverToFile(extracted, coversDir, `${baseName}-cover`);
      }
    } catch (err) {
      console.error('Извлечение обложки не удалось, продолжаем без неё:', err.message);
    }
  }

  try {
    const result = await pool.query(
      `INSERT INTO books (user_id, title, author, file_path, file_format, cover_path, genre)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        req.userId,
        title,
        author || null,
        bookFile.path,
        fileFormat,
        coverPath,
        genre || null,
      ]
    );

    res.status(201).json(formatBook(result.rows[0]));
  } catch (err) {
    console.error('Ошибка загрузки книги:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Замена обложки книги — пользователь загружает новое изображение
async function updateCover(req, res) {
  if (!req.file) {
    return res.status(400).json({ error: 'Файл обложки обязателен' });
  }

  try {
    const bookResult = await pool.query(
      'SELECT cover_path FROM books WHERE id = $1 AND user_id = $2',
      [req.params.id, req.userId]
    );

    if (bookResult.rows.length === 0) {
      return res.status(404).json({ error: 'Книга не найдена' });
    }

    const oldCoverPath = bookResult.rows[0].cover_path;

    const result = await pool.query(
      'UPDATE books SET cover_path = $1 WHERE id = $2 RETURNING *',
      [req.file.path, req.params.id]
    );

    // Удаляем старую обложку, если она была
    if (oldCoverPath && fs.existsSync(oldCoverPath)) {
      fs.unlinkSync(oldCoverPath);
    }

    res.json(formatBook(result.rows[0]));
  } catch (err) {
    console.error('Ошибка замены обложки:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Отдаёт файл обложки книги
async function downloadCover(req, res) {
  try {
    const result = await pool.query(
      'SELECT cover_path FROM books WHERE id = $1 AND user_id = $2',
      [req.params.id, req.userId]
    );

    if (result.rows.length === 0 || !result.rows[0].cover_path) {
      return res.status(404).json({ error: 'Обложка не найдена' });
    }

    const coverPath = result.rows[0].cover_path;
    if (!fs.existsSync(coverPath)) {
      return res.status(404).json({ error: 'Файл обложки отсутствует на сервере' });
    }

    res.sendFile(path.resolve(coverPath));
  } catch (err) {
    console.error('Ошибка отдачи обложки:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Получение списка всех книг пользователя (с возможностью фильтра по статусу)
async function getBooks(req, res) {
  const { status } = req.query;

  try {
    let query = 'SELECT * FROM books WHERE user_id = $1';
    const params = [req.userId];

    if (status) {
      query += ' AND status = $2';
      params.push(status);
    }

    query += ' ORDER BY created_at DESC';

    const result = await pool.query(query, params);
    res.json(result.rows.map(formatBook));
  } catch (err) {
    console.error('Ошибка получения списка книг:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Получение одной книги по id
async function getBookById(req, res) {
  try {
    const result = await pool.query(
      'SELECT * FROM books WHERE id = $1 AND user_id = $2',
      [req.params.id, req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Книга не найдена' });
    }

    res.json(formatBook(result.rows[0]));
  } catch (err) {
    console.error('Ошибка получения книги:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Изменение метаданных книги — название, автор, жанр.
// Поле не передано вовсе -> остаётся как было.
// Поле передано пустой строкой -> очищается (только для author/genre; title обязателен).
// Поле передано с текстом -> обновляется.
async function updateMetadata(req, res) {
  const { title, author, genre } = req.body;

  if (title !== undefined && title.trim() === '') {
    return res.status(400).json({ error: 'Название книги не может быть пустым' });
  }

  try {
    // Если меняется название или автор — нужно проверить, не получится ли
    // в итоге дубликат другой книги пользователя. Для этого берём текущие
    // значения книги и подставляем то, что реально меняется.
    if (title !== undefined || author !== undefined) {
      const currentResult = await pool.query(
        'SELECT title, author FROM books WHERE id = $1 AND user_id = $2',
        [req.params.id, req.userId]
      );

      if (currentResult.rows.length === 0) {
        return res.status(404).json({ error: 'Книга не найдена' });
      }

      const finalTitle = title !== undefined ? title.trim() : currentResult.rows[0].title;
      const finalAuthor = author !== undefined
        ? (author.trim() === '' ? null : author.trim())
        : currentResult.rows[0].author;

      const duplicateCheck = await pool.query(
        `SELECT id FROM books
         WHERE user_id = $1
           AND id != $2
           AND LOWER(TRIM(title)) = LOWER(TRIM($3))
           AND LOWER(TRIM(COALESCE(author, ''))) = LOWER(TRIM(COALESCE($4, '')))`,
        [req.userId, req.params.id, finalTitle, finalAuthor]
      );

      if (duplicateCheck.rows.length > 0) {
        return res.status(409).json({
          error: finalAuthor
            ? `Книга «${finalTitle}» автора ${finalAuthor} уже есть в вашей библиотеке`
            : `Книга «${finalTitle}» уже есть в вашей библиотеке`,
        });
      }
    }

    const fields = [];
    const values = [];
    let paramIndex = 1;

    if (title !== undefined) {
      fields.push(`title = $${paramIndex++}`);
      values.push(title.trim());
    }
    if (author !== undefined) {
      fields.push(`author = $${paramIndex++}`);
      values.push(author.trim() === '' ? null : author.trim());
    }
    if (genre !== undefined) {
      fields.push(`genre = $${paramIndex++}`);
      values.push(genre.trim() === '' ? null : genre.trim());
    }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'Нет данных для обновления' });
    }

    values.push(req.params.id, req.userId);

    const result = await pool.query(
      `UPDATE books SET ${fields.join(', ')}
       WHERE id = $${paramIndex++} AND user_id = $${paramIndex}
       RETURNING *`,
      values
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Книга не найдена' });
    }

    res.json(formatBook(result.rows[0]));
  } catch (err) {
    console.error('Ошибка изменения метаданных книги:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Скачивание/потоковая отдача файла книги (для открытия в читалке)
async function downloadBookFile(req, res) {
  try {
    const result = await pool.query(
      'SELECT file_path, file_format, title FROM books WHERE id = $1 AND user_id = $2',
      [req.params.id, req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Книга не найдена' });
    }

    const { file_path } = result.rows[0];

    if (!fs.existsSync(file_path)) {
      return res.status(404).json({ error: 'Файл книги отсутствует на сервере' });
    }

    res.sendFile(path.resolve(file_path));
  } catch (err) {
    console.error('Ошибка отдачи файла книги:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Обновление прогресса чтения. При первом открытии книги фиксируется started_at.
async function updateProgress(req, res) {
  const { currentPage, totalPages } = req.body;

  try {
    const bookResult = await pool.query(
      'SELECT * FROM books WHERE id = $1 AND user_id = $2',
      [req.params.id, req.userId]
    );

    if (bookResult.rows.length === 0) {
      return res.status(404).json({ error: 'Книга не найдена' });
    }

    const updateResult = await pool.query(
      `UPDATE books
       SET current_page = $1,
           total_pages = COALESCE($2, total_pages),
           status = CASE WHEN status = 'not_started' THEN 'reading' ELSE status END,
           started_at = CASE WHEN started_at IS NULL THEN NOW() ELSE started_at END
       WHERE id = $3
       RETURNING *`,
      [currentPage, totalPages || null, req.params.id]
    );

    res.json(formatBook(updateResult.rows[0]));
  } catch (err) {
    console.error('Ошибка обновления прогресса:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Открытие сессии чтения — вызывается когда пользователь открывает читалку.
// Возвращает id созданной сессии, который Flutter сохраняет и передаёт при закрытии.
async function startReadingSession(req, res) {
  try {
    const result = await pool.query(
      `INSERT INTO reading_sessions (book_id, user_id, started_at)
       VALUES ($1, $2, NOW())
       RETURNING id`,
      [req.params.id, req.userId]
    );

    res.json({ sessionId: result.rows[0].id });
  } catch (err) {
    console.error('Ошибка открытия сессии чтения:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Закрытие сессии чтения — вызывается когда пользователь выходит из читалки.
// Проставляет ended_at, после чего разница (ended_at - started_at) используется
// для подсчёта общего времени чтения в статистике.
async function endReadingSession(req, res) {
  const { sessionId } = req.body;

  if (!sessionId) {
    return res.status(400).json({ error: 'sessionId обязателен' });
  }

  try {
    await pool.query(
      `UPDATE reading_sessions
       SET ended_at = NOW()
       WHERE id = $1 AND user_id = $2 AND ended_at IS NULL`,
      [sessionId, req.userId]
    );

    res.json({ message: 'Сессия закрыта' });
  } catch (err) {
    console.error('Ошибка закрытия сессии чтения:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Отметка книги прочитанной + оценка + лайк + отзыв.
// finished_at проставляется только при первом переводе в статус 'finished' —
// повторный вызов (редактирование отзыва) не должен сдвигать дату завершения.
async function finishBook(req, res) {
  const { rating, liked, review } = req.body;

  try {
    const result = await pool.query(
      `UPDATE books
       SET status = 'finished',
           finished_at = COALESCE(finished_at, NOW()),
           rating = $1,
           liked = $2,
           review = $3
       WHERE id = $4 AND user_id = $5
       RETURNING *`,
      [
        rating || null,
        liked !== undefined ? liked : null,
        review !== undefined ? (review.trim() === '' ? null : review.trim()) : null,
        req.params.id,
        req.userId,
      ]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Книга не найдена' });
    }

    res.json(formatBook(result.rows[0]));
  } catch (err) {
    console.error('Ошибка завершения книги:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Обновление оценки/лайка/отзыва уже прочитанной книги без изменения её статуса.
// Используется когда пользователь редактирует свой отзыв после прочтения.
async function updateReview(req, res) {
  const { rating, liked, review } = req.body;

  try {
    const fields = [];
    const values = [];
    let paramIndex = 1;

    if (rating !== undefined) {
      fields.push(`rating = $${paramIndex++}`);
      values.push(rating);
    }
    if (liked !== undefined) {
      fields.push(`liked = $${paramIndex++}`);
      values.push(liked);
    }
    if (review !== undefined) {
      fields.push(`review = $${paramIndex++}`);
      values.push(review.trim() === '' ? null : review.trim());
    }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'Нет данных для обновления' });
    }

    values.push(req.params.id, req.userId);

    const result = await pool.query(
      `UPDATE books SET ${fields.join(', ')}
       WHERE id = $${paramIndex++} AND user_id = $${paramIndex} AND status = 'finished'
       RETURNING *`,
      values
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Книга не найдена или ещё не прочитана' });
    }

    res.json(formatBook(result.rows[0]));
  } catch (err) {
    console.error('Ошибка обновления отзыва:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Удаление книги (и связанного файла)
async function deleteBook(req, res) {
  try {
    const result = await pool.query(
      'DELETE FROM books WHERE id = $1 AND user_id = $2 RETURNING file_path, cover_path',
      [req.params.id, req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Книга не найдена' });
    }

    const { file_path, cover_path } = result.rows[0];
    [file_path, cover_path].forEach((filePath) => {
      if (filePath && fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    });

    res.json({ message: 'Книга удалена' });
  } catch (err) {
    console.error('Ошибка удаления книги:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Преобразует строку из БД в удобный для фронтенда формат (camelCase)
function formatBook(row) {
  return {
    id: row.id,
    title: row.title,
    author: row.author,
    fileFormat: row.file_format,
    genre: row.genre,
    totalPages: row.total_pages,
    currentPage: row.current_page,
    status: row.status,
    startedAt: row.started_at,
    finishedAt: row.finished_at,
    rating: row.rating,
    liked: row.liked,
    review: row.review,
    hasCover: !!row.cover_path,
    createdAt: row.created_at,
  };
}

module.exports = {
  uploadBook,
  updateCover,
  downloadCover,
  updateMetadata,
  getBooks,
  getBookById,
  downloadBookFile,
  updateProgress,
  startReadingSession,
  endReadingSession,
  finishBook,
  updateReview,
  deleteBook,
};
