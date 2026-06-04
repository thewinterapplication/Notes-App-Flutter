import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import '../models/resume_template.dart';
import '../services/api_service.dart';
import 'resume_template_detail_screen.dart';

class ResumeTemplatesScreen extends StatefulWidget {
  const ResumeTemplatesScreen({super.key});

  @override
  State<ResumeTemplatesScreen> createState() => _ResumeTemplatesScreenState();
}

class _ResumeTemplatesScreenState extends State<ResumeTemplatesScreen> {
  List<ResumeTemplate> _templates = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final templates = await ApiService.getResumeTemplates();
      if (mounted) setState(() { _templates = templates; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE85D04), Color(0xFFD62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text('Resume Templates',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Download professionally crafted templates',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              setState(() { _loading = true; _error = null; });
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text('Could not load templates',
                  style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() { _loading = true; _error = null; });
                  _load();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_templates.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          setState(() { _loading = true; _error = null; });
          await _load();
        },
        child: ListView(children: [
          SizedBox(
            height: 320,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_rounded,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No templates available yet',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  Text('Check back soon!',
                      style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() { _loading = true; _error = null; });
        await _load();
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        itemCount: _templates.length,
        itemBuilder: (_, i) => _TemplateCard(template: _templates[i]),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});
  final ResumeTemplate template;

  @override
  Widget build(BuildContext context) {
    final isPdf = template.isPdf;
    final badgeColor = isPdf ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
    final gradientColors = isPdf
        ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
        : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)];

    Widget preview;
    if (template.thumbnailUrl.isNotEmpty) {
      preview = Image.network(
        template.thumbnailUrl,
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        errorBuilder: (_, __, ___) =>
            _IconPlaceholder(colors: gradientColors, isPdf: isPdf),
      );
    } else if (isPdf) {
      preview = _PdfTopPreview(
        url: template.fileUrl,
        fallback: _IconPlaceholder(colors: gradientColors, isPdf: isPdf),
      );
    } else {
      preview = _IconPlaceholder(colors: gradientColors, isPdf: isPdf);
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResumeTemplateDetailScreen(template: template),
        ),
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Colors.white,
                child: ClipRect(child: preview),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isPdf ? 'PDF' : 'WORD',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPlaceholder extends StatelessWidget {
  const _IconPlaceholder({required this.colors, required this.isPdf});
  final List<Color> colors;
  final bool isPdf;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Center(
        child: Icon(
          isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
          color: Colors.white.withValues(alpha: 0.9),
          size: 56,
        ),
      ),
    );
  }
}

/// Caches raw PDF bytes by URL so the card preview and the detail viewer
/// share one download. The list card additionally caches a rendered first-page
/// PNG so it doesn't re-rasterize on every scroll back.
class PdfPreviewCache {
  static final Map<String, Uint8List> _pdfBytes = {};
  static final Map<String, Uint8List> _firstPagePng = {};
  static final Map<String, Future<Uint8List>> _inflight = {};

  static Uint8List? getBytes(String url) => _pdfBytes[url];
  static Uint8List? getFirstPage(String url) => _firstPagePng[url];
  static void putFirstPage(String url, Uint8List png) =>
      _firstPagePng[url] = png;

  /// Fetches the PDF bytes (deduped across concurrent callers).
  static Future<Uint8List> fetch(String url) {
    final existing = _pdfBytes[url];
    if (existing != null) return Future.value(existing);
    final inflight = _inflight[url];
    if (inflight != null) return inflight;

    final future = () async {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }
        _pdfBytes[url] = response.bodyBytes;
        return response.bodyBytes;
      } finally {
        _inflight.remove(url);
      }
    }();
    _inflight[url] = future;
    return future;
  }
}

class _PdfTopPreview extends StatefulWidget {
  const _PdfTopPreview({required this.url, required this.fallback});
  final String url;
  final Widget fallback;

  @override
  State<_PdfTopPreview> createState() => _PdfTopPreviewState();
}

class _PdfTopPreviewState extends State<_PdfTopPreview> {
  Uint8List? _png;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final cached = PdfPreviewCache.getFirstPage(widget.url);
    if (cached != null) {
      _png = cached;
      _loading = false;
    } else {
      _render();
    }
  }

  Future<void> _render() async {
    try {
      final pdfBytes = await PdfPreviewCache.fetch(widget.url);
      final doc = await PdfDocument.openData(pdfBytes);
      final page = await doc.getPage(1);
      final img = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      await doc.close();
      final png = img?.bytes;
      if (png == null) throw Exception('Render returned null');
      PdfPreviewCache.putFirstPage(widget.url, png);
      if (!mounted) return;
      setState(() {
        _png = png;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ResumeTemplate] preview render failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    if (_failed || _png == null) return widget.fallback;
    return Image.memory(
      _png!,
      fit: BoxFit.fitWidth,
      alignment: Alignment.topCenter,
      gaplessPlayback: true,
    );
  }
}
