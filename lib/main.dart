import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:screen_protector/screen_protector.dart';

/// API Service to connect to server
class ApiService {
  // Single source of truth - use machine IP for all platforms
  static const String baseUrl = 'http://192.168.1.46:3000';

  static Future<Map<String, dynamic>> login(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> register(String name, String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'phone': phone}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Send OTP to phone number
  static Future<Map<String, dynamic>> sendOTP(String phone) async {
    try {
      // Add country code for India if not present
      final phoneWithCode = phone.startsWith('91') ? phone : '91$phone';

      final response = await http.post(
        Uri.parse('$baseUrl/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneWithCode}),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return {'success': true, 'sessionId': data['sessionId']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to send OTP'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Verify OTP
  static Future<Map<String, dynamic>> verifyOTP(String sessionId, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sessionId': sessionId, 'otp': otp}),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Invalid OTP'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Fetch PDF files by subject/course abbreviation
  static Future<Map<String, dynamic>> getFilesBySubject(String subject) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/files/subject/${Uri.encodeComponent(subject)}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = (data['files'] as List)
            .map((json) => PdfFile.fromJson(json))
            .toList();
        return {'success': true, 'files': files};
      } else {
        return {'success': false, 'message': 'Failed to fetch files'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}

void main() {
  runApp(const NotesApp());
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const SplashScreen(),
    );
  }
}

/// Splash Screen - checks authentication and navigates accordingly
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 2000));

    final prefs = await SharedPreferences.getInstance();
    final userPhone = prefs.getString('userPhone');
    final userName = prefs.getString('userName');

    if (!mounted) return;

    if (userPhone != null && userPhone.isNotEmpty && userName != null && userName.isNotEmpty) {
      // User is authenticated, go to home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      // User not authenticated, go to login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A2530), Color(0xFF2D3E50), Color(0xFF3D5266)],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.note_alt_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Notes App',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your Study Companion',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 50),
                    const SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _userName = 'Guest User';
  String _userPhone = '';

  // Use Course model with static course list
  List<Course> get courses => Course.allCourses;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'Guest User';
      _userPhone = prefs.getString('userPhone') ?? '';
    });
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

  // Responsive helper methods
  double _getScreenWidth(BuildContext context) => MediaQuery.of(context).size.width;
  double _getScreenHeight(BuildContext context) => MediaQuery.of(context).size.height;

  bool _isTablet(BuildContext context) => _getScreenWidth(context) >= 600;
  bool _isDesktop(BuildContext context) => _getScreenWidth(context) >= 1024;

  int _getGridCrossAxisCount(BuildContext context) {
    if (_isDesktop(context)) return 3;
    if (_isTablet(context)) return 2;
    return 1;
  }

  double _getCardHeight(BuildContext context) {
    final height = _getScreenHeight(context);
    if (_isDesktop(context)) return height * 0.22;
    if (_isTablet(context)) return height * 0.18;
    return height * 0.15;
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
      drawer: _buildResponsiveDrawer(context),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExploreTab(),
          _buildStudyTableTab(),
        ],
      ),
    );
  }

  Widget _buildResponsiveDrawer(BuildContext context) {
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
                              _userName,
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
                              _userPhone.isNotEmpty ? '+91 $_userPhone' : 'Not logged in',
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
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 8),
                  _buildStyledMenuItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    iconColor: const Color(0xFF9C27B0),
                    bgColor: const Color(0xFF9C27B0).withOpacity(0.1),
                    onTap: () => Navigator.pop(context),
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
                    icon: Icons.login_rounded,
                    label: 'Login',
                    iconColor: const Color(0xFF4CAF50),
                    bgColor: const Color(0xFF4CAF50).withOpacity(0.1),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
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
                        // Clear user data
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('userName');
                        await prefs.remove('userPhone');

                        if (mounted) {
                          // Navigate to splash screen
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const SplashScreen()),
                            (route) => false,
                          );
                        }
                      }
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
        final cardHeight = _getCardHeight(context);
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

        if (crossAxisCount == 1) {
          // Use ListView for mobile
          return Container(
            color: const Color(0xFFF5F5F5),
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
              itemCount: results.length,
              itemBuilder: (context, index) {
                return _buildCourseCard(results[index], cardHeight);
              },
            ),
          );
        } else {
          // Use GridView for tablet/desktop
          return Container(
            color: const Color(0xFFF5F5F5),
            child: GridView.builder(
              padding: EdgeInsets.all(padding),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: _isDesktop(context) ? 2.2 : 2.0,
                crossAxisSpacing: padding,
                mainAxisSpacing: padding,
              ),
              itemCount: results.length,
              itemBuilder: (context, index) {
                return _buildCourseCard(results[index], null);
              },
            ),
          );
        }
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
        final cardHeight = fixedHeight ?? constraints.maxHeight;

        return Container(
          margin: fixedHeight != null ? EdgeInsets.only(bottom: padding) : EdgeInsets.zero,
          height: fixedHeight,
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
                // Navigate to course PDF list
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CoursePdfListScreen(course: course),
                  ),
                );
              },
              child: Stack(
                children: [
                  // Background pattern
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(
                      course.icon,
                      size: bgIconSize,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  // Content
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            course.icon,
                            color: Colors.white,
                            size: iconSize,
                          ),
                          SizedBox(height: cardHeight * 0.08),
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

/// Course model with ID, abbreviation, and full name
class Course {
  final int id;
  final String abbreviation;
  final String fullName;
  final IconData icon;
  final List<Color> gradientColors;

  const Course({
    required this.id,
    required this.abbreviation,
    required this.fullName,
    required this.icon,
    required this.gradientColors,
  });

  static const List<Course> allCourses = [
    Course(
      id: 1,
      abbreviation: 'CSE',
      fullName: 'Computer Science and Engineering',
      icon: Icons.code,
      gradientColors: [Color(0xFFE91E8C), Color(0xFFC2185B)],
    ),
    Course(
      id: 2,
      abbreviation: 'ECE',
      fullName: 'Electronics and Communication Engineering',
      icon: Icons.memory,
      gradientColors: [Color(0xFF00838F), Color(0xFF006064)],
    ),
    Course(
      id: 3,
      abbreviation: 'EEE',
      fullName: 'Electrical and Electronics Engineering',
      icon: Icons.electrical_services,
      gradientColors: [Color(0xFFE85D04), Color(0xFFD62828)],
    ),
    Course(
      id: 4,
      abbreviation: 'CIVIL',
      fullName: 'Civil Engineering',
      icon: Icons.architecture,
      gradientColors: [Color(0xFF388E3C), Color(0xFF1B5E20)],
    ),
    Course(
      id: 5,
      abbreviation: 'MECHANICAL',
      fullName: 'Mechanical Engineering',
      icon: Icons.settings,
      gradientColors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
    ),
  ];
}

/// PDF File model matching backend schema
class PdfFile {
  final String id;
  final String fileName;
  final String subject;
  final String fileUrl;
  final int likesCount;
  final int viewCount;
  final DateTime createdAt;

  PdfFile({
    required this.id,
    required this.fileName,
    required this.subject,
    required this.fileUrl,
    required this.likesCount,
    required this.viewCount,
    required this.createdAt,
  });

  factory PdfFile.fromJson(Map<String, dynamic> json) {
    return PdfFile(
      id: json['_id'] ?? '',
      fileName: json['fileName'] ?? '',
      subject: json['subject'] ?? 'uncategorized',
      fileUrl: json['fileUrl'] ?? '',
      likesCount: json['likesCount'] ?? 0,
      viewCount: json['viewCount'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Screen to display PDF files for a specific course
class CoursePdfListScreen extends StatefulWidget {
  final Course course;

  const CoursePdfListScreen({super.key, required this.course});

  @override
  State<CoursePdfListScreen> createState() => _CoursePdfListScreenState();
}

class _CoursePdfListScreenState extends State<CoursePdfListScreen> {
  List<PdfFile> _files = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFiles();
  }

  Future<void> _fetchFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ApiService.getFilesBySubject(widget.course.abbreviation);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _files = result['files'] as List<PdfFile>;
        } else {
          _error = result['message'];
        }
      });
    }
  }

  void _openPdf(PdfFile file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(pdfUrl: file.fileUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.course.gradientColors[0],
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.course.abbreviation,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.course.fullName,
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
              widget.course.gradientColors[0].withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load files',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchFiles,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No files yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload PDFs for ${widget.course.abbreviation} to see them here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchFiles,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          return _buildFileCard(file);
        },
      ),
    );
  }

  Widget _buildFileCard(PdfFile file) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _openPdf(file),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // PDF Icon
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
              // File Info
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
                        Icon(
                          Icons.visibility,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${file.viewCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.thumb_up_outlined,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${file.likesCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
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
    );
  }
}

/// Fullscreen PDF Viewer - just the PDF with zoom and scroll
class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;

  const PdfViewerScreen({super.key, required this.pdfUrl});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfControllerPinch _pdfController;

  @override
  void initState() {
    super.initState();
    _enableSecureMode();
    _pdfController = PdfControllerPinch(
      document: _loadDocument(),
    );
  }

  Future<void> _enableSecureMode() async {
    await ScreenProtector.preventScreenshotOn();
  }

  Future<void> _disableSecureMode() async {
    await ScreenProtector.preventScreenshotOff();
  }

  Future<PdfDocument> _loadDocument() async {
    final bytes = await http.readBytes(Uri.parse(widget.pdfUrl));
    return PdfDocument.openData(bytes);
  }

  @override
  void dispose() {
    _disableSecureMode();
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: PdfViewPinch(
          controller: _pdfController,
        ),
      ),
    );
  }
}

// Login Page
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A2530), Color(0xFF2D3E50), Color(0xFF3D5266)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.08),

                    // App Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.note_alt_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Welcome Text
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in with your mobile number',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),

                    SizedBox(height: size.height * 0.06),

                    // Login Card - Glass Effect with Shine
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Colors.white.withOpacity(0.1),
                              border: Border.all(
                                width: 1.5,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Mobile Number',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),

                              // Phone Input
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Country Code
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Colors.white.withOpacity(0.3)),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Text(
                                            '🇮🇳',
                                            style: TextStyle(fontSize: 20),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            '+91',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Phone Number Field
                                    Expanded(
                                      child: TextFormField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Enter mobile number',
                                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter mobile number';
                                          }
                                          if (value.length < 10) {
                                            return 'Enter valid mobile number';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Continue Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (_formKey.currentState!.validate()) {
                                      // Send OTP first
                                      final result = await ApiService.sendOTP(_phoneController.text);

                                      if (result['success']) {
                                        if (mounted) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => OTPVerificationScreen(
                                                phoneNumber: _phoneController.text,
                                                sessionId: result['sessionId'],
                                                isRegistration: false,
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(result['message'] ?? 'Failed to send OTP'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.85),
                                    foregroundColor: const Color(0xFF2D3E50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Continue',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) => const RegisterPage(),
                                transitionDuration: Duration.zero,
                                reverseTransitionDuration: Duration.zero,
                              ),
                            );
                          },
                          child: const Text(
                            'Register',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Register Page
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A2530), Color(0xFF2D3E50), Color(0xFF3D5266)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.06),

                    // App Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Create Account Text
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Register with your mobile number',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),

                    SizedBox(height: size.height * 0.04),

                    // Register Card - Glass Effect with Shine
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Colors.white.withOpacity(0.1),
                              border: Border.all(
                                width: 1.5,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name Field
                                const Text(
                                  'Full Name',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  child: TextFormField(
                                    controller: _nameController,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter your full name',
                                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      prefixIcon: Icon(Icons.person_outline, color: Colors.white.withOpacity(0.7)),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your name';
                                      }
                                      return null;
                                    },
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Phone Field
                                const Text(
                                  'Mobile Number',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Country Code
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            right: BorderSide(color: Colors.white.withOpacity(0.3)),
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            Text(
                                              '🇮🇳',
                                              style: TextStyle(fontSize: 20),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              '+91',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Phone Number Field
                                      Expanded(
                                        child: TextFormField(
                                          controller: _phoneController,
                                          keyboardType: TextInputType.phone,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Enter mobile number',
                                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please enter mobile number';
                                            }
                                            if (value.length < 10) {
                                              return 'Enter valid mobile number';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Terms Checkbox
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _agreeToTerms,
                                        onChanged: (value) {
                                          setState(() {
                                            _agreeToTerms = value ?? false;
                                          });
                                        },
                                        activeColor: Colors.white,
                                        checkColor: const Color(0xFF2D3E50),
                                        side: BorderSide(color: Colors.white.withOpacity(0.5)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'I agree to the Terms & Conditions',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // Register Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      if (_formKey.currentState!.validate()) {
                                        if (!_agreeToTerms) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Please agree to Terms & Conditions'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                          return;
                                        }

                                        // Send OTP first
                                        final result = await ApiService.sendOTP(_phoneController.text);

                                        if (result['success']) {
                                          if (mounted) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => OTPVerificationScreen(
                                                  phoneNumber: _phoneController.text,
                                                  sessionId: result['sessionId'],
                                                  name: _nameController.text,
                                                  isRegistration: true,
                                                ),
                                              ),
                                            );
                                          }
                                        } else {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(result['message'] ?? 'Failed to send OTP'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.85),
                                      foregroundColor: const Color(0xFF2D3E50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Register',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
                                transitionDuration: Duration.zero,
                                reverseTransitionDuration: Duration.zero,
                              ),
                            );
                          },
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// OTP Verification Screen
class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String sessionId;
  final String? name; // For registration flow
  final bool isRegistration;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.sessionId,
    this.name,
    this.isRegistration = false,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  late String _currentSessionId;

  @override
  void initState() {
    super.initState();
    _currentSessionId = widget.sessionId;
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otpValue => _otpControllers.map((c) => c.text).join();

  Future<void> _verifyOTP() async {
    if (_otpValue.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter 4-digit OTP'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.verifyOTP(_currentSessionId, _otpValue);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      // OTP verified successfully
      if (widget.isRegistration) {
        // Complete registration
        final regResult = await ApiService.register(widget.name!, widget.phoneNumber);
        if (regResult['success']) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName', widget.name!);
          await prefs.setString('userPhone', widget.phoneNumber);

          if (mounted) {
            // Navigate to HomeScreen and clear all previous routes
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Registration successful!'),
                backgroundColor: Color(0xFF4CAF50),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(regResult['message'] ?? 'Registration failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Complete login
        final loginResult = await ApiService.login(widget.phoneNumber);
        if (loginResult['success']) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userPhone', widget.phoneNumber);
          if (loginResult['data'] != null && loginResult['data']['name'] != null) {
            await prefs.setString('userName', loginResult['data']['name']);
          }

          if (mounted) {
            // Navigate to HomeScreen and clear all previous routes
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login successful!'),
                backgroundColor: Color(0xFF4CAF50),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loginResult['message'] ?? 'Login failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Invalid OTP'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _isResending = true);

    final result = await ApiService.sendOTP(widget.phoneNumber);

    if (!mounted) return;
    setState(() => _isResending = false);

    if (result['success']) {
      _currentSessionId = result['sessionId'];
      // Clear OTP fields
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice call initiated! Listen for OTP'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to resend OTP'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A2530), Color(0xFF2D3E50), Color(0xFF3D5266)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // OTP Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 40),

                  const Text(
                    'Verify OTP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You will receive a call with 4-digit OTP\n+91 ${widget.phoneNumber}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // OTP Input Fields (4 digits for Voice OTP)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(4, (index) {
                      return SizedBox(
                        width: 55,
                        height: 65,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: TextField(
                            controller: _otpControllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty && index < 3) {
                                _focusNodes[index + 1].requestFocus();
                              } else if (value.isEmpty && index > 0) {
                                _focusNodes[index - 1].requestFocus();
                              }
                              if (_otpValue.length == 4) {
                                _verifyOTP();
                              }
                            },
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 40),

                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.85),
                        foregroundColor: const Color(0xFF2D3E50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Verify OTP',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Resend OTP
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the code? ",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: _isResending ? null : _resendOTP,
                        child: Text(
                          _isResending ? 'Sending...' : 'Resend OTP',
                          style: TextStyle(
                            color: _isResending ? Colors.white54 : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
