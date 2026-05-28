import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/career_guidance_type.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class GuidanceRequestScreen extends ConsumerStatefulWidget {
  const GuidanceRequestScreen({super.key});

  @override
  ConsumerState<GuidanceRequestScreen> createState() =>
      _GuidanceRequestScreenState();
}

class _GuidanceRequestScreenState extends ConsumerState<GuidanceRequestScreen> {
  List<CareerGuidanceType> _types = [];
  bool _loadingTypes = true;
  String? _typesError;

  CareerGuidanceType? _selectedType;
  DateTime? _scheduledAt;
  final _descriptionController = TextEditingController();

  bool _isSubmitting = false;
  String? _activeOrderId;

  late final Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadTypes();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    try {
      final types = await ApiService.getCareerGuidanceTypes();
      if (mounted) {
        setState(() {
          _types = types;
          _loadingTypes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _typesError = e.toString();
          _loadingTypes = false;
        });
      }
    }
  }

  void _showTypePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TypePickerSheet(
        types: _types,
        selected: _selectedType,
        onSelect: (type) {
          setState(() => _selectedType = type);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Select guidance date',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Select guidance time',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  bool get _canSubmit =>
      _selectedType != null &&
      _scheduledAt != null &&
      _descriptionController.text.trim().isNotEmpty &&
      !_isSubmitting;

  Future<void> _payAndBook() async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to request guidance.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final order = await ApiService.createGuidanceOrder(
        userPhone: auth.userPhone,
        typeSlug: _selectedType!.slug,
        scheduledAt: _scheduledAt!,
        description: _descriptionController.text.trim(),
      );

      _activeOrderId = order['orderId'] as String?;

      final options = <String, dynamic>{
        'key': order['keyId'],
        'order_id': order['orderId'],
        'amount': order['amount'],
        'currency': order['currency'] ?? 'INR',
        'name': order['brandName'] ?? 'College Notes',
        'description': '${_selectedType!.name} — Guidance Session',
        'prefill': order['prefill'] ?? {},
        'theme': {'color': order['themeColor'] ?? '#6366f1'},
        'modal': {'confirm_close': true},
        'retry': {'enabled': true, 'max_count': 1},
      };

      _razorpay.open(options);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start payment: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final orderId = _activeOrderId;
    if (orderId == null || !mounted) {
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final result = await ApiService.verifyGuidancePayment(
        orderId: orderId,
        paymentId: response.paymentId!,
        signature: response.signature!,
      );
      if (!mounted) return;
      _showSuccessSheet(result['meetLink'] as String);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment done but booking failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Payment cancelled or failed.'),
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) setState(() => _isSubmitting = false);
  }

  void _showSuccessSheet(String meetLink) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Session Booked!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Your guidance session is scheduled for ${DateFormat('EEE, MMM d • h:mm a').format(_scheduledAt!)}.',
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      meetLink,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: meetLink));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Link copied!')),
                      );
                    },
                    tooltip: 'Copy link',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.video_call_rounded),
                label: const Text('Open Google Meet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => launchUrl(
                  Uri.parse(meetLink),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Guidance'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Book a 1:1 session',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Select a guidance type, pick a time, and describe what you need help with.',
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 28),

            // Career type dropdown
            if (_loadingTypes)
              const Center(child: CircularProgressIndicator())
            else if (_typesError != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Could not load guidance types. Please try again.',
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _loadingTypes = true;
                          _typesError = null;
                        });
                        _loadTypes();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_types.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No guidance types available yet. Please check back later.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _selectedType != null
                        ? const Color(0xFF6366f1).withValues(alpha: 0.4)
                        : Colors.grey.shade200,
                  ),
                ),
                child: InkWell(
                  onTap: _showTypePicker,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366f1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.category_rounded,
                            color: Color(0xFF6366f1),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Guidance Type',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedType == null
                                    ? 'Tap to select'
                                    : _selectedType!.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: _selectedType == null
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                  color: _selectedType == null
                                      ? Colors.grey.shade400
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedType != null)
                          Text(
                            _selectedType!.formattedPrice,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6366f1),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Date & Time picker card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFF10B981),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date & Time',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _scheduledAt == null
                                  ? 'Tap to select'
                                  : DateFormat('EEE, MMM d yyyy • h:mm a')
                                      .format(_scheduledAt!),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: _scheduledAt == null
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                                color: _scheduledAt == null
                                    ? Colors.grey.shade400
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Description card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 5,
                  maxLength: 1000,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'What do you want guidance on?',
                    border: InputBorder.none,
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.payment_rounded),
                label: Text(
                  _isSubmitting
                      ? 'Processing…'
                      : _selectedType != null
                          ? 'Pay ${_selectedType!.formattedPrice} & Book'
                          : 'Select a type to continue',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canSubmit
                      ? const Color(0xFF10B981)
                      : Colors.grey.shade300,
                  foregroundColor: _canSubmit ? Colors.white : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _canSubmit ? _payAndBook : null,
              ),
            ),

            if (!auth.isLoggedIn) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'You must be logged in to book a session.',
                  style: TextStyle(color: Colors.red.shade400, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypePickerSheet extends StatelessWidget {
  const _TypePickerSheet({
    required this.types,
    required this.selected,
    required this.onSelect,
  });

  final List<CareerGuidanceType> types;
  final CareerGuidanceType? selected;
  final void Function(CareerGuidanceType) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Select Guidance Type',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Type list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              shrinkWrap: true,
              itemCount: types.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final type = types[i];
                final isSelected = selected?.slug == type.slug;
                return GestureDetector(
                  onTap: () => onSelect(type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6366f1).withValues(alpha: 0.06)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6366f1)
                            : Colors.grey.shade200,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isSelected
                                      ? const Color(0xFF6366f1)
                                      : Colors.black87,
                                ),
                              ),
                              if (type.description != null &&
                                  type.description!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  type.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              type.formattedPrice,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isSelected
                                    ? const Color(0xFF6366f1)
                                    : Colors.black87,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 4),
                              const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF6366f1), size: 18),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
