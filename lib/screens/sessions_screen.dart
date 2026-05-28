import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'broadcast_sessions_screen.dart';
import 'guidance_request_screen.dart';
import 'my_guidance_sessions_screen.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              const Expanded(
                child: TabBarView(
                  children: [
                    _GuidanceTab(),
                    BroadcastSessionsBody(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.maybePop(context),
              ),
              const Text(
                'Sessions',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              'Book 1-on-1 guidance or join live group classes',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle:
                TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: [
              Tab(text: '1 vs 1'),
              Tab(text: 'Live'),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuidanceTab extends ConsumerStatefulWidget {
  const _GuidanceTab();

  @override
  ConsumerState<_GuidanceTab> createState() => _GuidanceTabState();
}

class _GuidanceTabState extends ConsumerState<_GuidanceTab>
    with SingleTickerProviderStateMixin {
  late final TabController _innerTab;
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _innerTab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _innerTab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final phone = ref.read(authProvider).userPhone;
    try {
      final sessions =
          await ApiService.getMyGuidanceSessions(userPhone: phone);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Book session card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const GuidanceRequestScreen()),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.support_agent_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Book a 1-on-1 Session',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Get personalised career guidance',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
        ),

        // My Bookings header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 8, 0),
          child: Row(
            children: [
              const Text(
                'My Bookings',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2D3E50)),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.refresh_rounded,
                    size: 20, color: Colors.grey.shade500),
                onPressed: () {
                  setState(() { _loading = true; _error = null; });
                  _load();
                },
              ),
            ],
          ),
        ),

        // Upcoming / Past tab bar
        TabBar(
          controller: _innerTab,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6366F1),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Upcoming'), Tab(text: 'Past')],
        ),

        // Session list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : TabBarView(
                      controller: _innerTab,
                      children: [
                        _buildList(_upcoming, isUpcoming: true),
                        _buildList(_past, isUpcoming: false),
                      ],
                    ),
        ),
      ],
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
        child: ListView(children: [
          SizedBox(
            height: 280,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    isUpcoming
                        ? Icons.upcoming_rounded
                        : Icons.history_rounded,
                    size: 56,
                    color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                    isUpcoming
                        ? 'No upcoming bookings'
                        : 'No past bookings',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
                if (isUpcoming) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Tap "Book a 1-on-1 Session" to get started',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ]),
            ),
          ),
        ]),
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
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
          ]),
        ),
      );
}
