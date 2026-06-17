const pool = require('../config/db');

// Создание заметки в книге (с привязкой к странице и, опционально, к выделенному тексту)
async function createNote(req, res) {
  const { bookId, pageNumber, content, highlightedText } = req.body;

  if (!bookId || !content) {
    return res.status(400).json({ error: 'Поля bookId и content обязательны' });
  }

  try {
    // Проверяем, что книга принадлежит пользователю
    const book = await pool.query('SELECT id FROM books WHERE id = $1 AND user_id = $2', [
      bookId,
      req.userId,
    ]);

    if (book.rows.length === 0) {
      return res.status(404).json({ error: 'Книга не найдена' });
    }

    const result = await pool.query(
      `INSERT INTO notes (book_id, user_id, page_number, content, highlighted_text)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [bookId, req.userId, pageNumber || null, content, highlightedText || null]
    );

    res.status(201).json(formatNote(result.rows[0]));
  } catch (err) {
    console.error('Ошибка создания заметки:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Получение всех заметок для конкретной книги
async function getNotesByBook(req, res) {
  try {
    const result = await pool.query(
      'SELECT * FROM notes WHERE book_id = $1 AND user_id = $2 ORDER BY page_number ASC NULLS LAST, created_at ASC',
      [req.params.bookId, req.userId]
    );

    res.json(result.rows.map(formatNote));
  } catch (err) {
    console.error('Ошибка получения заметок:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Обновление текста заметки
async function updateNote(req, res) {
  const { content } = req.body;

  if (!content) {
    return res.status(400).json({ error: 'Поле content обязательно' });
  }

  try {
    const result = await pool.query(
      'UPDATE notes SET content = $1 WHERE id = $2 AND user_id = $3 RETURNING *',
      [content, req.params.id, req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Заметка не найдена' });
    }

    res.json(formatNote(result.rows[0]));
  } catch (err) {
    console.error('Ошибка обновления заметки:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Удаление заметки
async function deleteNote(req, res) {
  try {
    const result = await pool.query(
      'DELETE FROM notes WHERE id = $1 AND user_id = $2 RETURNING id',
      [req.params.id, req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Заметка не найдена' });
    }

    res.json({ message: 'Заметка удалена' });
  } catch (err) {
    console.error('Ошибка удаления заметки:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

function formatNote(row) {
  return {
    id: row.id,
    bookId: row.book_id,
    pageNumber: row.page_number,
    content: row.content,
    highlightedText: row.highlighted_text,
    createdAt: row.created_at,
  };
}

module.exports = { createNote, getNotesByBook, updateNote, deleteNote };
