import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course.dart';
import '../models/pdf_file.dart';
import '../providers/pdf_provider.dart';
import 'subject_pdf_list_screen.dart';
import 'pdf_detail_screen.dart';

/// Screen to display subjects for a specific course
/// Falls back to showing all PDFs if subjects endpoint is unavailable
class CourseSubjectsScreen extends ConsumerWidget {
  final Course course;

  const CourseSubjectsScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider(course.abbreviation));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: course.gradientColors[0],
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.abbreviation,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              course.fullName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              course.gradientColors[0].withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: subjectsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          // On error, fall back to showing all PDFs for the course
          error: (error, stack) => _FallbackPdfList(course: course),
          data: (subjects) {
            // If no subjects, fall back to showing all PDFs
            if (subjects.isEmpty) {
              return _FallbackPdfList(course: course);
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(subjectsProvider(course.abbreviation));
              },
              child: _buildSubjectList(context, subjects),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSubjectList(BuildContext context, List<String> subjects) {
    final width = MediaQuery.of(context).size.width;
    final isWideScreen = width >= 600;
    final crossAxisCount = width >= 1200 ? 3 : width >= 800 ? 2 : 1;
    final padding = isWideScreen ? 20.0 : 16.0;

    if (crossAxisCount == 1) {
      return ListView.builder(
        padding: EdgeInsets.all(padding),
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          return _buildSubjectCard(context, subjects[index]);
        },
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(padding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 80,
      ),
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        return _buildSubjectCard(context, subjects[index], isGrid: true);
      },
    );
  }

  Widget _buildSubjectCard(BuildContext context, String subject, {bool isGrid = false}) {
    return Card(
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SubjectPdfListScreen(
                course: course,
                subject: subject,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                course.gradientColors[0].withOpacity(0.1),
                course.gradientColors[1].withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Subject Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: course.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.book,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Subject Name
                Expanded(
                  child: Text(
                    subject,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fallback widget that shows all PDFs for a course when subjects aren't available
class _FallbackPdfList extends ConsumerWidget {
  final Course course;

  const _FallbackPdfList({required this.course});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final pdfFilesAsync = ref.watch(pdfFilesProvider(course.abbreviation));

    return pdfFilesAsync.when(
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
              onPressed: () => ref.invalidate(pdfFilesProvider(course.abbreviation)),
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
                  'Upload PDFs for ${course.abbreviation} to see them here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pdfFilesProvider(course.abbreviation));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () => _openPdf(context, file),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf,
                            color: Colors.red.shade400,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.fileName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.visibility, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text('${file.viewCount}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                  const SizedBox(width: 12),
                                  Icon(Icons.thumb_up_outlined, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text('${file.likesCount}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
