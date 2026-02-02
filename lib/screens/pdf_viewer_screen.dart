import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:screen_protector/screen_protector.dart';
import '../widgets/pdf_thumbnail.dart';

/// Fullscreen PDF Viewer - just the PDF with zoom and scroll
class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;

  const PdfViewerScreen({super.key, required this.pdfUrl});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  // Toggle screenshot protection: set to true to enable, false to disable
  static const bool enableScreenshotProtection = false;

  // Two controllers for two viewing modes
  PdfController? _pageController; // For single page (book) mode
  PdfControllerPinch? _scrollController; // For scroll mode

  bool _singlePageMode = true; // Book mode is default
  int _currentPage = 1;
  int _totalPages = 0;
  Future<PdfDocument>? _documentFuture;

  @override
  void initState() {
    super.initState();
    _enableSecureMode();
    _documentFuture = _loadDocument();
    _initControllers();
  }

  void _initControllers() {
    _pageController = PdfController(
      document: _documentFuture!,
    );
    _scrollController = PdfControllerPinch(
      document: _documentFuture!,
    );
    _scrollController!.addListener(_onScrollPageChanged);
  }

  void _onScrollPageChanged() {
    if (mounted && !_singlePageMode) {
      setState(() {
        _currentPage = _scrollController!.page;
      });
    }
  }

  void _onPageChanged(int page) {
    if (mounted) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  Future<void> _enableSecureMode() async {
    if (enableScreenshotProtection) {
      await ScreenProtector.preventScreenshotOn();
    }
  }

  Future<void> _disableSecureMode() async {
    if (enableScreenshotProtection) {
      await ScreenProtector.preventScreenshotOff();
    }
  }

  Future<PdfDocument> _loadDocument() async {
    final bytes = await http.readBytes(Uri.parse(widget.pdfUrl));
    final doc = await PdfDocument.openData(bytes);
    if (mounted) {
      setState(() {
        _totalPages = doc.pagesCount;
      });
    }
    return doc;
  }

  void _toggleViewMode() {
    setState(() {
      _singlePageMode = !_singlePageMode;
    });
  }

  @override
  void dispose() {
    _disableSecureMode();
    _scrollController?.removeListener(_onScrollPageChanged);
    _pageController?.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      _pageController?.jumpToPage(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main PDF viewer with padding for thumbnail strip
            Positioned.fill(
              bottom: _singlePageMode && _totalPages > 0 ? 100 : 0,
              child: _singlePageMode
                  ? PdfView(
                      controller: _pageController!,
                      scrollDirection: Axis.horizontal,
                      pageSnapping: true,
                      onPageChanged: _onPageChanged,
                    )
                  : PdfViewPinch(
                      controller: _scrollController!,
                    ),
            ),
            // Toggle button - top right
            Positioned(
              right: 16,
              top: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _toggleViewMode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _singlePageMode ? Icons.menu_book : Icons.view_day,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _singlePageMode ? 'Book' : 'Scroll',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Page indicator - top left
            if (_totalPages > 0)
              Positioned(
                left: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            // Thumbnail strip - bottom (only in book mode)
            if (_singlePageMode && _totalPages > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 100,
                child: Container(
                  color: Colors.black.withOpacity(0.9),
                  child: FutureBuilder<PdfDocument>(
                    future: _documentFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white54,
                            strokeWidth: 2,
                          ),
                        );
                      }
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        itemCount: _totalPages,
                        itemBuilder: (context, index) {
                          final pageNum = index + 1;
                          final isSelected = pageNum == _currentPage;
                          return GestureDetector(
                            onTap: () => _goToPage(pageNum),
                            child: Container(
                              width: 60,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected ? Colors.blue : Colors.white24,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: PdfThumbnail(
                                      document: snapshot.data!,
                                      pageNumber: pageNum,
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                                  // Page number overlay
                                  Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.blue
                                            : Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        '$pageNum',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
