import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Custom widget to render PDF page thumbnail
class PdfThumbnail extends StatefulWidget {
  final PdfDocument document;
  final int pageNumber;
  final Color backgroundColor;

  const PdfThumbnail({
    super.key,
    required this.document,
    required this.pageNumber,
    this.backgroundColor = Colors.white,
  });

  @override
  State<PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<PdfThumbnail> {
  PdfPageImage? _pageImage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    try {
      final page = await widget.document.getPage(widget.pageNumber);
      final pageImage = await page.render(
        width: page.width * 0.3,
        height: page.height * 0.3,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      if (mounted) {
        setState(() {
          _pageImage = pageImage;
          _isLoading = false;
        });
      }
      await page.close();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: widget.backgroundColor,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    if (_pageImage?.bytes != null) {
      return Image.memory(
        _pageImage!.bytes,
        fit: BoxFit.cover,
      );
    }

    return Container(
      color: widget.backgroundColor,
      child: const Center(
        child: Icon(Icons.error_outline, size: 16, color: Colors.grey),
      ),
    );
  }
}
