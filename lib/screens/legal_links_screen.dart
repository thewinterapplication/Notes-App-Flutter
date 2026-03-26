import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';

class LegalLinksScreen extends StatelessWidget {
  const LegalLinksScreen({super.key});

  static const List<_LegalLinkItem> _links = [
    _LegalLinkItem(
      title: 'Terms and Conditions',
      subtitle: 'Membership rules, access scope and billing terms.',
      path: '/terms-and-conditions',
      icon: Icons.description_outlined,
    ),
    _LegalLinkItem(
      title: 'Privacy Policy',
      subtitle: 'What data is collected and how it is handled.',
      path: '/privacy-policy',
      icon: Icons.privacy_tip_outlined,
    ),
    _LegalLinkItem(
      title: 'Shipping Policy',
      subtitle: 'Digital delivery expectations for purchases and access.',
      path: '/shipping-policy',
      icon: Icons.local_shipping_outlined,
    ),
    _LegalLinkItem(
      title: 'Contact Us',
      subtitle: 'Support and business contact details.',
      path: '/contact-us',
      icon: Icons.support_agent_outlined,
    ),
    _LegalLinkItem(
      title: 'Cancellation and Refunds',
      subtitle: 'How renewals, cancellations and refunds are handled.',
      path: '/cancellation-and-refunds',
      icon: Icons.assignment_return_outlined,
    ),
  ];

  Future<void> _openLegalPage(
    BuildContext context,
    _LegalLinkItem item,
  ) async {
    final uri = Uri.parse('${ApiService.baseUrl}${item.path}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!context.mounted || launched) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to open ${item.title} right now.'),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Policies & support',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _HeroBadge(),
                        SizedBox(height: 14),
                        Text(
                          'Legal pages, without crowding checkout.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Open the latest published terms, privacy, shipping and support pages from one place. Each page launches in your browser so it stays synced with the backend copy.',
                          style: TextStyle(
                            color: Color(0xFFD1D5DB),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  ..._links.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LegalLinkCard(
                        item: item,
                        onTap: () => _openLegalPage(context, item),
                      ),
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

class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Always available',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LegalLinkCard extends StatelessWidget {
  const _LegalLinkCard({
    required this.item,
    required this.onTap,
  });

  final _LegalLinkItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  item.icon,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalLinkItem {
  const _LegalLinkItem({
    required this.title,
    required this.subtitle,
    required this.path,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String path;
  final IconData icon;
}
