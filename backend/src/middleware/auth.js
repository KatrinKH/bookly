const jwt = require('jsonwebtoken');
require('dotenv').config();

// Middleware проверяет наличие и валидность JWT-токена в заголовке Authorization.
// При успехе добавляет req.userId, доступный во всех последующих обработчиках маршрута.
function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Требуется авторизация' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = decoded.userId;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Недействительный или просроченный токен' });
  }
}

module.exports = authMiddleware;
