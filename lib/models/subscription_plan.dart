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
      currency: (json['currency'] as String?) ?? 'INR',
      period: (json['period'] as String?) ?? 'monthly',
      interval: (json['interval'] as num?)?.toInt() ?? 1,
      benefits: (json['benefits'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  double get amount => amountInPaise / 100;

  String get amountLabel {
    final value = amount;
    final valueText = value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);

    if (currency.toUpperCase() == 'INR') {
      return '₹$valueText';
    }

    return '$currency $valueText';
  }

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
}
