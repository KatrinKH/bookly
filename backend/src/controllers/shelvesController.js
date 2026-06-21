const pool = require('../config/db');

// Создание новой полки
async function createShelf(req, res) {
  const { name } = req.body;

  if (!name || name.trim() === '') {
    return res.status(400).json({ error: 'Название полки обязательно' });
  }

  try {
    const result = await pool.query(
      `INSERT INTO shelves (user_id, name) VALUES ($1, $2) RETURNING *`,
      [req.userId, name.trim()]
    );

    res.status(201).json(formatShelf(result.rows[0], 0));
  } catch (err) {
    console.error('Ошибка создания полки:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Получение списка полок пользователя с сортировкой и количеством книг на каждой.
// sort: 'newest' (по умолчанию, новые сначала) | 'oldest' (старые сначала)
//       | 'recently_updated' (полка с последним добавлением книги — первая)
async function getShelves(req, res) {
  const sort = req.query.sort || 'newest';

  if (!['newest', 'oldest', 'recently_updated'].includes(sort)) {
    return res.status(400).json({ error: 'Параметр sort должен быть newest, oldest или recently_updated' });
  }

  try {
    // last_added — момент добавления самой последней книги на полку (или null, если полка пустая)
    let query = `
      SELECT
        s.*,
        COUNT(bs.book_id) AS book_count,
        MAX(bs.added_at) AS last_added
      FROM shelves s
      LEFT JOIN book_shelves bs ON bs.shelf_id = s.id
      WHERE s.user_id = $1
      GROUP BY s.id
    `;

    if (sort === 'newest') {
      query += ' ORDER BY s.created_at DESC';
    } else if (sort === 'oldest') {
      query += ' ORDER BY s.created_at ASC';
    } else {
      // recently_updated: полки без книг (last_added IS NULL) идут в конец
      query += ' ORDER BY last_added DESC NULLS LAST';
    }

    const result = await pool.query(query, [req.userId]);

    res.json(result.rows.map((row) => formatShelf(row, parseInt(row.book_count, 10))));
  } catch (err) {
    console.error('Ошибка получения полок:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Переименование полки
async function updateShelf(req, res) {
  const { name } = req.body;

  if (!name || name.trim() === '') {
    return res.status(400).json({ error: 'Название полки обязательно' });
  }

  try {
    const result = await pool.query(
      `UPDATE shelves SET name = $1 WHERE id = $2 AND user_id = $3 RETURNING *`,
      [name.trim(), req.params.id, req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Полка не найдена' });
    }

    res.json(formatShelf(result.rows[0], null));
  } catch (err) {
    console.error('Ошибка переименования полки:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Удаление полки (связи в book_shelves удаляются автоматически через ON DELETE CASCADE)
async function deleteShelf(req, res) {
  try {
    const result = await pool.query(
      'DELETE FROM shelves WHERE id = $1 AND user_id = $2 RETURNING id',
      [req.params.id, req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Полка не найдена' });
    }

    res.json({ message: 'Полка удалена' });
  } catch (err) {
    console.error('Ошибка удаления полки:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Получение книг на конкретной полке
async function getShelfBooks(req, res) {
  try {
    const shelfCheck = await pool.query(
      'SELECT id FROM shelves WHERE id = $1 AND user_id = $2',
      [req.params.id, req.userId]
    );

    if (shelfCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Полка не найдена' });
    }

    const result = await pool.query(
      `SELECT b.*
       FROM books b
       JOIN book_shelves bs ON bs.book_id = b.id
       WHERE bs.shelf_id = $1
       ORDER BY bs.added_at DESC`,
      [req.params.id]
    );

    res.json(result.rows.map(formatBookForShelf));
  } catch (err) {
    console.error('Ошибка получения книг полки:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Добавление книги на полку
async function addBookToShelf(req, res) {
  const { bookId } = req.body;

  if (!bookId) {
    return res.status(400).json({ error: 'bookId обязателен' });
  }

  try {
    // Проверяем, что и полка, и книга принадлежат текущему пользователю
    const shelfCheck = await pool.query(
      'SELECT id FROM shelves WHERE id = $1 AND user_id = $2',
      [req.params.id, req.userId]
    );
    if (shelfCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Полка не найдена' });
    }

    const bookCheck = await pool.query(
      'SELECT id FROM books WHERE id = $1 AND user_id = $2',
      [bookId, req.userId]
    );
    if (bookCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Книга не найдена' });
    }

    await pool.query(
      `INSERT INTO book_shelves (book_id, shelf_id)
       VALUES ($1, $2)
       ON CONFLICT (book_id, shelf_id) DO UPDATE SET added_at = NOW()`,
      [bookId, req.params.id]
    );

    res.status(201).json({ message: 'Книга добавлена на полку' });
  } catch (err) {
    console.error('Ошибка добавления книги на полку:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Удаление книги с полки
async function removeBookFromShelf(req, res) {
  try {
    const result = await pool.query(
      `DELETE FROM book_shelves
       WHERE shelf_id = $1 AND book_id = $2
         AND shelf_id IN (SELECT id FROM shelves WHERE user_id = $3)
       RETURNING book_id`,
      [req.params.id, req.params.bookId, req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Книга на этой полке не найдена' });
    }

    res.json({ message: 'Книга удалена с полки' });
  } catch (err) {
    console.error('Ошибка удаления книги с полки:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

function formatShelf(row, bookCount) {
  return {
    id: row.id,
    name: row.name,
    bookCount: bookCount,
    createdAt: row.created_at,
  };
}

// Краткий формат книги для отображения на полке (совпадает с форматом из booksController)
function formatBookForShelf(row) {
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
    description: row.description,
    hasCover: !!row.cover_path,
    createdAt: row.created_at,
  };
}

module.exports = {
  createShelf,
  getShelves,
  updateShelf,
  deleteShelf,
  getShelfBooks,
  addBookToShelf,
  removeBookFromShelf,
};
