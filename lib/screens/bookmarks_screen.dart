import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course.dart';
import '../models/pdf_file.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'auth/login_page.dart';
import 'pdf_detail_screen.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  List<PdfFile> _bookmarkedFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final authState = ref.read(authProvider);

    if (!authState.isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }

    final favouriteIds = authState.favourites;

    if (favouriteIds.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // Fetch all files across subjects and filter by favourite IDs
    final List<PdfFile> allFiles = [];
    for (final course in Course.allCourses) {
      final result = await ApiService.getFilesBySubject(course.abbreviation);
      if (result['success'] == true) {
        allFiles.addAll(result['files'] as List<PdfFile>);
      }
    }

    final bookmarked = allFiles.where((f) => favouriteIds.contains(f.id)).toList();

    if (mounted) {
      setState(() {
        _bookmarkedFiles = bookmarked;
        _isLoading = false;
      });
    }
  }

  Course _getCourseForFile(PdfFile file) {
    return Course.allCourses.firstWhere(
      (c) => c.abbreviation.toLowerCase() == file.subject.toLowerCase(),
      orElse: () => Course.allCourses.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final favourites = authState.favourites;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D7D9A),
        title: const Text('Bookmarks', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !authState.isLoggedIn
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Login to see bookmarks',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D7D9A),
                        ),
                        child: const Text('Login', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : favourites.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No bookmarks yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Bookmark PDFs to find them here',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBookmarks,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bookmarkedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _bookmarkedFiles[index];
                      if (!favourites.contains(file.id)) return const SizedBox.shrink();
                      final course = _getCourseForFile(file);
                      return _buildBookmarkItem(file, course);
                    },
                  ),
                ),
    );
  }

  Widget _buildBookmarkItem(PdfFile file, Course course) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfDetailScreen(pdfFile: file, course: course),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: course.gradientColors,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName.replaceAll('.pdf', ''),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.fullName,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.visibility, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text('${file.viewCount}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        const SizedBox(width: 12),
                        Icon(Icons.favorite, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text('${file.likesCount}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
              ),
              // Remove bookmark
              IconButton(
                icon: const Icon(Icons.bookmark, color: Color(0xFFFF9800)),
                onPressed: () {
                  ref.read(authProvider.notifier).toggleFavourite(file.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
