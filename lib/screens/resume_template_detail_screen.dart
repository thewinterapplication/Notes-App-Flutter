import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/resume_template.dart';
import 'resume_templates_screen.dart' show PdfPreviewCache;

class ResumeTemplateDetailScreen extends StatefulWidget {
  const ResumeTemplateDetailScreen({super.key, required this.template});
  final ResumeTemplate template;

  @override
  State<ResumeTemplateDetailScreen> createState() =>
      _ResumeTemplateDetailScreenState();
}

class _ResumeTemplateDetailScreenState
    extends State<ResumeTemplateDetailScreen> {
  PdfControllerPinch? _pdfController;
  bool _loadingPdf = false;
  bool _pdfFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.template.isPdf) _openPdf();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _openPdf() async {
    setState(() => _loadingPdf = true);
    try {
      final bytes = await PdfPreviewCache.fetch(widget.template.fileUrl);
      final controller = PdfControllerPinch(
        document: PdfDocument.openData(bytes),
      );
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _pdfController = controller;
        _loadingPdf = false;
      });
    } catch (e) {
      debugPrint('[ResumeTemplate] open PDF failed: $e');
      if (!mounted) return;
      setState(() {
        _loadingPdf = false;
        _pdfFailed = true;
      });
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
      body: _buildBody(template),
      floatingActionButton: FloatingActionButton(
        onPressed: _download,
        backgroundColor: const Color(0xFFE85D04),
        foregroundColor: Colors.white,
        tooltip: 'Download',
        child: const Icon(Icons.download_rounded),
      ),
    );
  }

  Widget _buildBody(ResumeTemplate template) {
    if (template.isPdf) {
      if (_loadingPdf) {
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
      if (_pdfController != null) {
        return PdfViewPinch(
          controller: _pdfController!,
          padding: 8,
        );
      }
      if (_pdfFailed) return _fallbackPlaceholder(template);
    }

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
