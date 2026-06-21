const express = require('express');
const router = express.Router();
const shelvesController = require('../controllers/shelvesController');
const authMiddleware = require('../middleware/auth');

router.use(authMiddleware);

router.post('/', shelvesController.createShelf);
router.get('/', shelvesController.getShelves); // ?sort=newest|oldest|recently_updated
router.patch('/:id', shelvesController.updateShelf);
router.delete('/:id', shelvesController.deleteShelf);

router.get('/:id/books', shelvesController.getShelfBooks);
router.post('/:id/books', shelvesController.addBookToShelf);
router.delete('/:id/books/:bookId', shelvesController.removeBookFromShelf);

module.exports = router;
