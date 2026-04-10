import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'item_detail_screen.dart';

class UpskillScreen extends StatefulWidget {
  const UpskillScreen({super.key});

  @override
  State<UpskillScreen> createState() => _UpskillScreenState();
}

class _UpskillScreenState extends State<UpskillScreen> {
  List<Map<String, dynamic>> _upskills = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUpskills();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredUpskills {
    if (_searchQuery.isEmpty) return _upskills;
    return _upskills
        .where((u) => (u['upskillName'] ?? '')
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Future<void> _fetchUpskills() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http
          .get(Uri.parse('${ApiService.baseUrl}/api/upskills'))
          .timeout(ApiService.requestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _upskills = List<Map<String, dynamic>>.from(data['upskills']);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load upskills';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Unable to connect. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Column(
        children: [
          // Header — matches Courses/Placements
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
                const Text(
                  'Upskill',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Courses to boost your skills',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
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
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search upskills...',
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
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 46),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: Colors.grey.shade400,
                                size: 20,
                              ),
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

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off_rounded,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(_error!,
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 16)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                                onPressed: _fetchUpskills,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _filteredUpskills.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.school_outlined,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No upskills found'
                                        : 'No courses available right now',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchUpskills,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 16),
                              itemCount: _filteredUpskills.length,
                              itemBuilder: (context, index) =>
                                  _buildUpskillCard(_filteredUpskills[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpskillCard(Map<String, dynamic> upskill) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemDetailScreen(
              title: upskill['upskillName'] ?? 'Course Details',
              imageUrl: upskill['imageUrl'] ?? '',
              description: upskill['description'] ?? '',
              actionUrl: upskill['upskillUrl'] ?? '',
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2D3E50).withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFF2D3E50).withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name on top
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text(
                upskill['upskillName'] ?? '',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3E50),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Image
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  upskill['imageUrl'] ?? '',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.broken_image_rounded,
                        size: 48, color: Colors.grey.shade400),
                  ),
                  loadingBuilder: (_, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 180,
                      color: Colors.grey.shade100,
                      child:
                          const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
            ),

            // Let's Go >> on bottom right
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    "Let's Go",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE91E8C),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.double_arrow_rounded,
                    size: 18,
                    color: const Color(0xFFE91E8C),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
