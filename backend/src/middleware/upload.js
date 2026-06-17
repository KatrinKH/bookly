const multer = require('multer');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

const uploadDir = process.env.UPLOAD_DIR || 'uploads';
const booksDir = path.join(uploadDir, 'books');
const coversDir = path.join(uploadDir, 'covers');

// Создаём папки для хранения файлов, если их ещё нет
[uploadDir, booksDir, coversDir].forEach((dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    if (file.fieldname === 'cover') {
      cb(null, coversDir);
    } else {
      cb(null, booksDir);
    }
  },
  filename: (req, file, cb) => {
    const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1e9)}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  },
});

function fileFilter(req, file, cb) {
  if (file.fieldname === 'cover') {
    // Обложка должна быть изображением
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Файл обложки должен быть изображением'));
    }
    return;
  }

  // Книга должна быть PDF или EPUB
  const allowedExt = ['.pdf', '.epub'];
  const ext = path.extname(file.originalname).toLowerCase();
  if (allowedExt.includes(ext)) {
    cb(null, true);
  } else {
    cb(new Error('Поддерживаются только файлы PDF и EPUB'));
  }
}

const maxSizeMb = parseInt(process.env.MAX_FILE_SIZE_MB || '100', 10);

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: maxSizeMb * 1024 * 1024 },
});

module.exports = { upload, booksDir, coversDir };
