import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class MyGuidanceSessionsScreen extends ConsumerStatefulWidget {
  const MyGuidanceSessionsScreen({super.key});

  @override
  ConsumerState<MyGuidanceSessionsScreen> createState() =>
      _MyGuidanceSessionsScreenState();
}

class _MyGuidanceSessionsScreenState
    extends ConsumerState<MyGuidanceSessionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final phone = ref.read(authProvider).userPhone;
    try {
      final sessions = await ApiService.getMyGuidanceSessions(userPhone: phone);
      if (mounted) setState(() { _sessions = sessions; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _upcoming {
    final now = DateTime.now();
    return _sessions.where((s) {
      final at = DateTime.tryParse(s['scheduledAt'] as String? ?? '');
      return at != null && at.isAfter(now) && s['status'] != 'cancelled';
    }).toList();
  }

  List<Map<String, dynamic>> get _past {
    final now = DateTime.now();
    return _sessions.where((s) {
      final at = DateTime.tryParse(s['scheduledAt'] as String? ?? '');
      return at == null || at.isBefore(now) || s['status'] == 'cancelled';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Sessions'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() { _loading = true; _error = null; });
              _load();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(_upcoming, isUpcoming: true),
                    _buildList(_past, isUpcoming: false),
                  ],
                ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> sessions,
      {required bool isUpcoming}) {
    if (sessions.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          setState(() { _loading = true; _error = null; });
          await _load();
        },
        child: ListView(
          children: [
            SizedBox(
              height: 320,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUpcoming
                          ? Icons.upcoming_rounded
                          : Icons.history_rounded,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isUpcoming
                          ? 'No upcoming sessions'
                          : 'No past sessions',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600),
                    ),
                    if (isUpcoming) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Book a guidance session to get started.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() { _loading = true; _error = null; });
        await _load();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length,
        itemBuilder: (_, i) =>
            GuidanceSessionCard(session: sessions[i], isUpcoming: isUpcoming),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text('Could not load sessions',
                  style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() { _loading = true; _error = null; });
                  _load();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}

class GuidanceSessionCard extends StatelessWidget {
  const GuidanceSessionCard({super.key, required this.session, required this.isUpcoming});

  final Map<String, dynamic> session;
  final bool isUpcoming;

  @override
  Widget build(BuildContext context) {
    final scheduledAt =
        DateTime.tryParse(session['scheduledAt'] as String? ?? '');
    final meetLink = (session['meetLink'] as String?) ?? '';
    final typeName = session['typeName'] as String?;
    final description = (session['description'] as String?) ?? '';
    final status = (session['status'] as String?) ?? 'scheduled';
    final amountInPaise = (session['amountInPaise'] as num?)?.toInt();

    final dateLabel = scheduledAt != null
        ? DateFormat('EEE, MMM d yyyy • h:mm a').format(scheduledAt.toLocal())
        : '—';

    final statusColor = switch (status) {
      'completed' => const Color(0xFF10B981),
      'cancelled' => Colors.red.shade400,
      _ => const Color(0xFF6366f1),
    };

    final priceLabel = amountInPaise != null
        ? '₹${(amountInPaise / 100).toStringAsFixed(0)}'
        : null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUpcoming
              ? const Color(0xFF10B981).withValues(alpha: 0.35)
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: career type heading (left) + price (right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    typeName ?? 'Guidance Session',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (priceLabel != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    priceLabel,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isUpcoming
                            ? const Color(0xFF10B981)
                            : Colors.grey.shade500),
                  ),
                ],
              ],
            ),

            // Description
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13, height: 1.4),
              ),
            ],

            const SizedBox(height: 10),

            // Row 2: time (left) + status badge (right)
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  dateLabel,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            // Join Now — upcoming only
            if (meetLink.isNotEmpty && isUpcoming) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.video_call_rounded, size: 18),
                  label: const Text('Join Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => launchUrl(
                    Uri.parse(meetLink),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
