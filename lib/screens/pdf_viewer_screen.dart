import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:screen_protector/screen_protector.dart';

/// Fullscreen PDF Viewer - simple page view with zoom and thumbnail navigation
class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String userPhone;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.userPhone,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  static const bool enableScreenshotProtection = true;

  int _currentPage = 1;
  int _totalPages = 0;
  bool _documentReady = false;
  bool _scrollMode = false; // false = page mode, true = scroll mode
  String? _errorMessage;
  PdfDocument? _loadedDocument;
  final Map<int, PdfPageImage?> _pageCache = {};

  // Async lock to serialize getPage() calls — prevents concurrent native access
  Completer<void>? _renderLock;

  // Track zoom/pinch state to disable PageView swiping
  bool _isZoomedIn = false;
  int _pointerCount = 0;
  final TransformationController _transformationController = TransformationController();

  late final PageController _pageController;
  final ScrollController _thumbnailScrollController = ScrollController();

  // Scroll mode controller (separate document instance to avoid concurrency)
  PdfControllerPinch? _scrollController;
  Future<PdfDocument>? _scrollDocumentFuture;

  @override
  void initState() {
    super.initState();
    _enableSecureMode();
    _pageController = PageController();
    _transformationController.addListener(_onZoomChanged);
    _loadDocument();
    _scrollDocumentFuture = _loadScrollDocument();
    _scrollController = PdfControllerPinch(document: _scrollDocumentFuture!);
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

  Map<String, String> get _requestHeaders => {
        'X-User-Phone': widget.userPhone.trim(),
      };

  Future<Uint8List> _readPdfBytes() async {
    if (widget.userPhone.trim().isEmpty) {
      throw Exception('Login and an active subscription are required to open this PDF.');
    }

    return http.readBytes(
      Uri.parse(widget.pdfUrl),
      headers: _requestHeaders,
    );
  }

  String _formatLoadError(Object error) {
    final message = error.toString();

    if (widget.userPhone.trim().isEmpty || message.contains('401')) {
      return 'Please login again to open this PDF.';
    }

    if (message.contains('403')) {
      return 'An active subscription is required to open this PDF.';
    }

    return 'Unable to load this PDF right now.';
  }

  void _onZoomChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (zoomed != _isZoomedIn) {
      setState(() {
        _isZoomedIn = zoomed;
      });
    }
  }

  Future<PdfDocument> _loadScrollDocument() async {
    final bytes = await _readPdfBytes();
    return await PdfDocument.openData(bytes);
  }

  Future<void> _loadDocument() async {
    try {
      final bytes = await _readPdfBytes();
      final doc = await PdfDocument.openData(bytes);
      _loadedDocument = doc;
      if (mounted) {
        setState(() {
          _totalPages = doc.pagesCount;
          _documentReady = true;
          _errorMessage = null;
        });
        // Preload first page and adjacent
        _preloadAdjacentPages(1);
      }
    } catch (e) {
      debugPrint('Error loading document: $e');
      if (mounted) {
        setState(() {
          _errorMessage = _formatLoadError(e);
        });
      }
    }
  }

  /// Serialized page rendering — only one getPage() call at a time
  Future<PdfPageImage?> _ensurePageLoaded(int pageNumber) async {
    if (_pageCache.containsKey(pageNumber)) {
      return _pageCache[pageNumber];
    }
    if (_loadedDocument == null) return null;

    // Wait for any ongoing render to finish
    while (_renderLock != null) {
      await _renderLock!.future;
    }

    // Double-check cache after waiting
    if (_pageCache.containsKey(pageNumber)) {
      return _pageCache[pageNumber];
    }

    // Acquire lock
    _renderLock = Completer<void>();
    try {
      final page = await _loadedDocument!.getPage(pageNumber);
      final image = await page.render(
        width: page.width * 2,
        height: page.height * 2,
      );
      await page.close();
      _pageCache[pageNumber] = image;
      if (mounted) setState(() {});
      return image;
    } catch (e) {
      debugPrint('Error loading page $pageNumber: $e');
      return null;
    } finally {
      // Release lock
      final lock = _renderLock;
      _renderLock = null;
      lock?.complete();
    }
  }

  void _preloadAdjacentPages(int currentPage) {
    // Load current page first, then adjacent pages sequentially
    _ensurePageLoaded(currentPage).then((_) {
      for (int i = 1; i <= 2; i++) {
        if (currentPage + i <= _totalPages) {
          _ensurePageLoaded(currentPage + i);
        }
        if (currentPage - i >= 1) {
          _ensurePageLoaded(currentPage - i);
        }
      }
    });
  }

  Widget _buildZoomableImage(PdfPageImage image) {
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 1.0,
      maxScale: 5.0,
      panEnabled: _isZoomedIn,
      child: Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Image.memory(
          image.bytes,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildPageWidget(int pageNumber) {
    final cachedImage = _pageCache[pageNumber];
    if (cachedImage?.bytes != null) {
      return _buildZoomableImage(cachedImage!);
    }

    // Page not cached yet — load it
    return FutureBuilder<PdfPageImage?>(
      future: _ensurePageLoaded(pageNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data?.bytes != null) {
          return _buildZoomableImage(snapshot.data!);
        }
        return Container(
          color: Colors.white,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  /// Build thumbnail using cached page image — no independent getPage() calls
  Widget _buildThumbnail(int pageNum, bool isSelected) {
    final cachedImage = _pageCache[pageNum];
    return GestureDetector(
      onTap: () => _goToPage(pageNum),
      child: Container(
        width: 60,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Show cached image or page number placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: cachedImage?.bytes != null
                  ? Image.memory(
                      cachedImage!.bytes,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Text(
                        '$pageNum',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                      : Colors.black.withOpacity(0.6),
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
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      _pageController.animateToPage(
        page - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollThumbnailToPage(int page) {
    if (!_thumbnailScrollController.hasClients) return;
    final targetOffset = (page - 1) * 68.0;
    final maxScroll = _thumbnailScrollController.position.maxScrollExtent;
    final viewportWidth = _thumbnailScrollController.position.viewportDimension;
    final centeredOffset = targetOffset - (viewportWidth / 2) + 34;
    _thumbnailScrollController.animateTo(
      centeredOffset.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _disableSecureMode();
    _transformationController.removeListener(_onZoomChanged);
    _transformationController.dispose();
    _pageController.dispose();
    _scrollController?.dispose();
    _thumbnailScrollController.dispose();
    _pageCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Main PDF view — page mode or scroll mode
            Positioned.fill(
              bottom: !_scrollMode && _documentReady && _totalPages > 0 ? 100 : 0,
              child: _scrollMode
                  ? FutureBuilder<PdfDocument>(
                      future: _scrollDocumentFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              _formatLoadError(snapshot.error!),
                              style: const TextStyle(color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return PdfViewPinch(
                          controller: _scrollController!,
                        );
                      },
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _documentReady
                      ? Listener(
                          onPointerDown: (_) {
                            _pointerCount++;
                            if (_pointerCount >= 2) {
                              setState(() {});
                            }
                          },
                          onPointerUp: (_) {
                            _pointerCount--;
                            if (_pointerCount < 2) {
                              setState(() {});
                            }
                          },
                          onPointerCancel: (_) {
                            _pointerCount--;
                            if (_pointerCount < 2) {
                              setState(() {});
                            }
                          },
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _totalPages,
                            physics: (_isZoomedIn || _pointerCount >= 2)
                                ? const NeverScrollableScrollPhysics()
                                : null,
                            onPageChanged: (index) {
                              // Reset zoom when changing pages
                              _transformationController.value = Matrix4.identity();
                              setState(() {
                                _currentPage = index + 1;
                              });
                              _preloadAdjacentPages(index + 1);
                              _scrollThumbnailToPage(index + 1);
                            },
                            itemBuilder: (context, index) {
                              return _buildPageWidget(index + 1);
                            },
                          ),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                'Loading document...',
                                style: TextStyle(color: Colors.black54),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            // Toggle button - top right
            if (_documentReady)
              Positioned(
                right: 16,
                top: 16,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _scrollMode = !_scrollMode;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _scrollMode ? Icons.auto_stories : Icons.view_day,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _scrollMode ? 'Page' : 'Scroll',
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
              ),
            // Thumbnail strip - bottom (only in page mode)
            if (!_scrollMode && _documentReady && _totalPages > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                  ),
                  child: ListView.builder(
                    controller: _thumbnailScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    itemCount: _totalPages,
                    itemBuilder: (context, index) {
                      final pageNum = index + 1;
                      final isSelected = pageNum == _currentPage;
                      return _buildThumbnail(pageNum, isSelected);
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
