import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/book_service.dart';

// Экран добавления новой книги: выбор файла PDF/EPUB и заполнение метаданных
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
  final _bookService = BookService();

  String? _filePath;
  String? _fileName;
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
        // Если название не заполнено, подставляем имя файла без расширения
        if (_titleController.text.isEmpty) {
          _titleController.text = _fileName!.replaceAll(RegExp(r'\.(pdf|epub)$', caseSensitive: false), '');
        }
      });
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
        filePath: _filePath!,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _errorMessage = 'Ошибка загрузки: $e');
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

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _genreController.dispose();
    super.dispose();
  }
}
