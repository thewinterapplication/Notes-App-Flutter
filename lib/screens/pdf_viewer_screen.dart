import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:page_flip/page_flip.dart';
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

  // Controllers for viewing modes
  PdfControllerPinch? _scrollController; // For scroll mode
  final GlobalKey<PageFlipWidgetState> _pageFlipController = GlobalKey(); // For page flip animation

  bool _singlePageMode = true; // Book mode is default
  int _currentPage = 1;
  int _totalPages = 0;
  int _pagesLoaded = 0; // Track loading progress
  bool _pagesPreloaded = false; // All pages loaded for book mode
  Future<PdfDocument>? _documentFuture; // For book mode page rendering
  Future<PdfDocument>? _scrollDocumentFuture; // Separate future for scroll mode
  PdfDocument? _loadedDocument;
  final Map<int, PdfPageImage?> _pageCache = {};

  // Zoom state for book mode (simple approach - just track which page is zoomed)
  int? _zoomedPageNumber;

  @override
  void initState() {
    super.initState();
    _enableSecureMode();
    _documentFuture = _loadDocument();
    _scrollDocumentFuture = _loadScrollDocument();
    _initControllers();
  }

  void _initControllers() {
    _scrollController = PdfControllerPinch(
      document: _scrollDocumentFuture!,
    );
    _scrollController!.addListener(_onScrollPageChanged);
  }

  Future<PdfDocument> _loadScrollDocument() async {
    final bytes = await http.readBytes(Uri.parse(widget.pdfUrl));
    return await PdfDocument.openData(bytes);
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
    _loadedDocument = doc;
    if (mounted) {
      setState(() {
        _totalPages = doc.pagesCount;
      });
    }
    // Pre-load all pages sequentially for book mode
    _preloadAllPages();
    return doc;
  }

  Future<void> _preloadAllPages() async {
    if (_loadedDocument == null || _totalPages == 0) return;
    for (int i = 1; i <= _totalPages; i++) {
      await _getPageImage(i); // Sequential loading
      if (mounted) {
        setState(() {
          _pagesLoaded = i;
        });
      }
    }
    if (mounted) {
      setState(() {
        _pagesPreloaded = true;
      });
    }
  }

  Future<PdfPageImage?> _getPageImage(int pageNumber) async {
    if (_pageCache.containsKey(pageNumber)) {
      return _pageCache[pageNumber];
    }
    if (_loadedDocument == null) return null;
    try {
      final page = await _loadedDocument!.getPage(pageNumber);
      final image = await page.render(
        width: page.width * 2,
        height: page.height * 2,
      );
      await page.close(); // Release page resources
      _pageCache[pageNumber] = image;
      return image;
    } catch (e) {
      debugPrint('Error loading page $pageNumber: $e');
      return null;
    }
  }

  Widget _buildPageWidget(int pageNumber) {
    final cachedImage = _pageCache[pageNumber];
    if (cachedImage?.bytes == null) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isZoomed = _zoomedPageNumber == pageNumber;

    return GestureDetector(
      onDoubleTap: () {
        setState(() {
          if (isZoomed) {
            _zoomedPageNumber = null; // Zoom out
          } else {
            _zoomedPageNumber = pageNumber; // Zoom in
          }
        });
      },
      child: Container(
        color: Colors.white,
        child: isZoomed
            ? InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.memory(
                  cachedImage!.bytes,
                  fit: BoxFit.contain,
                ),
              )
            : Image.memory(
                cachedImage!.bytes,
                fit: BoxFit.contain,
              ),
      ),
    );
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
    _scrollController?.dispose();
    _pageCache.clear();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      _pageFlipController.currentState?.goToPage(page - 1);
      setState(() {
        _currentPage = page;
      });
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
                  ? _pagesPreloaded
                      ? PageFlipWidget(
                          key: _pageFlipController,
                          backgroundColor: Colors.black,
                          lastPage: Container(
                            color: Colors.white,
                            child: const Center(
                              child: Text(
                                'End of Document',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            ),
                          ),
                          children: List.generate(_totalPages, (index) {
                            return _buildPageWidget(index + 1);
                          }),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(color: Colors.white),
                              const SizedBox(height: 16),
                              Text(
                                _totalPages > 0
                                    ? 'Loading pages: $_pagesLoaded / $_totalPages'
                                    : 'Loading document...',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        )
                  : FutureBuilder<PdfDocument>(
                      future: _scrollDocumentFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading PDF: ${snapshot.error}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        }
                        return PdfViewPinch(
                          controller: _scrollController!,
                        );
                      },
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
