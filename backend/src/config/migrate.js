const fs = require('fs');
const path = require('path');
const pool = require('./db');

// Скрипт читает schema.sql и выполняет его на подключённой базе данных.
// Запуск: npm run migrate

async function migrate() {
  const schemaPath = path.join(__dirname, 'schema.sql');
  const schema = fs.readFileSync(schemaPath, 'utf8');

  try {
    console.log('Применяю схему базы данных...');
    await pool.query(schema);
    console.log('Готово: таблицы созданы или уже существовали.');
  } catch (err) {
    console.error('Ошибка при применении схемы:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

migrate();
