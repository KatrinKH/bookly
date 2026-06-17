const express = require('express');
const router = express.Router();
const notesController = require('../controllers/notesController');
const authMiddleware = require('../middleware/auth');

router.use(authMiddleware);

router.post('/', notesController.createNote);
router.get('/book/:bookId', notesController.getNotesByBook);
router.patch('/:id', notesController.updateNote);
router.delete('/:id', notesController.deleteNote);

module.exports = router;
