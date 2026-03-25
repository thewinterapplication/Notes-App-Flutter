import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course.dart';
import '../models/pdf_file.dart';
import '../providers/pdf_provider.dart';
import 'pdf_detail_screen.dart';

/// Screen to display PDF files for a specific subject within a course
class SubjectPdfListScreen extends ConsumerStatefulWidget {
  final Course course;
  final String subject;
  final bool isPYQ;
  final bool isPlacement;

  const SubjectPdfListScreen({
    super.key,
    required this.course,
    required this.subject,
    this.isPYQ = false,
    this.isPlacement = false,
  });

  @override
  ConsumerState<SubjectPdfListScreen> createState() => _SubjectPdfListScreenState();
}

class _SubjectPdfListScreenState extends ConsumerState<SubjectPdfListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Course get course => widget.course;
  String get subject => widget.subject;
  bool get isPYQ => widget.isPYQ;
  bool get isPlacement => widget.isPlacement;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openPdf(BuildContext context, PdfFile file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfDetailScreen(
          pdfFile: file,
          course: course,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final params = CourseSubjectParams(course: course.abbreviation, subject: subject);
    final pdfFilesAsync = ref.watch(
      isPlacement
          ? placementFilesByCourseSubjectProvider(params)
          : isPYQ
              ? pyqFilesByCourseSubjectProvider(params)
              : pdfFilesByCourseSubjectProvider(params),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Styled gradient header with search
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: course.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: course.gradientColors[0].withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button + title row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${course.abbreviation} - ${course.fullName}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search notes...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 8),
                          child: Icon(Icons.search_rounded, color: course.gradientColors[0], size: 22),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 46),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: Colors.grey.shade400, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: pdfFilesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load files',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => ref.invalidate(
                          isPlacement
                              ? placementFilesByCourseSubjectProvider(params)
                              : isPYQ
                                  ? pyqFilesByCourseSubjectProvider(params)
                                  : pdfFilesByCourseSubjectProvider(params),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (files) {
                  if (files.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No files yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload PDFs for $subject to see them here',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final filtered = _searchQuery.isEmpty
                      ? files
                      : files.where((f) =>
                          f.fileName.toLowerCase().contains(_searchQuery.toLowerCase())
                        ).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No notes found',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(
                        isPlacement
                            ? placementFilesByCourseSubjectProvider(params)
                            : isPYQ
                                ? pyqFilesByCourseSubjectProvider(params)
                                : pdfFilesByCourseSubjectProvider(params),
                      );
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildFileCard(context, filtered[index], index),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stripExtension(String fileName) {
    if (fileName.toLowerCase().endsWith('.pdf')) {
      return fileName.substring(0, fileName.length - 4);
    }
    return fileName;
  }

  Widget _buildFileCard(BuildContext context, PdfFile file, int index) {
    final tileColor = course.gradientColors[0].withOpacity(0.06 + (index % 3) * 0.03);
    return GestureDetector(
      onTap: () => _openPdf(context, file),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: course.gradientColors[0].withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.article_rounded, color: course.gradientColors[0], size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _stripExtension(file.fileName),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF212121),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: course.gradientColors[0]),
                      const SizedBox(width: 4),
                      Text(
                        'Author',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 14, color: course.gradientColors[0]),
                      const SizedBox(width: 4),
                      Text(
                        '${file.viewCount}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.thumb_up_outlined, size: 14, color: course.gradientColors[0]),
                      const SizedBox(width: 4),
                      Text(
                        '${file.likesCount}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
