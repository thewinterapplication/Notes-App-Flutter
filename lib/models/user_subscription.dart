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

    final payload = _resolvePayload(json);

    return UserSubscription(
      status: _asString(payload['status']) ?? 'none',
      planCode: _asString(payload['planCode']),
      planId: _asString(payload['planId']),
      subscriptionId: _asString(payload['subscriptionId']),
      shortUrl: _asString(payload['shortUrl']),
      customerId: _asString(payload['customerId']),
      lastPaymentId: _asString(payload['lastPaymentId']),
      lastPaymentMethod: _asString(payload['lastPaymentMethod']),
      currentStart: _parseDate(payload['currentStart']),
      currentEnd: _parseDate(payload['currentEnd']),
      chargeAt: _parseDate(payload['chargeAt']),
      startAt: _parseDate(payload['startAt']),
      endAt: _parseDate(payload['endAt']),
      endedAt: _parseDate(payload['endedAt']),
      expireBy: _parseDate(payload['expireBy']),
      paidCount: _asInt(payload['paidCount']) ?? 0,
      remainingCount: _asInt(payload['remainingCount']),
      totalCount: _asInt(payload['totalCount']),
      customerNotify: payload['customerNotify'] as bool? ?? true,
      notes: ((payload['notes'] as Map?) ?? const {}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      lastWebhookEvent: _asString(payload['lastWebhookEvent']),
      lastWebhookEventId: _asString(payload['lastWebhookEventId']),
      lastWebhookReceivedAt: _parseDate(payload['lastWebhookReceivedAt']),
      lastSignatureVerifiedAt: _parseDate(payload['lastSignatureVerifiedAt']),
      cancelAtCycleEnd: payload['cancelAtCycleEnd'] as bool? ?? false,
      updatedAt: _parseDate(payload['updatedAt']),
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

  static Map<String, dynamic> _resolvePayload(Map<String, dynamic> json) {
    final candidates = <Map<String, dynamic>>[
      json,
      if (_asMap(json['_doc']) != null) _asMap(json['_doc'])!,
      if (_asMap(json[r'$__parent']) != null &&
          _asMap(_asMap(json[r'$__parent'])!['subscription']) != null)
        _asMap(_asMap(json[r'$__parent'])!['subscription'])!,
      if (_asMap(json['subscription']) != null) _asMap(json['subscription'])!,
    ];

    var bestCandidate = json;
    var bestScore = _scorePayload(json);

    for (final candidate in candidates.skip(1)) {
      final score = _scorePayload(candidate);
      if (score > bestScore) {
        bestCandidate = candidate;
        bestScore = score;
      }
    }

    return bestCandidate;
  }

  static int _scorePayload(Map<String, dynamic> json) {
    var score = 0;

    final status = _asString(json['status']);
    if (status != null && status != 'none') {
      score += 4;
    }

    if (_asString(json['subscriptionId']) != null) {
      score += 4;
    }

    if (_asString(json['planCode']) != null) {
      score += 3;
    }

    if (_asString(json['planId']) != null) {
      score += 2;
    }

    if (_parseDate(json['currentEnd']) != null ||
        _parseDate(json['chargeAt']) != null ||
        _parseDate(json['startAt']) != null) {
      score += 2;
    }

    if (_asInt(json['remainingCount']) != null) {
      score += 1;
    }

    if (_asInt(json['totalCount']) != null) {
      score += 1;
    }

    if ((json['notes'] as Map?)?.isNotEmpty ?? false) {
      score += 1;
    }

    return score;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  static String? _asString(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') {
      return null;
    }

    return text;
  }

  static int? _asInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    if (value is Map && value.containsKey(r'$date')) {
      return _parseDate(value[r'$date']);
    }

    return DateTime.tryParse(value.toString());
  }
}
