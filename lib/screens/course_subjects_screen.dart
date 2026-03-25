import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course.dart';
import '../providers/pdf_provider.dart';
import 'subject_pdf_list_screen.dart';

/// Screen to display subjects for a specific course
/// Falls back to showing all PDFs if subjects endpoint is unavailable
class CourseSubjectsScreen extends ConsumerStatefulWidget {
  final Course course;
  final bool isPYQ;
  final bool isPlacement;

  const CourseSubjectsScreen({super.key, required this.course, this.isPYQ = false, this.isPlacement = false});

  @override
  ConsumerState<CourseSubjectsScreen> createState() => _CourseSubjectsScreenState();
}

class _CourseSubjectsScreenState extends ConsumerState<CourseSubjectsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<List<Color>> _tileGradients = [
    [Color(0xFFE91E8C), Color(0xFFC2185B)], // Pink
    [Color(0xFF00838F), Color(0xFF006064)], // Teal
    [Color(0xFFE85D04), Color(0xFFD62828)], // Orange-red
    [Color(0xFF388E3C), Color(0xFF1B5E20)], // Green
    [Color(0xFF7B1FA2), Color(0xFF4A148C)], // Purple
    [Color(0xFF1565C0), Color(0xFF0D47A1)], // Blue
    [Color(0xFFFF6F00), Color(0xFFE65100)], // Amber
    [Color(0xFF00897B), Color(0xFF004D40)], // Dark teal
    [Color(0xFFC62828), Color(0xFFB71C1C)], // Red
    [Color(0xFF4527A0), Color(0xFF311B92)], // Deep purple
  ];

  Course get course => widget.course;
  bool get isPYQ => widget.isPYQ;
  bool get isPlacement => widget.isPlacement;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(
      isPlacement
          ? placementSubjectsProvider(course.abbreviation)
          : isPYQ
              ? pyqSubjectsProvider(course.abbreviation)
              : subjectsProvider(course.abbreviation),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Styled header with search
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
                              course.abbreviation,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              course.fullName,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
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
                        hintText: 'Search subjects...',
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
              child: subjectsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No subjects found',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => ref.invalidate(
                          isPlacement
                              ? placementSubjectsProvider(course.abbreviation)
                              : isPYQ
                                  ? pyqSubjectsProvider(course.abbreviation)
                                  : subjectsProvider(course.abbreviation),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (subjects) {
                  if (subjects.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No subjects found',
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  }

                  final filtered = _searchQuery.isEmpty
                      ? subjects
                      : subjects.where((s) =>
                          s.toLowerCase().contains(_searchQuery.toLowerCase())
                        ).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No subjects found',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(
                        isPlacement
                            ? placementSubjectsProvider(course.abbreviation)
                            : isPYQ
                                ? pyqSubjectsProvider(course.abbreviation)
                                : subjectsProvider(course.abbreviation),
                      );
                    },
                    child: _buildSubjectList(context, filtered),
                  );
                },
              ),
            ),
          ],
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
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildSubjectCard(context, subjects[index], index),
          );
        },
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(padding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 120,
      ),
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        return _buildSubjectCard(context, subjects[index], index);
      },
    );
  }

  Widget _buildSubjectCard(BuildContext context, String subject, int index) {
    final gradientColors = _tileGradients[index % _tileGradients.length];
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubjectPdfListScreen(
              course: course,
              subject: subject,
              isPYQ: isPYQ,
              isPlacement: isPlacement,
            ),
          ),
        );
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background watermark icon
            Positioned(
              right: -10,
              top: 0,
              bottom: 0,
              child: Center(
                child: Icon(
                  Icons.book,
                  size: 100,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ),
            // Content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.book, color: Colors.white, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      subject,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

