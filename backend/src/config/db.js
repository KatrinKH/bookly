const { Pool } = require('pg');
require('dotenv').config();

// Пул соединений с PostgreSQL.
// Все запросы к базе данных в проекте идут через этот пул.
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'bookly',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
});

pool.on('error', (err) => {
  console.error('Неожиданная ошибка пула подключений к БД:', err);
});

module.exports = pool;
