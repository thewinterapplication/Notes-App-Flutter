import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/subscription_checkout_session.dart';
import '../models/subscription_plan.dart';
import '../models/user_subscription.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/api_service.dart';
import 'auth/login_page.dart';
import 'legal_links_screen.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  late final Razorpay _razorpay;
  SubscriptionCheckoutSession? _activeSession;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    Future.microtask(() async {
      await ref.read(subscriptionProvider.notifier).loadPlans();
      final phone = ref.read(authProvider).userPhone;
      if (phone.isNotEmpty) {
        await ref
            .read(subscriptionProvider.notifier)
            .refreshSubscription(phone);
      }
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    developer.log(
      '[Checkout] Payment success: paymentId=${response.paymentId}',
      name: 'subscription',
    );
    final authState = ref.read(authProvider);
    final session = _activeSession;

    if (session == null || authState.userPhone.isEmpty) {
      developer.log(
        '[Checkout] Missing session or phone, skipping verify',
        name: 'subscription',
      );
      return;
    }

    if ((response.paymentId ?? '').isEmpty ||
        (response.signature ?? '').isEmpty) {
      await ref
          .read(subscriptionProvider.notifier)
          .refreshSubscription(authState.userPhone);
      if (!mounted) return;
      _showSnackBar(
        'Payment completed. Waiting for final confirmation from Razorpay.',
        backgroundColor: const Color(0xFF2563EB),
      );
      return;
    }

    final result = await ref
        .read(subscriptionProvider.notifier)
        .verifyPayment(
          phone: authState.userPhone,
          subscriptionId: session.subscriptionId,
          paymentId: response.paymentId!,
          signature: response.signature!,
        );

    if (!mounted) return;
    _showSnackBar(
      result['success'] == true
          ? (result['message'] as String? ??
                'Subscription activated successfully.')
          : (result['message'] as String? ?? 'Verification failed.'),
      backgroundColor: result['success'] == true
          ? const Color(0xFF059669)
          : const Color(0xFFDC2626),
    );
    if (result['success'] == true) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handlePaymentError(PaymentFailureResponse response) async {
    developer.log(
      '[Checkout] Payment error: code=${response.code}, message=${response.message}',
      name: 'subscription',
    );
    final phone = ref.read(authProvider).userPhone;
    if (phone.isNotEmpty) {
      await ref.read(subscriptionProvider.notifier).refreshSubscription(phone);
    }

    if (!mounted) return;

    final message = response.message?.trim().isNotEmpty == true
        ? response.message!.trim()
        : 'Payment was not completed.';

    _showSnackBar(
      message,
      backgroundColor: response.code == Razorpay.PAYMENT_CANCELLED
          ? const Color(0xFF7C3AED)
          : const Color(0xFFDC2626),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showSnackBar(
      '${response.walletName ?? 'External wallet'} selected.',
      backgroundColor: const Color(0xFF2563EB),
    );
  }

  void _showSnackBar(String message, {required Color backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  Future<void> _startCheckout() async {
    final authState = ref.read(authProvider);
    if (!authState.isLoggedIn) {
      _showLoginSheet();
      return;
    }

    final result = await ref
        .read(subscriptionProvider.notifier)
        .startCheckout(phone: authState.userPhone);

    if (!mounted) return;

    if (result['success'] != true || result['checkout'] == null) {
      final failureMessage =
          (result['message'] as String?)?.trim().isNotEmpty == true
          ? (result['message'] as String).trim()
          : 'Unable to start secure checkout right now.';
      _showSnackBar(failureMessage, backgroundColor: const Color(0xFFDC2626));
      return;
    }

    final checkout = result['checkout'] as SubscriptionCheckoutSession;
    _activeSession = checkout;

    developer.log(
      '[Checkout] Session ready: subscriptionId=${checkout.subscriptionId}, keyId=${checkout.keyId}',
      name: 'subscription',
    );

    if (!(Platform.isAndroid || Platform.isIOS)) {
      developer.log(
        '[Checkout] Non-mobile platform, using shortUrl fallback',
        name: 'subscription',
      );
      await _openShortUrlFallback(checkout);
      return;
    }

    final options = {
      'key': checkout.keyId,
      'subscription_id': checkout.subscriptionId,
      'name': checkout.brandName,
      'description': checkout.description,
      'prefill': {'name': checkout.customerName, 'contact': checkout.contact},
      'notes': checkout.notes,
      'theme': {'color': checkout.themeColor},
      'readonly': {'contact': true, 'name': true},
      'modal': {'confirm_close': true},
      'retry': {'enabled': true, 'max_count': 1},
    };

    developer.log(
      '[Checkout] Opening Razorpay with options: $options',
      name: 'subscription',
    );

    try {
      _razorpay.open(options);
    } catch (e) {
      developer.log(
        '[Checkout] Razorpay.open() failed: $e, using shortUrl fallback',
        name: 'subscription',
      );
      await _openShortUrlFallback(checkout);
    }
  }

  Future<void> _openShortUrlFallback(
    SubscriptionCheckoutSession session,
  ) async {
    final shortUrl = session.shortUrl;
    if (shortUrl == null || shortUrl.isEmpty) {
      _showSnackBar(
        'Checkout could not be opened on this device.',
        backgroundColor: const Color(0xFFDC2626),
      );
      return;
    }

    final uri = Uri.tryParse(shortUrl);
    if (uri == null) {
      _showSnackBar(
        'Checkout link is invalid.',
        backgroundColor: const Color(0xFFDC2626),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      _showSnackBar(
        'Unable to open the secure checkout link.',
        backgroundColor: const Color(0xFFDC2626),
      );
    }
  }

  Future<void> _openLegalPage(String path, String label) async {
    final uri = Uri.parse('${ApiService.baseUrl}$path');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      _showSnackBar(
        'Unable to open $label right now.',
        backgroundColor: const Color(0xFFDC2626),
      );
    }
  }

  Future<void> _openPoliciesScreen() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const LegalLinksScreen()));
  }

  Future<void> _showLoginSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Login required',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We need your account to create and manage the Razorpay subscription safely.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      this.context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Login to continue',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCancelSheet(UserSubscription subscription) async {
    if (!subscription.hasSubscriptionId) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Manage renewal',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to stop the membership billing.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              const SizedBox(height: 18),
              _CancelOption(
                title: 'End after current cycle',
                subtitle:
                    'Recommended. Access continues till the current paid period ends.',
                accent: const Color(0xFF0F766E),
                onTap: () => _cancelSubscription(cancelAtCycleEnd: true),
              ),
              const SizedBox(height: 12),
              _CancelOption(
                title: 'Cancel immediately',
                subtitle:
                    'Stops right away if Razorpay accepts an immediate cancellation.',
                accent: const Color(0xFFDC2626),
                onTap: () => _cancelSubscription(cancelAtCycleEnd: false),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cancelSubscription({required bool cancelAtCycleEnd}) async {
    Navigator.pop(context);
    final phone = ref.read(authProvider).userPhone;
    if (phone.isEmpty) return;

    final result = await ref
        .read(subscriptionProvider.notifier)
        .cancelSubscription(phone: phone, cancelAtCycleEnd: cancelAtCycleEnd);

    if (!mounted) return;
    _showSnackBar(
      result['message'] as String? ?? 'Unable to update subscription.',
      backgroundColor: result['success'] == true
          ? const Color(0xFF059669)
          : const Color(0xFFDC2626),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not available';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final subscriptionState = ref.watch(subscriptionProvider);
    final selectedPlan = subscriptionState.selectedPlan;

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
                      'Membership',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => ref
                        .read(subscriptionProvider.notifier)
                        .loadPlans(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref
                      .read(subscriptionProvider.notifier)
                      .loadPlans(forceRefresh: true);
                  if (authState.userPhone.isNotEmpty) {
                    await ref
                        .read(subscriptionProvider.notifier)
                        .refreshSubscription(authState.userPhone);
                  }
                },
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    selectedPlan != null ? 220 : 188,
                  ),
                  children: [
                    _HeroCard(authState: authState, formatDate: _formatDate),
                    const SizedBox(height: 18),
                    if (authState.subscription.hasSubscriptionId)
                      _LiveStatusCard(
                        subscription: authState.subscription,
                        formatDate: _formatDate,
                        onManageTap:
                            authState.subscription.isLive ||
                                authState.subscription.isEntitled
                            ? () => _showCancelSheet(authState.subscription)
                            : null,
                      ),
                    if (authState.subscription.hasSubscriptionId)
                      const SizedBox(height: 18),
                    const Text(
                      'Choose your plan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Razorpay Checkout opens on the next step and shows supported UPI apps, cards and other methods based on your account and device.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (subscriptionState.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (subscriptionState.plans.isEmpty)
                      _EmptyPlansCard(
                        message:
                            subscriptionState.errorMessage ??
                            'No subscription plans are configured yet.',
                      )
                    else
                      ...subscriptionState.plans.map(
                        (plan) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _PlanCard(
                            plan: plan,
                            isSelected: selectedPlan?.code == plan.code,
                            onTap: () => ref
                                .read(subscriptionProvider.notifier)
                                .selectPlan(plan.code),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    _InfoStrip(
                      icon: Icons.payments_outlined,
                      title: 'UPI app handoff',
                      subtitle:
                          'On supported Android and iOS devices, Razorpay can surface installed apps like PhonePe, Google Pay and Paytm for a direct handoff.',
                    ),
                    const SizedBox(height: 12),
                    const _InfoStrip(
                      icon: Icons.verified_user_outlined,
                      title: 'Backend verified',
                      subtitle:
                          'We verify the Razorpay payment signature on the server and keep webhooks as the source of truth for your membership state.',
                    ),
                    if (subscriptionState.errorMessage != null &&
                        subscriptionState.errorMessage!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          subscriptionState.errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
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
      bottomSheet: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -8),
              ),
            ],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectedPlan != null)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedPlan.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${selectedPlan.amountLabel} / ${selectedPlan.billingLabel}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              if (selectedPlan != null) const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      subscriptionState.isProcessing ||
                          subscriptionState.isLoading ||
                          selectedPlan == null
                      ? null
                      : _startCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: subscriptionState.isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : Text(
                          authState.isLoggedIn
                              ? 'Continue to secure checkout'
                              : 'Login to subscribe',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              _CheckoutLegalFooter(
                onTermsTap: () => _openLegalPage(
                  '/terms-and-conditions',
                  'Terms and Conditions',
                ),
                onPrivacyTap: () =>
                    _openLegalPage('/privacy-policy', 'Privacy Policy'),
                onPoliciesTap: _openPoliciesScreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.authState, required this.formatDate});

  final AuthState authState;
  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    final hasPlan = authState.subscription.isEntitled;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -10,
            child: Icon(
              hasPlan
                  ? Icons.workspace_premium_rounded
                  : Icons.flash_on_rounded,
              size: 110,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasPlan
                      ? authState.subscription.displayStatus
                      : 'Razorpay Membership',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasPlan
                    ? 'You are covered.'
                    : 'Fast recurring payments, handled right.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                hasPlan
                    ? 'Renewal health, payment retries and membership status stay synced with the backend.'
                    : 'Create the subscription on your backend, collect the mandate with Razorpay Checkout, and let webhooks keep the app state accurate.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              if (hasPlan) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Next billing',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatDate(authState.subscription.nextBillingAt),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveStatusCard extends StatelessWidget {
  const _LiveStatusCard({
    required this.subscription,
    required this.formatDate,
    this.onManageTap,
  });

  final UserSubscription subscription;
  final String Function(DateTime?) formatDate;
  final VoidCallback? onManageTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF0F766E)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subscription.displayStatus,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (onManageTap != null)
                TextButton(
                  onPressed: onManageTap,
                  child: const Text(
                    'Manage',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatusMetric(
                label: 'Subscription ID',
                value: subscription.subscriptionId ?? 'NA',
              ),
              _StatusMetric(
                label: 'Next billing',
                value: formatDate(subscription.nextBillingAt),
              ),
              _StatusMetric(
                label: 'Last method',
                value: subscription.lastPaymentMethod ?? 'Pending',
              ),
              _StatusMetric(
                label: 'Renewal mode',
                value: subscription.cancelAtCycleEnd
                    ? 'Stops this cycle'
                    : 'Auto renew',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool isSelected;
  final VoidCallback onTap;

  Color _hexToColor(String hex) {
    final sanitized = hex.replaceAll('#', '');
    final normalized = sanitized.length == 6 ? 'FF$sanitized' : sanitized;
    return Color(int.parse(normalized, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final accent = _hexToColor(plan.accentColor);
    final surface = _hexToColor(plan.surfaceColor);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isSelected ? accent : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    plan.badge,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? accent : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? accent : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              plan.title,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              plan.subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.amountLabel,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '/ ${plan.periodLabel}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              plan.billingLabel,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...plan.benefits.map(
              (benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(Icons.check_rounded, size: 15, color: accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        benefit,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
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
    );
  }
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF111827)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutLegalFooter extends StatelessWidget {
  const _CheckoutLegalFooter({
    required this.onTermsTap,
    required this.onPrivacyTap,
    required this.onPoliciesTap,
  });

  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;
  final VoidCallback onPoliciesTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'By continuing, you accept the membership billing terms and can review privacy and support policies anytime.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 0,
            children: [
              _FooterLink(label: 'Terms', onTap: onTermsTap),
              _FooterLink(label: 'Privacy', onTap: onPrivacyTap),
              _FooterLink(
                label: 'Policies & support',
                onTap: onPoliciesTap,
                icon: Icons.arrow_forward_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF1D4ED8),
        padding: const EdgeInsets.symmetric(vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFF1D4ED8),
            ),
          ),
          if (icon != null) ...[const SizedBox(width: 4), Icon(icon, size: 14)],
        ],
      ),
    );
  }
}

class _EmptyPlansCard extends StatelessWidget {
  const _EmptyPlansCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.payments_outlined,
            size: 42,
            color: Color(0xFF6B7280),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelOption extends StatelessWidget {
  const _CancelOption({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
            color: accent.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.schedule_rounded, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
