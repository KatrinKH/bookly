const jwt = require('jsonwebtoken');
require('dotenv').config();

// Middleware проверяет JWT-токен — сначала в заголовке Authorization,
// затем в query-параметре ?token= (нужно для PDF-просмотрщика, который
// не умеет добавлять заголовки к сетевым запросам).
function authMiddleware(req, res, next) {
  let token = null;

  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.split(' ')[1];
  } else if (req.query.token) {
    token = req.query.token;
  }

  if (!token) {
    return res.status(401).json({ error: 'Требуется авторизация' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = decoded.userId;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Недействительный или просроченный токен' });
  }
}

module.exports = authMiddleware;
