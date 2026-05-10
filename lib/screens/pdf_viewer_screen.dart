import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:screen_protector/screen_protector.dart';

import '../models/pdf_file.dart';
import '../services/pdf_cache_service.dart';
import '../services/review_service.dart';

/// Fullscreen PDF Viewer - simple page view with zoom and thumbnail navigation
class PdfViewerScreen extends StatefulWidget {
  final PdfFile pdfFile;
  final String userPhone;

  const PdfViewerScreen({
    super.key,
    required this.pdfFile,
    required this.userPhone,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  static const bool enableScreenshotProtection = true;
  static const int _pagePreloadRadius = 4;
  static const int _pageCacheRadius = 6;

  int _currentPage = 1;
  int _totalPages = 0;
  bool _documentReady = false;
  bool _scrollMode = false;
  bool _downloadFinished = false;
  String? _errorMessage;
  String? _localPdfPath;
  double? _downloadProgress;
  PdfDocument? _loadedDocument;
  int _documentGeneration = 0;
  final Map<int, PdfPageImage?> _pageCache = {};

  // Serialize getPage() calls to avoid concurrent native access.
  Completer<void>? _renderLock;
  int _preloadGeneration = 0;
  final Map<int, Future<PdfPageImage?>> _inFlightPageLoads = {};
  bool _backgroundDownloadCancelled = false;
  int _bgDownloadedPages = 0;
  bool _bgDownloadDone = false;

  bool _isZoomedIn = false;
  int _pointerCount = 0;
  final TransformationController _transformationController =
      TransformationController();

  late final PageController _pageController;
  final ScrollController _thumbnailScrollController = ScrollController();

  PdfControllerPinch? _scrollController;
  Future<PdfDocument>? _scrollDocumentFuture;

  String _formatLogDetails(Map<String, Object?> details) {
    return details.entries
        .where((entry) => entry.value != null)
        .map((entry) {
          final value = entry.value;
          final rendered = value is String ? jsonEncode(value) : value;
          return '${entry.key}=$rendered';
        })
        .join(' ');
  }

  void _logViewer(String message, [Map<String, Object?> details = const {}]) {
    final mergedDetails = <String, Object?>{
      'documentId': widget.pdfFile.id,
      'fileName': widget.pdfFile.fileName,
      ...details,
    };
    final suffix = _formatLogDetails(mergedDetails);
    debugPrint('[PDFViewer] $message${suffix.isEmpty ? '' : ' $suffix'}');
  }

  void _logViewerError(
    String message,
    Object error, [
    Map<String, Object?> details = const {},
  ]) {
    final mergedDetails = <String, Object?>{
      'documentId': widget.pdfFile.id,
      'fileName': widget.pdfFile.fileName,
      ...details,
    };
    final suffix = _formatLogDetails(mergedDetails);
    debugPrint(
      '[PDFViewer] $message${suffix.isEmpty ? '' : ' $suffix'} error=$error',
    );
  }

  @override
  void initState() {
    super.initState();
    _enableSecureMode();
    _pageController = PageController();
    _transformationController.addListener(_onZoomChanged);
    _loadDocument();
    ReviewService.trackViewAndMaybeRequestReview();
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

  String _formatLoadError(Object error) {
    if (error is PdfDownloadException) {
      if (error.statusCode == 401) {
        return widget.userPhone.trim().isEmpty
            ? 'Please login to open this premium PDF.'
            : 'Please login again to open this PDF.';
      }

      if (error.statusCode == 403) {
        return 'An active subscription is required to open this premium PDF.';
      }

      return error.message;
    }

    final message = error.toString();

    if (message.contains('401')) {
      return widget.userPhone.trim().isEmpty
          ? 'Please login to open this premium PDF.'
          : 'Please login again to open this PDF.';
    }

    if (message.contains('403')) {
      return 'An active subscription is required to open this premium PDF.';
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
    final localPdfPath = _localPdfPath;
    if (localPdfPath == null) {
      throw const PdfDownloadException('Document is still loading.');
    }

    return await PdfDocument.openFile(localPdfPath);
  }

  Future<void> _loadDocument() async {
    if (widget.pdfFile.pageCount > 0) {
      _logViewer('load-start-per-page', {
        'pageCount': widget.pdfFile.pageCount,
      });
      setState(() {
        _totalPages = widget.pdfFile.pageCount;
        _documentReady = true;
      });
      _preloadAdjacentPages(1);
      unawaited(_backgroundDownloadAllPages(widget.pdfFile.pageCount));
      return;
    }

    try {
      _logViewer('load-start', {
        'downloadUrl': widget.pdfFile.downloadUrl,
        'hasUserPhone': widget.userPhone.trim().isNotEmpty,
      });
      final cachedFile = await PdfCacheService.getOrDownloadPdf(
        pdfFile: widget.pdfFile,
        userPhone: widget.userPhone,
        onPartialReady: (partialPath) {
          if (!mounted || _documentReady) return;
          _logViewer('partial-file-ready', {'partialPath': partialPath});
          unawaited(_openDocument(partialPath, isPartial: true));
        },
        onProgress: (receivedBytes, totalBytes) {
          if (!mounted || totalBytes == null || totalBytes <= 0) return;
          setState(() {
            _downloadProgress = receivedBytes / totalBytes;
          });
        },
      );

      if (!mounted) {
        _logViewer('load-unmounted-after-download', {
          'path': cachedFile.filePath,
          'fromCache': cachedFile.fromCache,
        });
        return;
      }

      _logViewer('cache-result', {
        'path': cachedFile.filePath,
        'fromCache': cachedFile.fromCache,
      });

      setState(() {
        _localPdfPath = cachedFile.filePath;
        _downloadFinished = true;
      });

      await _openDocument(cachedFile.filePath);
    } catch (error) {
      _logViewerError('load-failed', error);
      debugPrint('Error loading document: $error');
      if (mounted && !_documentReady) {
        setState(() {
          _errorMessage = _formatLoadError(error);
        });
      }
    }
  }

  Future<void> _openDocument(String filePath, {bool isPartial = false}) async {
    final myGeneration = ++_documentGeneration;
    PdfDocument? doc;
    try {
      _logViewer('open-file-start', {
        'path': filePath,
        'isPartial': isPartial,
        'generation': myGeneration,
        'isMounted': mounted,
      });
      doc = await PdfDocument.openFile(filePath);
      _logViewer('open-file-native-ok', {
        'path': filePath,
        'isPartial': isPartial,
        'generation': myGeneration,
        'pages': doc.pagesCount,
        'isMounted': mounted,
      });

      if (!mounted || myGeneration != _documentGeneration) {
        _logViewer('open-file-discarded', {
          'path': filePath,
          'isPartial': isPartial,
          'generation': myGeneration,
          'activeGeneration': _documentGeneration,
          'isMounted': mounted,
        });
        await doc.close();
        return;
      }

      final prevDoc = _loadedDocument;
      setState(() {
        _loadedDocument = doc;
        _totalPages = doc!.pagesCount;
        _documentReady = true;
        _errorMessage = null;
        _pageCache.clear();
      });
      try {
        await prevDoc?.close();
      } catch (_) {}
      _logViewer('open-file-complete', {
        'path': filePath,
        'isPartial': isPartial,
        'pages': _totalPages,
        'generation': myGeneration,
      });
      _preloadAdjacentPages(_currentPage);
    } catch (error) {
      await doc?.close();
      if (isPartial || !mounted || myGeneration != _documentGeneration) {
        _logViewerError('open-file-ignored', error, {
          'path': filePath,
          'isPartial': isPartial,
          'generation': myGeneration,
          'activeGeneration': _documentGeneration,
        });
        // Swallow: partial open failures are expected for old non-linearized PDFs;
        // superseded opens are discarded silently.
        return;
      }
      _logViewerError('open-file-failed', error, {
        'path': filePath,
        'isPartial': isPartial,
        'generation': myGeneration,
      });
      if (!_documentReady) {
        setState(() {
          _errorMessage = _formatLoadError(error);
        });
      }
    }
  }

  Future<PdfPageImage?> _loadPageFromBytes(int pageNumber) async {
    try {
      final bytes = await PdfCacheService.fetchPage(
        pdfFile: widget.pdfFile,
        userPhone: widget.userPhone,
        pageNumber: pageNumber,
      );
      final doc = await PdfDocument.openData(bytes);
      final page = await doc.getPage(1);
      final image = await page.render(
        width: page.width * 2,
        height: page.height * 2,
      );
      await page.close();
      await doc.close();
      _pageCache[pageNumber] = image;
      if (mounted) setState(() {});
      return image;
    } catch (error) {
      _logViewerError('page-load-failed', error, {'page': pageNumber});
      return null;
    }
  }

  Future<PdfPageImage?> _ensurePageLoaded(int pageNumber) async {
    if (_pageCache.containsKey(pageNumber)) {
      return _pageCache[pageNumber];
    }

    if (widget.pdfFile.pageCount > 0) {
      final inFlight = _inFlightPageLoads[pageNumber];
      if (inFlight != null) return inFlight;

      final future = _loadPageFromBytes(pageNumber);
      _inFlightPageLoads[pageNumber] = future;
      try {
        return await future;
      } finally {
        _inFlightPageLoads.remove(pageNumber);
      }
    }

    if (_loadedDocument == null) {
      return null;
    }

    while (_renderLock != null) {
      await _renderLock!.future;
    }

    if (_pageCache.containsKey(pageNumber)) {
      return _pageCache[pageNumber];
    }

    _renderLock = Completer<void>();
    try {
      final page = await _loadedDocument!.getPage(pageNumber);
      final image = await page.render(
        width: page.width * 2,
        height: page.height * 2,
      );
      await page.close();
      _pageCache[pageNumber] = image;
      if (mounted) {
        setState(() {});
      }
      return image;
    } catch (error) {
      _logViewerError('page-load-failed', error, {'page': pageNumber});
      debugPrint('Error loading page $pageNumber: $error');
      return null;
    } finally {
      final lock = _renderLock;
      _renderLock = null;
      lock?.complete();
    }
  }

  void _preloadAdjacentPages(int currentPage) {
    final generation = ++_preloadGeneration;
    final pagesToLoad = <int>[currentPage];

    for (int i = 1; i <= _pagePreloadRadius; i++) {
      final nextPage = currentPage + i;
      if (nextPage <= _totalPages) {
        pagesToLoad.add(nextPage);
      }

      final previousPage = currentPage - i;
      if (previousPage >= 1) {
        pagesToLoad.add(previousPage);
      }
    }

    _trimPageCache(currentPage);
    unawaited(_preloadPageWindow(pagesToLoad, currentPage, generation));
  }

  Future<void> _preloadPageWindow(
    List<int> pagesToLoad,
    int anchorPage,
    int generation,
  ) async {
    if (!mounted || generation != _preloadGeneration) return;

    await Future.wait(
      pagesToLoad.map((pageNumber) async {
        if (!mounted || generation != _preloadGeneration) return;
        await _ensurePageLoaded(pageNumber);
      }),
    );

    if (mounted && generation == _preloadGeneration) {
      _trimPageCache(anchorPage);
    }
  }

  void _trimPageCache(int anchorPage) {
    final minPage = math.max(1, anchorPage - _pageCacheRadius);
    final maxPage = math.min(_totalPages, anchorPage + _pageCacheRadius);
    final pagesToRemove = _pageCache.keys
        .where((page) => page < minPage || page > maxPage)
        .toList();

    for (final page in pagesToRemove) {
      _pageCache.remove(page);
    }
  }

  void _toggleScrollMode() {
    setState(() {
      if (!_scrollMode && _scrollDocumentFuture == null) {
        _scrollDocumentFuture = _loadScrollDocument();
        _scrollController = PdfControllerPinch(
          document: _scrollDocumentFuture!,
        );
      }
      _scrollMode = !_scrollMode;
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
        child: Image.memory(image.bytes, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildPageWidget(int pageNumber) {
    final cachedImage = _pageCache[pageNumber];
    if (cachedImage?.bytes != null) {
      return _buildZoomableImage(cachedImage!);
    }

    return FutureBuilder<PdfPageImage?>(
      future: _ensurePageLoaded(pageNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data?.bytes != null) {
          return _buildZoomableImage(snapshot.data!);
        }

        return const _PdfLoadingView();
      },
    );
  }

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
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: cachedImage?.bytes != null
                  ? Image.memory(cachedImage!.bytes, fit: BoxFit.cover)
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
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue
                      : Colors.black.withValues(alpha: 0.6),
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

  Widget _buildLoadingState() => _PdfLoadingView(
    progress: _downloadProgress,
    openingDoc: _downloadFinished,
  );

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
    if (!_thumbnailScrollController.hasClients) {
      return;
    }

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
  Future<void> _backgroundDownloadAllPages(int totalPages) async {
    _logViewer('bg-download-start', {'totalPages': totalPages});
    for (int page = 1; page <= totalPages; page++) {
      if (_backgroundDownloadCancelled || !mounted) break;
      try {
        await PdfCacheService.fetchPage(
          pdfFile: widget.pdfFile,
          userPhone: widget.userPhone,
          pageNumber: page,
        );
      } catch (_) {
        // Don't abort the whole download if one page fails
      }
      if (mounted) setState(() => _bgDownloadedPages = page);
    }
    if (mounted) {
      setState(() => _bgDownloadDone = true);
      _logViewer('bg-download-complete', {'totalPages': totalPages});
    }
  }

  void dispose() {
    _backgroundDownloadCancelled = true;
    _disableSecureMode();
    _transformationController.removeListener(_onZoomChanged);
    _transformationController.dispose();
    _pageController.dispose();
    _scrollController?.dispose();
    _thumbnailScrollController.dispose();
    _pageCache.clear();
    _loadedDocument?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              bottom: !_scrollMode && _documentReady && _totalPages > 0
                  ? 100
                  : 0,
              child: _scrollMode
                  ? FutureBuilder<PdfDocument>(
                      future: _scrollDocumentFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                _formatLoadError(snapshot.error!),
                                style: const TextStyle(color: Colors.black54),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        return PdfViewPinch(controller: _scrollController!);
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
                  : _buildLoadingState(),
            ),
            if (_totalPages > 0)
              Positioned(
                left: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
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
            if (_documentReady && _localPdfPath != null)
              Positioned(
                right: 16,
                top: 16,
                child: GestureDetector(
                  onTap: _toggleScrollMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
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
                      horizontal: 8,
                      vertical: 8,
                    ),
                    itemCount: _totalPages,
                    itemBuilder: (context, index) {
                      final pageNum = index + 1;
                      final isSelected = pageNum == _currentPage;
                      return _buildThumbnail(pageNum, isSelected);
                    },
                  ),
                ),
              ),
            if (!_bgDownloadDone && _totalPages > 0 && widget.pdfFile.pageCount > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: (!_scrollMode && _documentReady && _totalPages > 0) ? 100 : 0,
                child: Container(
                  height: 20,
                  color: Colors.black.withValues(alpha: 0.75),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: _totalPages > 0
                                ? _bgDownloadedPages / _totalPages
                                : null,
                            backgroundColor: Colors.grey[700],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.lightBlueAccent,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_bgDownloadedPages / $_totalPages pages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double? progress;
  final double angle;

  _RingPainter({required this.progress, required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final trackPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final arcPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress != null) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        progress! * 2 * math.pi,
        false,
        arcPaint,
      );
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle - math.pi / 2,
        math.pi / 2,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.angle != angle;
}

class _PdfLoadingView extends StatefulWidget {
  final double? progress;
  final bool openingDoc;
  const _PdfLoadingView({this.progress, this.openingDoc = false});

  @override
  State<_PdfLoadingView> createState() => _PdfLoadingViewState();
}

class _PdfLoadingViewState extends State<_PdfLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.progress != null
        ? (widget.progress! * 100).clamp(0, 100).toStringAsFixed(0)
        : null;
    final isSpinning = widget.progress == null && !widget.openingDoc;

    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: AnimatedBuilder(
                animation: _rotateCtrl,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _RingPainter(
                      progress: widget.openingDoc ? 1.0 : widget.progress,
                      angle: _rotateCtrl.value * 2 * math.pi,
                    ),
                    child: Center(
                      child: widget.openingDoc
                          ? Text(
                              'Opening…',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : pct != null
                              ? Text(
                                  '$pct%',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                )
                              : Icon(
                                  Icons.hourglass_top_rounded,
                                  size: 32,
                                  color: Colors.grey.shade400,
                                ),
                    ),
                  );
                },
              ),
            ),
            if (!widget.openingDoc && !isSpinning) ...[
              const SizedBox(height: 12),
              Text(
                'Downloading…',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
