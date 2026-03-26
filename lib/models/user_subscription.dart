class UserSubscription {
  final String status;
  final String? planCode;
  final String? planId;
  final String? subscriptionId;
  final String? shortUrl;
  final String? customerId;
  final String? lastPaymentId;
  final String? lastPaymentMethod;
  final DateTime? currentStart;
  final DateTime? currentEnd;
  final DateTime? chargeAt;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? endedAt;
  final DateTime? expireBy;
  final int paidCount;
  final int? remainingCount;
  final int? totalCount;
  final bool customerNotify;
  final Map<String, String> notes;
  final String? lastWebhookEvent;
  final String? lastWebhookEventId;
  final DateTime? lastWebhookReceivedAt;
  final DateTime? lastSignatureVerifiedAt;
  final bool cancelAtCycleEnd;
  final DateTime? updatedAt;

  const UserSubscription({
    this.status = 'none',
    this.planCode,
    this.planId,
    this.subscriptionId,
    this.shortUrl,
    this.customerId,
    this.lastPaymentId,
    this.lastPaymentMethod,
    this.currentStart,
    this.currentEnd,
    this.chargeAt,
    this.startAt,
    this.endAt,
    this.endedAt,
    this.expireBy,
    this.paidCount = 0,
    this.remainingCount,
    this.totalCount,
    this.customerNotify = true,
    this.notes = const {},
    this.lastWebhookEvent,
    this.lastWebhookEventId,
    this.lastWebhookReceivedAt,
    this.lastSignatureVerifiedAt,
    this.cancelAtCycleEnd = false,
    this.updatedAt,
  });

  factory UserSubscription.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UserSubscription();
    }

    return UserSubscription(
      status: (json['status'] as String?) ?? 'none',
      planCode: json['planCode'] as String?,
      planId: json['planId'] as String?,
      subscriptionId: json['subscriptionId'] as String?,
      shortUrl: json['shortUrl'] as String?,
      customerId: json['customerId'] as String?,
      lastPaymentId: json['lastPaymentId'] as String?,
      lastPaymentMethod: json['lastPaymentMethod'] as String?,
      currentStart: _parseDate(json['currentStart']),
      currentEnd: _parseDate(json['currentEnd']),
      chargeAt: _parseDate(json['chargeAt']),
      startAt: _parseDate(json['startAt']),
      endAt: _parseDate(json['endAt']),
      endedAt: _parseDate(json['endedAt']),
      expireBy: _parseDate(json['expireBy']),
      paidCount: (json['paidCount'] as num?)?.toInt() ?? 0,
      remainingCount: (json['remainingCount'] as num?)?.toInt(),
      totalCount: (json['totalCount'] as num?)?.toInt(),
      customerNotify: json['customerNotify'] as bool? ?? true,
      notes: ((json['notes'] as Map?) ?? const {}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      lastWebhookEvent: json['lastWebhookEvent'] as String?,
      lastWebhookEventId: json['lastWebhookEventId'] as String?,
      lastWebhookReceivedAt: _parseDate(json['lastWebhookReceivedAt']),
      lastSignatureVerifiedAt: _parseDate(json['lastSignatureVerifiedAt']),
      cancelAtCycleEnd: json['cancelAtCycleEnd'] as bool? ?? false,
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  UserSubscription copyWith({
    String? status,
    String? planCode,
    String? planId,
    String? subscriptionId,
    String? shortUrl,
    String? customerId,
    String? lastPaymentId,
    String? lastPaymentMethod,
    DateTime? currentStart,
    DateTime? currentEnd,
    DateTime? chargeAt,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? endedAt,
    DateTime? expireBy,
    int? paidCount,
    int? remainingCount,
    int? totalCount,
    bool? customerNotify,
    Map<String, String>? notes,
    String? lastWebhookEvent,
    String? lastWebhookEventId,
    DateTime? lastWebhookReceivedAt,
    DateTime? lastSignatureVerifiedAt,
    bool? cancelAtCycleEnd,
    DateTime? updatedAt,
  }) {
    return UserSubscription(
      status: status ?? this.status,
      planCode: planCode ?? this.planCode,
      planId: planId ?? this.planId,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      shortUrl: shortUrl ?? this.shortUrl,
      customerId: customerId ?? this.customerId,
      lastPaymentId: lastPaymentId ?? this.lastPaymentId,
      lastPaymentMethod: lastPaymentMethod ?? this.lastPaymentMethod,
      currentStart: currentStart ?? this.currentStart,
      currentEnd: currentEnd ?? this.currentEnd,
      chargeAt: chargeAt ?? this.chargeAt,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      endedAt: endedAt ?? this.endedAt,
      expireBy: expireBy ?? this.expireBy,
      paidCount: paidCount ?? this.paidCount,
      remainingCount: remainingCount ?? this.remainingCount,
      totalCount: totalCount ?? this.totalCount,
      customerNotify: customerNotify ?? this.customerNotify,
      notes: notes ?? this.notes,
      lastWebhookEvent: lastWebhookEvent ?? this.lastWebhookEvent,
      lastWebhookEventId: lastWebhookEventId ?? this.lastWebhookEventId,
      lastWebhookReceivedAt:
          lastWebhookReceivedAt ?? this.lastWebhookReceivedAt,
      lastSignatureVerifiedAt:
          lastSignatureVerifiedAt ?? this.lastSignatureVerifiedAt,
      cancelAtCycleEnd: cancelAtCycleEnd ?? this.cancelAtCycleEnd,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasSubscriptionId => (subscriptionId ?? '').isNotEmpty;

  bool get isLive => const {
    'created',
    'authenticated',
    'active',
    'pending',
    'halted',
    'paused',
  }.contains(status);

  bool get isEntitled {
    if (const {
      'authenticated',
      'active',
      'pending',
      'halted',
      'paused',
    }.contains(status)) {
      return true;
    }

    if (status == 'cancelled' &&
        currentEnd != null &&
        currentEnd!.isAfter(DateTime.now())) {
      return true;
    }

    return false;
  }

  String get displayStatus {
    switch (status) {
      case 'created':
        return 'Pending payment';
      case 'authenticated':
        return 'Authenticated';
      case 'active':
        return 'Active';
      case 'pending':
        return 'Payment retry';
      case 'halted':
        return 'Action needed';
      case 'paused':
        return 'Paused';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      case 'expired':
        return 'Expired';
      default:
        return 'No plan';
    }
  }

  DateTime? get nextBillingAt => currentEnd ?? chargeAt;

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }
}
