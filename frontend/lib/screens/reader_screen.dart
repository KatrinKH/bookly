import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:epub_view/epub_view.dart';
import '../models/book.dart';
import '../services/book_service.dart';

// Экран чтения книги.
// EPUB: простая вертикальная прокрутка через epub_view,
//        файл кэшируется локально при первом открытии.
// PDF: вертикальный скролл через SfPdfViewer, страница сохраняется на backend.
// При входе открывает сессию чтения, при выходе закрывает — для статистики часов.
class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final BookService _bookService = BookService();

  // PDF
  late PdfViewerController? _pdfController;
  String? _fileUrl;

  // EPUB
  EpubController? _epubController;

  // Состояние
  bool _isLoading = true;
  bool _isDownloading = false;
  int? _sessionId;

  @override
  void initState() {
    super.initState();
    _pdfController = widget.book.fileFormat == 'pdf' ? PdfViewerController() : null;
    _loadFile();
    _startSession();
  }

  // Открываем сессию чтения при входе в читалку
  Future<void> _startSession() async {
    try {
      final sessionId = await _bookService.startReadingSession(widget.book.id);
      _sessionId = sessionId;
    } catch (_) {
      // Не критично: чтение продолжается, просто время не попадёт в статистику
    }
  }

  Future<void> _loadFile() async {
    if (widget.book.fileFormat == 'epub') {
      await _loadEpub();
    } else {
      final url = await _bookService.getBookFileUrl(widget.book.id);
      setState(() {
        _fileUrl = url;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEpub() async {
    final tempDir = await getTemporaryDirectory();
    final localPath = '${tempDir.path}/book_${widget.book.id}.epub';
    final isCached = File(localPath).existsSync();

    if (!isCached && mounted) {
      setState(() => _isDownloading = true);
    }

    if (!isCached) {
      final downloadUrl = _bookService.getBookFileDownloadUrl(widget.book.id);
      final token = await _bookService.getToken();

      await Dio().download(
        downloadUrl,
        localPath,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    }

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _epubController = EpubController(
          document: EpubDocument.openFile(File(localPath)),
        );
        _isLoading = false;
      });
    }
  }

  // Сохраняет текущую страницу PDF на backend
  Future<void> _savePdfProgress(int currentPage, {int? totalPages}) async {
    try {
      await _bookService.updateProgress(
        bookId: widget.book.id,
        currentPage: currentPage,
        totalPages: totalPages,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.book.title)),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _isDownloading ? 'Скачивание книги...' : 'Открытие...',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  if (_isDownloading) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Это займёт немного времени\nпри первом открытии',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ],
                ],
              ),
            )
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
        _savePdfProgress(
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
        // Сохраняем номер главы как прогресс чтения
        if (value?.chapterNumber != null) {
          _bookService.updateProgress(
            bookId: widget.book.id,
            currentPage: value!.chapterNumber!,
          ).catchError((_) {});
        }
      },
    );
  }

  @override
  void dispose() {
    // Закрываем сессию чтения — время попадёт в статистику
    if (_sessionId != null) {
      _bookService.endReadingSession(widget.book.id, _sessionId!).catchError((_) {});
    }
    _epubController?.dispose();
    super.dispose();
  }
}
