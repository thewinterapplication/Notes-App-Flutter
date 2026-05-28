import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/resume_template.dart';
import '../services/api_service.dart';
import 'resume_template_detail_screen.dart';

class ResumeTemplatesScreen extends StatefulWidget {
  const ResumeTemplatesScreen({super.key});

  @override
  State<ResumeTemplatesScreen> createState() => _ResumeTemplatesScreenState();
}

class _ResumeTemplatesScreenState extends State<ResumeTemplatesScreen> {
  List<ResumeTemplate> _templates = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final templates = await ApiService.getResumeTemplates();
      if (mounted) setState(() { _templates = templates; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE85D04), Color(0xFFD62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text('Resume Templates',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Download professionally crafted templates',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
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
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text('Could not load templates',
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

    if (_templates.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          setState(() { _loading = true; _error = null; });
          await _load();
        },
        child: ListView(children: [
          SizedBox(
            height: 320,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_rounded,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No templates available yet',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  Text('Check back soon!',
                      style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
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
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        itemCount: _templates.length,
        itemBuilder: (_, i) => _TemplateCard(template: _templates[i]),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});
  final ResumeTemplate template;

  @override
  Widget build(BuildContext context) {
    final isPdf = template.isPdf;
    final badgeColor = isPdf ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
    final gradientColors = isPdf
        ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
        : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResumeTemplateDetailScreen(template: template),
        ),
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail / placeholder
            Expanded(
              child: template.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      template.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _IconPlaceholder(colors: gradientColors, isPdf: isPdf),
                    )
                  : _IconPlaceholder(colors: gradientColors, isPdf: isPdf),
            ),
            // Name + badge
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isPdf ? 'PDF' : 'WORD',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeColor),
                    ),
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

class _IconPlaceholder extends StatelessWidget {
  const _IconPlaceholder({required this.colors, required this.isPdf});
  final List<Color> colors;
  final bool isPdf;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Center(
        child: Icon(
          isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
          color: Colors.white.withValues(alpha: 0.9),
          size: 56,
        ),
      ),
    );
  }
}
