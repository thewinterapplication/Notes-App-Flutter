import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/course.dart';
import '../constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../providers/pdf_provider.dart';
import '../widgets/subscription_banner.dart';
import 'course_subjects_screen.dart';
import 'bookmarks_screen.dart';
import 'splash_screen.dart';
import 'subscription_screen.dart';
import 'upload_notes_screen.dart';
import 'jobs_screen.dart';
import 'upskill_screen.dart';

/// Home Screen with new wireframe-based design
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _coursesSearchController =
      TextEditingController();
  int _currentNavIndex = 0;
  String _coursesSearchQuery = '';

  @override
  void dispose() {
    _coursesSearchController.dispose();
    super.dispose();
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

  Future<void> _openSubscriptionScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
    );
    ref.read(authProvider.notifier).refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final coursesAsync = ref.watch(availableCoursesProvider);
    final userName = authState.userName.isNotEmpty
        ? authState.userName
        : 'Guest';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5F5),
      drawer: _buildDrawer(context, authState),
      body: SafeArea(
        child: _currentNavIndex == 0
            ? _buildHomeBody(context, userName, coursesAsync)
            : _currentNavIndex == 1
            ? _buildCoursesTab(coursesAsync: coursesAsync)
            : _currentNavIndex == 2
            ? _buildCoursesTab(
                isPlacement: true,
                coursesAsync: ref.watch(availablePlacementCoursesProvider),
              )
            : _currentNavIndex == 3
            ? const JobsScreen()
            : const UpskillScreen(),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHomeBody(
    BuildContext context,
    String userName,
    AsyncValue<List<Course>> coursesAsync,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar with menu and notification
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.menu,
                      color: Color(0xFF2D3E50),
                      size: 24,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showComingSoonDialog('Notifications'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFF2D3E50),
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Welcome Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D3E50), Color(0xFF3D5266)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2D3E50).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello $userName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Welcome to $appName',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          if (!ref.watch(authProvider).hasActiveSubscription)
            SubscriptionBanner(
              subscription: ref.watch(authProvider).subscription,
              onTap: _openSubscriptionScreen,
            ),

          const SizedBox(height: 24),

          // Notes Section
          _buildSectionHeader(
            'Notes',
            onSeeAll: () => setState(() => _currentNavIndex = 1),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: coursesAsync.when(
              data: (courses) => courses.isEmpty
                  ? _buildEmptyCoursesPlaceholder(
                      'No courses available right now',
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: courses.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _buildHorizontalCourseCard(courses[index]),
                        );
                      },
                    ),
              loading: () => _buildSkeletonCards(),
              error: (_, __) => _buildEmptyCoursesPlaceholder(
                'Unable to load courses',
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Placements Section — only shown when courses are available
          ...ref.watch(availablePlacementCoursesProvider).maybeWhen(
            data: (placementCourses) => placementCourses.isEmpty
                ? []
                : [
                    _buildSectionHeader(
                      'Placements',
                      onSeeAll: () => setState(() => _currentNavIndex = 2),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: placementCourses.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _buildHorizontalCourseCard(
                              placementCourses[index],
                              isPlacement: true,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
            orElse: () => [],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3E50),
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text(
                'See All',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFE91E8C),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCourseCard(Course course, {bool isPYQ = false, bool isPlacement = false}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseSubjectsScreen(
              course: course,
              isPYQ: isPYQ,
              isPlacement: isPlacement,
            ),
          ),
        );
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: course.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: course.gradientColors[0].withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background icon
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                isPYQ ? Icons.description_outlined : course.icon,
                size: 80,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPYQ ? Icons.description_outlined : course.icon,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    course.abbreviation,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPYQ ? 'PYQ Papers' : course.fullName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCards() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _SkeletonCard(width: 140, height: 160),
        );
      },
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return _SkeletonCard(width: double.infinity, height: double.infinity);
      },
    );
  }

  void _showSearchBottomSheet(BuildContext context) {
    String searchQuery = '';
    final availableCourses = ref.read(availableCoursesProvider).maybeWhen(
          data: (courses) => courses,
          orElse: () => Course.allCourses,
        );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = availableCourses
                .where(
                  (c) =>
                      c.fullName.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ) ||
                      c.abbreviation.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ),
                )
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => setSheetState(() => searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search courses...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final course = filtered[index];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: course.gradientColors,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              course.icon,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          title: Text(course.fullName),
                          subtitle: Text(course.abbreviation),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CourseSubjectsScreen(course: course),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildComingSoonPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Coming Soon',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This feature is under development',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesTab({
    bool isPYQ = false,
    bool isPlacement = false,
    required AsyncValue<List<Course>> coursesAsync,
  }) {
    final filteredCourses = coursesAsync.whenData(
      (courses) => _coursesSearchQuery.isEmpty
          ? courses
          : courses
              .where(
                (c) =>
                    c.fullName.toLowerCase().contains(
                      _coursesSearchQuery.toLowerCase(),
                    ) ||
                    c.abbreviation.toLowerCase().contains(
                      _coursesSearchQuery.toLowerCase(),
                    ),
              )
              .toList(),
    );

    return Container(
      color: const Color(0xFFF5F5F5),
      child: Column(
        children: [
          // Header with search bar
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D3E50), Color(0xFF3D5266)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2D3E50).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPlacement
                      ? 'Placements'
                      : isPYQ
                      ? 'PYQ Papers'
                      : 'Courses',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPlacement
                      ? 'Placement materials'
                      : isPYQ
                      ? 'Previous year question papers'
                      : 'Find your branch',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
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
                    controller: _coursesSearchController,
                    onChanged: (value) =>
                        setState(() => _coursesSearchQuery = value),
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search courses...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 15,
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 16, right: 8),
                        child: Icon(
                          Icons.search_rounded,
                          color: Color(0xFF2D3E50),
                          size: 22,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 46),
                      suffixIcon: _coursesSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: Colors.grey.shade400,
                                size: 20,
                              ),
                              onPressed: () {
                                _coursesSearchController.clear();
                                setState(() => _coursesSearchQuery = '');
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Course list
          Expanded(
            child: filteredCourses.when(
              data: (courses) => courses.isEmpty
                  ? Center(
                      child: Text(
                        'No courses found',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: courses.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildVerticalCourseCard(
                            courses[index],
                            isPYQ: isPYQ,
                            isPlacement: isPlacement,
                          ),
                        );
                      },
                    ),
              loading: () => _buildSkeletonGrid(),
              error: (_, __) => Center(
                child: Text(
                  'Unable to load courses',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalCourseCard(
    Course course, {
    bool isPYQ = false,
    bool isPlacement = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseSubjectsScreen(
              course: course,
              isPYQ: isPYQ,
              isPlacement: isPlacement,
            ),
          ),
        );
      },
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: course.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: course.gradientColors[0].withOpacity(0.4),
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
                  course.icon,
                  size: 120,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ),
            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(course.icon, color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    course.fullName,
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCoursesPlaceholder(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 0),
              _buildNavItem(Icons.school_rounded, 'Courses', 1),
              _buildNavItem(Icons.work_rounded, 'Placements', 2),
              _buildNavItem(Icons.business_center_rounded, 'Jobs', 3),
              _buildNavItem(Icons.trending_up_rounded, 'Upskill', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentNavIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2D3E50).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF2D3E50)
                  : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? const Color(0xFF2D3E50)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AuthState authState) {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth * 0.68;

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
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A2530),
                    Color(0xFF2D3E50),
                    Color(0xFF3D5266),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                      color: Colors.white.withOpacity(0.15),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authState.userName.isNotEmpty
                        ? authState.userName
                        : 'Guest User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authState.userPhone.isNotEmpty
                        ? '+91 ${authState.userPhone}'
                        : 'Not logged in',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.grey.shade200),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
                children: [
                  _buildDrawerItem(
                    Icons.home_rounded,
                    'Home',
                    const Color(0xFF2196F3),
                    () {
                      Navigator.pop(context);
                      setState(() => _currentNavIndex = 0);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    Icons.bookmark_rounded,
                    'Saved',
                    const Color(0xFFFF9800),
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BookmarksScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    Icons.workspace_premium_rounded,
                    'Membership',
                    const Color(0xFF7C3AED),
                    () {
                      Navigator.pop(context);
                      _openSubscriptionScreen();
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    Icons.upload_file_rounded,
                    'Upload Notes',
                    const Color(0xFF4CAF50),
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UploadNotesScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    Icons.settings_rounded,
                    'Settings',
                    const Color(0xFF9C27B0),
                    () {
                      Navigator.pop(context);
                      _showComingSoonDialog('Settings');
                    },
                  ),
                ],
              ),
            ),

            // Bottom section
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  _buildDrawerItem(
                    Icons.logout_rounded,
                    'Logout',
                    const Color(0xFFF44336),
                    () async {
                      Navigator.pop(context);
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text(
                            'Are you sure you want to logout?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );
                      if (shouldLogout == true) {
                        await ref.read(authProvider.notifier).logout();
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SplashScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    Icons.privacy_tip_rounded,
                    'Privacy Policy',
                    const Color(0xFF2196F3),
                    () {
                      Navigator.pop(context);
                      launchUrl(
                        Uri.parse(
                          'https://notes-app-server-wczw.onrender.com/privacy-policy',
                        ),
                      );
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

  Widget _buildDrawerItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
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
}

class _SkeletonCard extends StatefulWidget {
  final double width;
  final double height;

  const _SkeletonCard({required this.width, required this.height});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment(_animation.value - 1, 0),
          end: Alignment(_animation.value, 0),
          colors: const [
            Color(0xFFE0E0E0),
            Color(0xFFF0F0F0),
            Color(0xFFE0E0E0),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Spacer(),
            Container(
              width: 70,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 50,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
