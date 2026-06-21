-- Схема базы данных проекта Bookly
-- Запускается один раз при первоначальной настройке проекта (см. migrate.js)

-- Пользователи
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Книги, загруженные пользователем
CREATE TABLE IF NOT EXISTS books (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(500) NOT NULL,
    author VARCHAR(255),
    description TEXT,
    file_path VARCHAR(500) NOT NULL,
    file_format VARCHAR(10) NOT NULL CHECK (file_format IN ('pdf', 'epub')),
    cover_path VARCHAR(500),
    genre VARCHAR(100),
    total_pages INTEGER,
    current_page INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'not_started' CHECK (status IN ('not_started', 'reading', 'finished', 'abandoned')),
    started_at TIMESTAMP,
    finished_at TIMESTAMP,
    rating SMALLINT CHECK (rating BETWEEN 1 AND 5),
    liked BOOLEAN,
    review TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Безопасное добавление полей для баз, созданных до появления этих колонок
ALTER TABLE books ADD COLUMN IF NOT EXISTS review TEXT;
ALTER TABLE books ADD COLUMN IF NOT EXISTS description TEXT;

-- Заметки, привязанные к конкретной книге и месту в ней
CREATE TABLE IF NOT EXISTS notes (
    id SERIAL PRIMARY KEY,
    book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    page_number INTEGER,
    content TEXT NOT NULL,
    highlighted_text TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Сессии чтения — используются для подсчёта статистики (сколько времени/страниц прочитано и когда)
CREATE TABLE IF NOT EXISTS reading_sessions (
    id SERIAL PRIMARY KEY,
    book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    started_at TIMESTAMP NOT NULL,
    ended_at TIMESTAMP,
    pages_read INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Индексы для ускорения частых запросов
CREATE INDEX IF NOT EXISTS idx_books_user_id ON books(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_book_id ON notes(book_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON reading_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON reading_sessions(started_at);
