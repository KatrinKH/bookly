import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import '../models/book.dart';
import '../services/book_service.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final BookService _bookService = BookService();

  late PdfViewerController? _pdfController;
  String? _fileUrl;

  final EpubController _epubController = EpubController();
  String? _epubLocalPath;

  bool _isLoading = true;
  bool _isDownloading = false;
  int? _sessionId;

  String get _cfiKey => 'epub_cfi_${widget.book.id}';

  @override
  void initState() {
    super.initState();
    _pdfController = widget.book.fileFormat == 'pdf' ? PdfViewerController() : null;
    _loadFile();
    _startSession();
  }

  Future<void> _startSession() async {
    try {
      final sessionId = await _bookService.startReadingSession(widget.book.id);
      _sessionId = sessionId;
    } catch (_) {}
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
        _epubLocalPath = localPath;
        _isLoading = false;
      });
    }

    // Сообщаем backend, что книга открыта — переводит статус not_started -> reading
    // и фиксирует started_at. Для EPUB страниц как таковых нет, поэтому передаём
    // условный прогресс 1, чтобы статус сменился даже если пользователь не скроллил.
    _markEpubAsStarted();
  }

  Future<void> _markEpubAsStarted() async {
    try {
      await _bookService.updateProgress(
        bookId: widget.book.id,
        currentPage: widget.book.currentPage > 0 ? widget.book.currentPage : 1,
      );
    } catch (_) {}
  }

  Future<void> _restorePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCfi = prefs.getString(_cfiKey);
      if (savedCfi != null && savedCfi.isNotEmpty) {
        // Увеличенная задержка — scrolled-режим требует больше времени на инициализацию
        await Future.delayed(const Duration(milliseconds: 1500));
        _epubController.display(cfi: savedCfi);
      }
    } catch (_) {}
  }

  void _savePosition(EpubLocation location) {
    final cfi = location.startCfi;
    if (cfi.isNotEmpty) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_cfiKey, cfi);
      });
    }
  }

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
    return EpubViewer(
      epubSource: EpubSource.fromFile(File(_epubLocalPath!)),
      epubController: _epubController,
      displaySettings: EpubDisplaySettings(
        flow: EpubFlow.scrolled,
        snap: false,
      ),
      onEpubLoaded: () async {
        await _restorePosition();
      },
      onRelocated: (location) {
        _savePosition(location);
      },
    );
  }

  @override
  void dispose() {
    if (_sessionId != null) {
      _bookService.endReadingSession(widget.book.id, _sessionId!).catchError((_) {});
    }
    super.dispose();
  }
}
