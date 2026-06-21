const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/authRoutes');
const booksRoutes = require('./routes/booksRoutes');
const notesRoutes = require('./routes/notesRoutes');
const statsRoutes = require('./routes/statsRoutes');
const shelvesRoutes = require('./routes/shelvesRoutes');

const app = express();

app.use(cors());
app.use(express.json());

// Проверка работоспособности сервера
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Bookly API работает' });
});

app.use('/api/auth', authRoutes);
app.use('/api/books', booksRoutes);
app.use('/api/notes', notesRoutes);
app.use('/api/stats', statsRoutes);
app.use('/api/shelves', shelvesRoutes);

// Обработчик ошибок Multer и прочих ошибок загрузки файлов
app.use((err, req, res, next) => {
  if (err) {
    console.error('Ошибка обработки запроса:', err.message);
    return res.status(400).json({ error: err.message });
  }
  next();
});

// Обработчик несуществующих маршрутов
app.use((req, res) => {
  res.status(404).json({ error: 'Маршрут не найден' });
});

module.exports = app;
