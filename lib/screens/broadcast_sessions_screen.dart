import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/broadcast_session.dart';
import '../services/api_service.dart';

class BroadcastSessionsBody extends StatefulWidget {
  const BroadcastSessionsBody({super.key});

  @override
  State<BroadcastSessionsBody> createState() => _BroadcastSessionsBodyState();
}

class _BroadcastSessionsBodyState extends State<BroadcastSessionsBody> {
  List<BroadcastSession> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final sessions = await ApiService.getBroadcastSessions();
      if (mounted) setState(() { _sessions = sessions; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text('Could not load sessions', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
              child: const Text('Retry'),
            ),
          ]),
        ),
      );
    }
    if (_sessions.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async { setState(() { _loading = true; _error = null; }); await _load(); },
        child: ListView(children: [
          SizedBox(height: 320, child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.live_tv_rounded, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No upcoming sessions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              Text('Check back soon for admin-hosted group sessions.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
            ]),
          )),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: () async { setState(() { _loading = true; _error = null; }); await _load(); },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sessions.length,
        itemBuilder: (_, i) => _BroadcastCard(session: _sessions[i]),
      ),
    );
  }
}

class BroadcastSessionsScreen extends StatefulWidget {
  const BroadcastSessionsScreen({super.key});

  @override
  State<BroadcastSessionsScreen> createState() =>
      _BroadcastSessionsScreenState();
}

class _BroadcastSessionsScreenState extends State<BroadcastSessionsScreen> {
  List<BroadcastSession> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sessions = await ApiService.getBroadcastSessions();
      if (mounted) setState(() { _sessions = sessions; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Sessions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Admin-hosted group sessions',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              setState(() { _loading = true; _error = null; });
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
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
    if (_sessions.isEmpty) {
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
                    Icon(Icons.live_tv_rounded,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      'No upcoming sessions',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Check back soon for admin-hosted group sessions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
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
        itemCount: _sessions.length,
        itemBuilder: (_, i) => _BroadcastCard(session: _sessions[i]),
      ),
    );
  }
}

class _BroadcastCard extends StatelessWidget {
  const _BroadcastCard({required this.session});
  final BroadcastSession session;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isLive = session.scheduledAt.isBefore(now) &&
        now.isBefore(session.scheduledAt
            .add(Duration(minutes: session.durationMinutes)));
    final dateLabel =
        DateFormat('EEE, MMM d yyyy • h:mm a').format(session.scheduledAt.toLocal());
    final durationLabel = '${session.durationMinutes} min';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isLive
              ? const Color(0xFFEF4444).withValues(alpha: 0.4)
              : const Color(0xFF7C3AED).withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    session.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                if (isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle,
                            size: 7, color: Color(0xFFEF4444)),
                        SizedBox(width: 4),
                        Text('LIVE',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
            if (session.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                session.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13, height: 1.4),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(dateLabel,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(width: 12),
                Icon(Icons.timer_outlined,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(durationLabel,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(
                    isLive ? Icons.play_circle_filled_rounded : Icons.video_call_rounded,
                    size: 18),
                label: Text(isLive ? 'Join Now — Live' : 'Join Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLive
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: session.meetLink.isNotEmpty
                    ? () => launchUrl(
                          Uri.parse(session.meetLink),
                          mode: LaunchMode.externalApplication,
                        )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
