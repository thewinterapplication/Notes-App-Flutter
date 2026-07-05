class SubscriptionPlan {
  final String code;
  final String planId;
  final String title;
  final String subtitle;
  final String description;
  final String badge;
  final String accentColor;
  final String surfaceColor;
  final bool popular;
  final int amountInPaise;
  final int? introductoryAmountInPaise;
  final int? introductoryPeriodDays;
  final int? recurringAmountInPaise;
  final String currency;
  final String period;
  final int interval;
  final List<String> benefits;

  const SubscriptionPlan({
    required this.code,
    required this.planId,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.badge,
    required this.accentColor,
    required this.surfaceColor,
    required this.popular,
    required this.amountInPaise,
    this.introductoryAmountInPaise,
    this.introductoryPeriodDays,
    this.recurringAmountInPaise,
    required this.currency,
    required this.period,
    required this.interval,
    required this.benefits,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      code: (json['code'] as String?) ?? '',
      planId: (json['planId'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      badge: (json['badge'] as String?) ?? '',
      accentColor: (json['accentColor'] as String?) ?? '#FF6A3D',
      surfaceColor: (json['surfaceColor'] as String?) ?? '#FFF1EA',
      popular: json['popular'] as bool? ?? false,
      amountInPaise: (json['amountInPaise'] as num?)?.toInt() ?? 0,
      introductoryAmountInPaise: (json['introductoryAmountInPaise'] as num?)
          ?.toInt(),
      introductoryPeriodDays: (json['introductoryPeriodDays'] as num?)?.toInt(),
      recurringAmountInPaise: (json['recurringAmountInPaise'] as num?)?.toInt(),
      currency: (json['currency'] as String?) ?? 'INR',
      period: (json['period'] as String?) ?? 'monthly',
      interval: (json['interval'] as num?)?.toInt() ?? 1,
      benefits: (json['benefits'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  double get amount => amountInPaise / 100;

  bool get hasIntroductoryOffer =>
      introductoryAmountInPaise != null && introductoryAmountInPaise! > 0;

  /// Returns the plan that carries an introductory offer (falling back to the
  /// first plan, or null when the list is empty). Used to render live intro
  /// pricing in promotional surfaces like the hero card and home banner.
  static SubscriptionPlan? introOfferFrom(List<SubscriptionPlan> plans) {
    if (plans.isEmpty) return null;
    for (final plan in plans) {
      if (plan.hasIntroductoryOffer) return plan;
    }
    return plans.first;
  }

  String _formatAmount(int amount) {
    final value = amount / 100;
    final valueText = value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);

    if (currency.toUpperCase() == 'INR') {
      return '\u20B9$valueText';
    }

    return '$currency $valueText';
  }

  String get amountLabel => _formatAmount(amountInPaise);

  String get introductoryAmountLabel =>
      _formatAmount(introductoryAmountInPaise ?? amountInPaise);

  String get recurringAmountLabel =>
      _formatAmount(recurringAmountInPaise ?? amountInPaise);

  String get periodLabel {
    switch (period) {
      case 'daily':
        return interval <= 1 ? 'day' : '$interval days';
      case 'weekly':
        return interval <= 1 ? 'week' : '$interval weeks';
      case 'yearly':
        return interval <= 1 ? 'year' : '$interval years';
      default:
        return interval <= 1 ? 'month' : '$interval months';
    }
  }

  String get billingLabel => 'Billed every $periodLabel';

  String get introductoryBillingLabel => hasIntroductoryOffer
      ? 'Then $recurringAmountLabel every $periodLabel'
      : billingLabel;

  /// Human label for the intro period, e.g. "first day", "first week",
  /// "first month", or "first 10 days" — derived from [introductoryPeriodDays].
  String get introductoryPeriodLabel {
    final days = introductoryPeriodDays;
    if (days == null || days <= 0) return 'first month';
    if (days == 1) return 'first day';
    if (days % 30 == 0) {
      final months = days ~/ 30;
      return months == 1 ? 'first month' : 'first $months months';
    }
    if (days % 7 == 0) {
      final weeks = days ~/ 7;
      return weeks == 1 ? 'first week' : 'first $weeks weeks';
    }
    return 'first $days days';
  }

  /// [introductoryPeriodLabel] with its first letter capitalized, e.g.
  /// "First week", "First month" — for use at the start of a sentence.
  String get introductoryPeriodLabelCapitalized {
    final label = introductoryPeriodLabel;
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }

  /// Short pill/badge label for the intro period, e.g. "Intro Week",
  /// "Intro Month", "Intro 2 Weeks" — derived from [introductoryPeriodLabel].
  String get introBadgeLabel {
    final noun = introductoryPeriodLabel.replaceFirst('first ', '');
    final titleCased = noun
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
    return 'Intro $titleCased';
  }

  /// Short marketing headline for the intro offer, e.g. "First month for ₹1.".
  String get introOfferHeadline {
    final label = introductoryPeriodLabel;
    final capitalized = '${label[0].toUpperCase()}${label.substring(1)}';
    return '$capitalized for $introductoryAmountLabel.';
  }

  /// One-line pitch describing the intro offer and the price it renews at.
  String get introOfferSummary =>
      'Start with $introductoryAmountLabel for the $introductoryPeriodLabel, '
      'then $recurringAmountLabel/$periodLabel afterwards.';

  /// One-line copy for the regular (no intro offer) membership.
  String get regularSummary =>
      'Continue with the regular $recurringAmountLabel/$periodLabel '
      'membership through Razorpay Checkout.';
}
