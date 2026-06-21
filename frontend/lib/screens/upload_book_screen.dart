import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/book_service.dart';

// Экран добавления новой книги: выбор файла PDF/EPUB, заполнение метаданных
// и опциональный выбор своей обложки. Если обложка не выбрана и файл EPUB —
// backend попробует извлечь обложку из самого файла автоматически.
class UploadBookScreen extends StatefulWidget {
  const UploadBookScreen({super.key});

  @override
  State<UploadBookScreen> createState() => _UploadBookScreenState();
}

class _UploadBookScreenState extends State<UploadBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _genreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _bookService = BookService();

  String? _filePath;
  String? _fileName;
  String? _coverPath;
  bool _isUploading = false;
  String? _errorMessage;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
        if (_titleController.text.isEmpty) {
          _titleController.text = _fileName!.replaceAll(RegExp(r'\.(pdf|epub)$', caseSensitive: false), '');
        }
      });
    }
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() => _coverPath = pickedFile.path);
    }
  }

  Future<void> _handleUpload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_filePath == null) {
      setState(() => _errorMessage = 'Выберите файл книги (PDF или EPUB)');
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      await _bookService.uploadBook(
        title: _titleController.text.trim(),
        author: _authorController.text.trim().isEmpty ? null : _authorController.text.trim(),
        genre: _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        filePath: _filePath!,
        coverPath: _coverPath,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() => _errorMessage = message);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить книгу')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text(_fileName ?? 'Выбрать файл (PDF или EPUB)'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
              const SizedBox(height: 20),
              _buildCoverPicker(),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Название книги *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Введите название' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(
                  labelText: 'Автор',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _genreController,
                decoration: const InputDecoration(
                  labelText: 'Жанр',
                  border: OutlineInputBorder(),
                  hintText: 'Например: Фантастика, Роман, Нон-фикшн',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Описание книги',
                  border: OutlineInputBorder(),
                  hintText: 'О чём эта книга, краткая аннотация...',
                  alignLabelWithHint: true,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isUploading ? null : _handleUpload,
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Добавить в библиотеку'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Превью выбранной обложки + кнопка выбора/смены.
  // Если обложка не выбрана — поясняем, что для EPUB она попробует извлечься сама.
  Widget _buildCoverPicker() {
    return Row(
      children: [
        GestureDetector(
          onTap: _pickCover,
          child: Container(
            width: 80,
            height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
              image: _coverPath != null
                  ? DecorationImage(image: FileImage(File(_coverPath!)), fit: BoxFit.cover)
                  : null,
            ),
            child: _coverPath == null
                ? Icon(Icons.add_photo_alternate_outlined,
                    color: Theme.of(context).colorScheme.primary)
                : null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _coverPath != null ? 'Обложка выбрана' : 'Обложка (опционально)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _coverPath != null
                    ? 'Нажмите, чтобы выбрать другую'
                    : 'Для EPUB обложка попробует извлечься из файла автоматически',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              if (_coverPath != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => setState(() => _coverPath = null),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text('Убрать'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _genreController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
