const express = require('express');
const router = express.Router();
const booksController = require('../controllers/booksController');
const authMiddleware = require('../middleware/auth');
const { upload } = require('../middleware/upload');

router.use(authMiddleware);

router.post(
  '/',
  upload.fields([{ name: 'book', maxCount: 1 }, { name: 'cover', maxCount: 1 }]),
  booksController.uploadBook
);
router.get('/', booksController.getBooks);
router.get('/:id', booksController.getBookById);
router.patch('/:id', booksController.updateMetadata);
router.get('/:id/file', booksController.downloadBookFile);
router.get('/:id/cover', booksController.downloadCover);
router.patch(
  '/:id/cover',
  upload.single('cover'),
  booksController.updateCover
);
router.patch('/:id/progress', booksController.updateProgress);
router.post('/:id/session/start', booksController.startReadingSession);
router.patch('/:id/session/end', booksController.endReadingSession);
router.patch('/:id/finish', booksController.finishBook);
router.delete('/:id', booksController.deleteBook);

module.exports = router;
