import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/resume_template.dart';

class ResumeTemplateDetailScreen extends StatefulWidget {
  const ResumeTemplateDetailScreen({super.key, required this.template});
  final ResumeTemplate template;

  @override
  State<ResumeTemplateDetailScreen> createState() =>
      _ResumeTemplateDetailScreenState();
}

class _ResumeTemplateDetailScreenState
    extends State<ResumeTemplateDetailScreen> {
  Uint8List? _pdfPreview;
  bool _loadingPreview = false;
  bool _previewFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.template.isPdf && widget.template.thumbnailUrl.isEmpty) {
      _loadPdfPreview();
    }
  }

  Future<void> _loadPdfPreview() async {
    setState(() => _loadingPreview = true);
    try {
      final response = await http.get(Uri.parse(widget.template.fileUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final doc = await PdfDocument.openData(response.bodyBytes);
      final page = await doc.getPage(1);
      final img = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      await doc.close();
      if (mounted && img?.bytes != null) {
        setState(() { _pdfPreview = img!.bytes; _loadingPreview = false; });
      } else {
        if (mounted) setState(() { _loadingPreview = false; _previewFailed = true; });
      }
    } catch (_) {
      if (mounted) setState(() { _loadingPreview = false; _previewFailed = true; });
    }
  }

  Future<void> _download() async {
    final uri = Uri.parse(widget.template.fileUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(template.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF2D3E50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildPreview(template),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _download,
        backgroundColor: const Color(0xFFE85D04),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.download_rounded),
        label: const Text('Download', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildPreview(ResumeTemplate template) {
    // 1. Thumbnail URL provided — show network image
    if (template.thumbnailUrl.isNotEmpty) {
      return InteractiveViewer(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                template.thumbnailUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, __, ___) => _fallbackPlaceholder(template),
              ),
            ),
          ),
        ),
      );
    }

    // 2. PDF — render first page
    if (template.isPdf) {
      if (_loadingPreview) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading preview…',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        );
      }
      if (_pdfPreview != null) {
        return InteractiveViewer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_pdfPreview!, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      }
    }

    // 3. Fallback — icon placeholder
    return _fallbackPlaceholder(template);
  }

  Widget _fallbackPlaceholder(ResumeTemplate template) {
    final isPdf = template.isPdf;
    final color = isPdf ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPdf
                    ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
                    : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
              color: Colors.white,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            template.name,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3E50)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isPdf ? 'PDF Document' : 'Word Document',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap Download to save this template',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
