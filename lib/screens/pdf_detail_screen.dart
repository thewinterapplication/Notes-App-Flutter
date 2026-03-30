import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course.dart';
import '../models/pdf_file.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'auth/login_page.dart';
import 'pdf_viewer_screen.dart';
import 'subscription_screen.dart';

/// PDF Detail Screen - Shows PDF info before opening viewer
class PdfDetailScreen extends ConsumerStatefulWidget {
  final PdfFile pdfFile;
  final Course course;

  const PdfDetailScreen({
    super.key,
    required this.pdfFile,
    required this.course,
  });

  @override
  ConsumerState<PdfDetailScreen> createState() => _PdfDetailScreenState();
}

class _PdfDetailScreenState extends ConsumerState<PdfDetailScreen> {
  PdfFile get pdfFile => widget.pdfFile;
  Course get course => widget.course;
  bool _isCheckingAccess = false;

  Future<void> _openPdfViewer(AuthState authState) async {
    if (_isCheckingAccess) {
      return;
    }

    if (!authState.isLoggedIn) {
      _showSubscriptionDialog(isLoggedIn: false);
      return;
    }

    var latestAuthState = authState;
    if (!latestAuthState.hasActiveSubscription) {
      setState(() {
        _isCheckingAccess = true;
      });

      try {
        await ref.read(authProvider.notifier).refreshProfile();
      } finally {
        if (mounted) {
          setState(() {
            _isCheckingAccess = false;
          });
        }
      }

      if (!mounted) {
        return;
      }

      latestAuthState = ref.read(authProvider);
      if (!latestAuthState.hasActiveSubscription) {
        _showSubscriptionDialog(isLoggedIn: true);
        return;
      }
    }

    ApiService.incrementViewCount(pdfFile.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          pdfUrl: pdfFile.fileUrl,
          userPhone: latestAuthState.userPhone,
        ),
      ),
    );
  }

  void _showSubscriptionDialog({required bool isLoggedIn}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isLoggedIn ? 'Subscription Required' : 'Login Required'),
        content: Text(
          isLoggedIn
              ? 'You need an active subscription to open this PDF.'
              : 'Please login first, then purchase a subscription to open this PDF.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                this.context,
                MaterialPageRoute(
                  builder: (context) => isLoggedIn
                      ? const SubscriptionScreen()
                      : const LoginPage(),
                ),
              );
            },
            child: Text(isLoggedIn ? 'View Plans' : 'Login'),
          ),
        ],
      ),
    );
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('Please login to bookmark PDFs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isFav = authState.isFavourite(pdfFile.id);
    final canOpenPdf = authState.hasActiveSubscription;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Teal top section (covers status bar + nav + card area)
            Container(
              color: const Color(0xFF2D7D9A),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Navigation row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isFav ? Icons.bookmark : Icons.bookmark_border,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (authState.isLoggedIn) {
                                  ref.read(authProvider.notifier).toggleFavourite(pdfFile.id);
                                } else {
                                  _showLoginDialog();
                                }
                              },
                            ),
                            IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => Container(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.share),
                                      title: const Text('Share'),
                                      onTap: () => Navigator.pop(context),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.report_outlined),
                                      title: const Text('Report'),
                                      onTap: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                          ],
                        ),
                      ],
                    ),
                    // Thumbnail + info content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        height: 180,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Info content on the right side
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 156),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pdfFile.fileName.replaceAll('.pdf', ''),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.person_outline, size: 16, color: Colors.white.withOpacity(0.7)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Author',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Thumbnail on the left, in front
                            Positioned(
                              top: 0,
                              left: 0,
                              child: GestureDetector(
                                onTap: () => _openPdfViewer(authState),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 140,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F0E8),
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.25),
                                            blurRadius: 10,
                                            offset: const Offset(3, 4),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          // Book spine shadow
                                          Positioned(
                                            left: 0,
                                            top: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 12,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.black.withOpacity(0.08),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                                borderRadius: const BorderRadius.only(
                                                  topLeft: Radius.circular(6),
                                                  bottomLeft: Radius.circular(6),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Page lines
                                          Positioned(
                                            left: 20,
                                            right: 20,
                                            top: 30,
                                            child: Column(
                                              children: List.generate(5, (i) => Padding(
                                                padding: const EdgeInsets.only(bottom: 6),
                                                child: Container(
                                                  height: 2,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(1),
                                                  ),
                                                ),
                                              )),
                                            ),
                                          ),
                                          // Center book icon
                                          Center(
                                            child: Container(
                                              width: 64,
                                              height: 64,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: course.gradientColors,
                                                ),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: const Icon(
                                                Icons.auto_stories_rounded,
                                                color: Colors.white,
                                                size: 32,
                                              ),
                                            ),
                                          ),
                                          // Open button at bottom
                                          Positioned(
                                            left: 20,
                                            right: 20,
                                            bottom: 16,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 7),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: course.gradientColors,
                                                ),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  _isCheckingAccess
                                                      ? 'Checking...'
                                                      : canOpenPdf
                                                      ? 'Open'
                                                      : authState.isLoggedIn
                                                      ? 'Subscribe to open'
                                                      : 'Login to open',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Rating badge
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '4.${(pdfFile.likesCount % 10)}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notes for ${pdfFile.fileName.replaceAll('.pdf', '')} - ${course.abbreviation}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last Updated: ${_formatDate(pdfFile.createdAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.expand_more),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(Icons.visibility_outlined, '${pdfFile.viewCount}', 'Views'),
                  _buildStatItem(Icons.description_outlined, '-', 'Pages'),
                  _buildSaveButton(authState),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            // Author section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: course.gradientColors[0].withOpacity(0.2),
                    child: Icon(
                      Icons.person,
                      color: course.gradientColors[0],
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          course.abbreviation,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Topics section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Topics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTopicChip(course.abbreviation, course.gradientColors[0]),
                      if (pdfFile.subject != 'uncategorized')
                        _buildTopicChip(pdfFile.subject, course.gradientColors[1]),
                      _buildTopicChip('PDF', Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.grey.shade700),
        const SizedBox(height: 4),
        if (value.isNotEmpty)
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(AuthState authState) {
    final isSaved = authState.isFavourite(pdfFile.id);
    return GestureDetector(
      onTap: () {
        if (authState.isLoggedIn) {
          ref.read(authProvider.notifier).toggleFavourite(pdfFile.id);
        } else {
          _showLoginDialog();
        }
      },
      child: Column(
        children: [
          Icon(
            isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
            size: 24,
            color: isSaved ? course.gradientColors[0] : Colors.grey.shade700,
          ),
          const SizedBox(height: 4),
          Text(
            isSaved ? 'Saved' : 'Save',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSaved ? FontWeight.w600 : FontWeight.w400,
              color: isSaved ? course.gradientColors[0] : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
