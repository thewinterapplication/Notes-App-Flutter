import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/course.dart';
import '../providers/auth_provider.dart';
import 'course_subjects_screen.dart';
import 'bookmarks_screen.dart';
import 'splash_screen.dart';

/// Home Screen with course exploration
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Use Course model with static course list
  List<Course> get courses => Course.allCourses;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Course> get filteredCourses {
    if (_searchQuery.isEmpty) {
      return courses;
    }
    return courses
        .where((course) =>
            course.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            course.abbreviation.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _showComingSoonDialog(String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.construction_rounded, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            const Text('Coming Soon'),
          ],
        ),
        content: Text(
          '$featureName is currently under development and will be available soon!',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Responsive helper methods
  double _getScreenWidth(BuildContext context) => MediaQuery.of(context).size.width;

  bool _isTablet(BuildContext context) => _getScreenWidth(context) >= 600;
  bool _isDesktop(BuildContext context) => _getScreenWidth(context) >= 1024;

  int _getGridCrossAxisCount(BuildContext context) {
    final width = _getScreenWidth(context);
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }

  double _getCardAspectRatio(BuildContext context) {
    final width = _getScreenWidth(context);
    if (width >= 1200) return 1.4;
    if (width >= 900) return 1.3;
    if (width >= 600) return 1.2;
    return 1.8;
  }

  double _getPadding(BuildContext context) {
    if (_isDesktop(context)) return 32;
    if (_isTablet(context)) return 24;
    return 16;
  }

  double _getIconSize(BuildContext context) {
    if (_isDesktop(context)) return 48;
    if (_isTablet(context)) return 40;
    return 32;
  }

  double _getTitleFontSize(BuildContext context) {
    if (_isDesktop(context)) return 20;
    if (_isTablet(context)) return 18;
    return 16;
  }

  double _getTabFontSize(BuildContext context) {
    if (_isDesktop(context)) return 16;
    if (_isTablet(context)) return 15;
    return 14;
  }

  double _getBackgroundIconSize(BuildContext context) {
    if (_isDesktop(context)) return 180;
    if (_isTablet(context)) return 150;
    return 120;
  }

  @override
  Widget build(BuildContext context) {
    final tabFontSize = _getTabFontSize(context);
    final authState = ref.watch(authProvider);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D3E50),
        elevation: 0,
        automaticallyImplyLeading: !_isSearching,
        leading: _isSearching
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
        leadingWidth: _isSearching ? 16 : null,
        title: _isSearching
            ? Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _updateSearchQuery,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search branches...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.6)),
                  ),
                ),
              )
            : Text(
                'Home',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: _isTablet(context) ? 22 : 20,
                ),
              ),
        centerTitle: !_isSearching,
        actions: [
          _isSearching
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _stopSearch,
                )
              : IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: _startSearch,
                ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: tabFontSize),
          unselectedLabelStyle: TextStyle(fontSize: tabFontSize),
          tabs: const [
            Tab(text: 'EXPLORE'),
            Tab(text: 'STUDY TABLE'),
          ],
        ),
      ),
      drawer: _buildResponsiveDrawer(context, authState),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExploreTab(),
          _buildStudyTableTab(),
        ],
      ),
    );
  }

  Widget _buildResponsiveDrawer(BuildContext context, AuthState authState) {
    final screenWidth = _getScreenWidth(context);
    final drawerWidth = _isDesktop(context)
        ? screenWidth * 0.18
        : _isTablet(context)
            ? screenWidth * 0.36
            : screenWidth * 0.68;

    return SizedBox(
      width: drawerWidth,
      child: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            // Profile Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 24,
                bottom: 24,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2530), Color(0xFF2D3E50), Color(0xFF3D5266)],
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final profileSize = constraints.maxWidth * 0.9;
                  return Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.9,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Picture
                          Container(
                            width: profileSize,
                            height: profileSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                              color: Colors.white.withOpacity(0.15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.person,
                              size: profileSize * 0.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Profile Name
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              authState.userName.isNotEmpty ? authState.userName : 'Guest User',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _isTablet(context) ? 22 : 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Phone
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              authState.userPhone.isNotEmpty ? '+91 ${authState.userPhone}' : 'Not logged in',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: _isTablet(context) ? 14 : 12,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Divider
            Container(
              height: 1,
              color: Colors.grey.shade200,
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                children: [
                  _buildStyledMenuItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    iconColor: const Color(0xFF2196F3),
                    bgColor: const Color(0xFF2196F3).withOpacity(0.1),
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 8),
                  _buildStyledMenuItem(
                    icon: Icons.bookmark_rounded,
                    label: 'Bookmarks',
                    iconColor: const Color(0xFFFF9800),
                    bgColor: const Color(0xFFFF9800).withOpacity(0.1),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BookmarksScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildStyledMenuItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    iconColor: const Color(0xFF9C27B0),
                    bgColor: const Color(0xFF9C27B0).withOpacity(0.1),
                    onTap: () {
                      Navigator.pop(context);
                      _showComingSoonDialog('Settings');
                    },
                  ),
                ],
              ),
            ),

            // Login & Logout Buttons at Bottom
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  _buildStyledMenuItem(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    iconColor: const Color(0xFFF44336),
                    bgColor: const Color(0xFFF44336).withOpacity(0.1),
                    onTap: () async {
                      Navigator.pop(context);
                      // Show confirmation dialog
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );

                      if (shouldLogout == true) {
                        // Use Riverpod to logout
                        await ref.read(authProvider.notifier).logout();

                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const SplashScreen()),
                            (route) => false,
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildStyledMenuItem(
                    icon: Icons.privacy_tip_rounded,
                    label: 'Privacy Policy',
                    iconColor: const Color(0xFF2196F3),
                    bgColor: const Color(0xFF2196F3).withOpacity(0.1),
                    onTap: () {
                      Navigator.pop(context);
                      launchUrl(Uri.parse('https://notes-app-server-wczw.onrender.com/privacy-policy'));
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledMenuItem({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: _isTablet(context) ? 24 : 22,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: _isTablet(context) ? 17 : 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExploreTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _getGridCrossAxisCount(context);
        final padding = _getPadding(context);
        final results = filteredCourses;

        // Show no results message
        if (results.isEmpty) {
          return Container(
            color: const Color(0xFFF5F5F5),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: _isTablet(context) ? 80 : 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No courses found',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: _isTablet(context) ? 20 : 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try a different search term',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: _isTablet(context) ? 16 : 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Use ListView for single column, GridView for multi-column
        if (crossAxisCount == 1) {
          return Container(
            color: const Color(0xFFF5F5F5),
            child: ListView.builder(
              padding: EdgeInsets.all(padding),
              itemCount: results.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(bottom: padding * 0.75),
                  child: SizedBox(
                    height: 140,
                    child: _buildCourseCard(results[index], 140),
                  ),
                );
              },
            ),
          );
        }

        return Container(
          color: const Color(0xFFF5F5F5),
          child: GridView.builder(
            padding: EdgeInsets.all(padding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: _getCardAspectRatio(context),
              crossAxisSpacing: padding * 0.75,
              mainAxisSpacing: padding * 0.75,
            ),
            itemCount: results.length,
            itemBuilder: (context, index) {
              return _buildCourseCard(results[index], null);
            },
          ),
        );
      },
    );
  }

  Widget _buildCourseCard(Course course, double? fixedHeight) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = _getIconSize(context);
        final titleFontSize = _getTitleFontSize(context);
        final bgIconSize = _getBackgroundIconSize(context);
        final padding = _getPadding(context);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_isTablet(context) ? 16 : 12),
            gradient: LinearGradient(
              colors: course.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: course.gradientColors[0].withOpacity(0.4),
                blurRadius: _isTablet(context) ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(_isTablet(context) ? 16 : 12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CourseSubjectsScreen(course: course),
                  ),
                );
              },
              child: Stack(
                children: [
                  // Background pattern
                  Positioned(
                    right: -10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Icon(
                        course.icon,
                        size: bgIconSize,
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                  ),
                  // Content - centered icon and text
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            course.icon,
                            color: Colors.white,
                            size: iconSize,
                          ),
                          SizedBox(height: padding * 0.5),
                          Text(
                            course.fullName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleFontSize,
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
          ),
        );
      },
    );
  }

  Widget _buildStudyTableTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: const Color(0xFFF5F5F5),
          child: Center(
            child: Text(
              'Study Table Coming Soon',
              style: TextStyle(
                color: Colors.grey,
                fontSize: _isDesktop(context) ? 24 : _isTablet(context) ? 20 : 18,
              ),
            ),
          ),
        );
      },
    );
  }
}
