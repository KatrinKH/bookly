import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:epub_view/epub_view.dart';
import '../models/book.dart';
import '../services/book_service.dart';

// Экран чтения книги. В зависимости от формата (pdf/epub) показывает
// соответствующий просмотрщик и автоматически сохраняет прогресс чтения
// на backend, откуда дата начала/конца чтения попадает в статистику.
class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final BookService _bookService = BookService();
  late PdfViewerController? _pdfController;
  EpubController? _epubController;
  String? _fileUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pdfController = widget.book.fileFormat == 'pdf' ? PdfViewerController() : null;
    _loadFileUrl();
  }

  Future<void> _loadFileUrl() async {
    final url = await _bookService.getBookFileUrl(widget.book.id);

    if (widget.book.fileFormat == 'epub') {
      // epub_view не умеет открывать файлы напрямую по сетевому URL,
      // поэтому сначала скачиваем EPUB во временную папку устройства,
      // а затем открываем уже локальный файл.
      final localPath = await _downloadEpubToTempFile(url);
      _epubController = EpubController(
        document: EpubDocument.openFile(File(localPath)),
      );
    }

    setState(() {
      _fileUrl = url;
      _isLoading = false;
    });
  }

  Future<String> _downloadEpubToTempFile(String url) async {
    final tempDir = await getTemporaryDirectory();
    final localPath = '${tempDir.path}/book_${widget.book.id}.epub';

    await Dio().download(url, localPath);

    return localPath;
  }

  // Сохраняет текущую страницу на backend.
  // Вызывается при смене страницы (PDF) и при выходе с экрана.
  Future<void> _saveProgress(int currentPage, {int? totalPages}) async {
    try {
      await _bookService.updateProgress(
        bookId: widget.book.id,
        currentPage: currentPage,
        totalPages: totalPages,
      );
    } catch (_) {
      // Намеренно игнорируем ошибку сохранения прогресса, чтобы не мешать чтению
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.book.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : widget.book.fileFormat == 'pdf'
              ? _buildPdfViewer()
              : _buildEpubViewer(),
    );
  }

  Widget _buildPdfViewer() {
    return SfPdfViewer.network(
      _fileUrl!,
      controller: _pdfController,
      onPageChanged: (details) {
        _saveProgress(
          details.newPageNumber,
          totalPages: _pdfController?.pageCount,
        );
      },
      initialPageNumber: widget.book.currentPage > 0 ? widget.book.currentPage : 1,
    );
  }

  Widget _buildEpubViewer() {
    return EpubView(
      controller: _epubController!,
      onChapterChanged: (value) {
        // Для EPUB фиксируем номер главы как условную "страницу" прогресса,
        // так как реальная пагинация в EPUB зависит от размера экрана
        if (value?.chapterNumber != null) {
          _saveProgress(value!.chapterNumber!);
        }
      },
    );
  }

  @override
  void dispose() {
    _epubController?.dispose();
    super.dispose();
  }
}
