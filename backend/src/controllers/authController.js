const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
require('dotenv').config();

const SALT_ROUNDS = 10;

// Регистрация нового пользователя
async function register(req, res) {
  const { email, password, displayName } = req.body;

  if (!email || !password || !displayName) {
    return res.status(400).json({ error: 'Заполните email, пароль и имя' });
  }

  if (password.length < 6) {
    return res.status(400).json({ error: 'Пароль должен содержать минимум 6 символов' });
  }

  try {
    const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Пользователь с таким email уже зарегистрирован' });
    }

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    const result = await pool.query(
      'INSERT INTO users (email, password_hash, display_name) VALUES ($1, $2, $3) RETURNING id, email, display_name, created_at',
      [email, passwordHash, displayName]
    );

    const user = result.rows[0];
    const token = generateToken(user.id);

    res.status(201).json({
      token,
      user: { id: user.id, email: user.email, displayName: user.display_name },
    });
  } catch (err) {
    console.error('Ошибка регистрации:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Авторизация существующего пользователя
async function login(req, res) {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Заполните email и пароль' });
  }

  try {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    const user = result.rows[0];

    if (!user) {
      return res.status(401).json({ error: 'Неверный email или пароль' });
    }

    const passwordMatches = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatches) {
      return res.status(401).json({ error: 'Неверный email или пароль' });
    }

    const token = generateToken(user.id);

    res.json({
      token,
      user: { id: user.id, email: user.email, displayName: user.display_name },
    });
  } catch (err) {
    console.error('Ошибка входа:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Получение профиля текущего авторизованного пользователя
async function getProfile(req, res) {
  try {
    const result = await pool.query(
      'SELECT id, email, display_name, created_at FROM users WHERE id = $1',
      [req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Пользователь не найден' });
    }

    const user = result.rows[0];
    res.json({
      id: user.id,
      email: user.email,
      displayName: user.display_name,
      createdAt: user.created_at,
    });
  } catch (err) {
    console.error('Ошибка получения профиля:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

// Изменение имени и/или email пользователя.
// Поле не передано вовсе -> остаётся как было.
// При смене email проверяется, что новый адрес не занят другим пользователем.
async function updateProfile(req, res) {
  const { displayName, email } = req.body;

  if (displayName !== undefined && displayName.trim() === '') {
    return res.status(400).json({ error: 'Имя не может быть пустым' });
  }

  if (email !== undefined && email.trim() === '') {
    return res.status(400).json({ error: 'Email не может быть пустым' });
  }

  try {
    if (email !== undefined) {
      const existing = await pool.query(
        'SELECT id FROM users WHERE email = $1 AND id != $2',
        [email.trim(), req.userId]
      );
      if (existing.rows.length > 0) {
        return res.status(409).json({ error: 'Этот email уже используется другим аккаунтом' });
      }
    }

    const fields = [];
    const values = [];
    let paramIndex = 1;

    if (displayName !== undefined) {
      fields.push(`display_name = $${paramIndex++}`);
      values.push(displayName.trim());
    }
    if (email !== undefined) {
      fields.push(`email = $${paramIndex++}`);
      values.push(email.trim());
    }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'Нет данных для обновления' });
    }

    values.push(req.userId);

    const result = await pool.query(
      `UPDATE users SET ${fields.join(', ')}
       WHERE id = $${paramIndex}
       RETURNING id, email, display_name, created_at`,
      values
    );

    const user = result.rows[0];
    res.json({
      id: user.id,
      email: user.email,
      displayName: user.display_name,
      createdAt: user.created_at,
    });
  } catch (err) {
    console.error('Ошибка обновления профиля:', err);
    res.status(500).json({ error: 'Внутренняя ошибка сервера' });
  }
}

function generateToken(userId) {
  return jwt.sign({ userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });
}

module.exports = { register, login, getProfile, updateProfile };
