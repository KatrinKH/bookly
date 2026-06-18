import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:epub_view/epub_view.dart';
import '../models/book.dart';
import '../services/book_service.dart';

// Экран чтения книги. В зависимости от формата (pdf/epub) показывает
// соответствующий просмотрщик и автоматически сохраняет прогресс чтения.
// При входе открывает сессию чтения, при выходе закрывает — это позволяет
// считать реальное время чтения для статистики.
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
  bool _isDownloading = false;
  int? _sessionId; // id открытой сессии чтения для закрытия при выходе

  @override
  void initState() {
    super.initState();
    _pdfController = widget.book.fileFormat == 'pdf' ? PdfViewerController() : null;
    _loadFileUrl();
    _startSession();
  }

  // Открываем сессию чтения при входе в читалку
  Future<void> _startSession() async {
    try {
      final sessionId = await _bookService.startReadingSession(widget.book.id);
      _sessionId = sessionId;
    } catch (_) {
      // Не критично: если сессия не открылась, чтение продолжается,
      // просто это время не попадёт в статистику
    }
  }

  Future<void> _loadFileUrl() async {
    final url = await _bookService.getBookFileUrl(widget.book.id);

    if (widget.book.fileFormat == 'epub') {
      final tempDir = await getTemporaryDirectory();
      final localPath = '${tempDir.path}/book_${widget.book.id}.epub';
      final isCached = File(localPath).existsSync();

      if (!isCached && mounted) {
        setState(() => _isDownloading = true);
      }

      final path = await _downloadEpubToTempFile();

      if (mounted) setState(() => _isDownloading = false);

      _epubController = EpubController(
        document: EpubDocument.openFile(File(path)),
      );
    }

    setState(() {
      _fileUrl = url;
      _isLoading = false;
    });
  }

  Future<String> _downloadEpubToTempFile() async {
    final tempDir = await getTemporaryDirectory();
    final localPath = '${tempDir.path}/book_${widget.book.id}.epub';

    // Если файл уже скачан ранее — используем кэш, не скачиваем повторно
    if (File(localPath).existsSync()) {
      return localPath;
    }

    final downloadUrl = _bookService.getBookFileDownloadUrl(widget.book.id);
    final token = await _bookService.getToken();

    await Dio().download(
      downloadUrl,
      localPath,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    return localPath;
  }

  // Сохраняет текущую страницу на backend при смене страницы
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
        if (value?.chapterNumber != null) {
          _saveProgress(value!.chapterNumber!);
        }
      },
    );
  }

  @override
  void dispose() {
    // Закрываем сессию чтения при выходе из читалки —
    // разница ended_at - started_at попадёт в статистику часов чтения
    if (_sessionId != null) {
      _bookService.endReadingSession(widget.book.id, _sessionId!).catchError((_) {});
    }
    _epubController?.dispose();
    super.dispose();
  }
}
