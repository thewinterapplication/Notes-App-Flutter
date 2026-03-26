class SubscriptionCheckoutSession {
  final String keyId;
  final String brandName;
  final String themeColor;
  final String subscriptionId;
  final String? shortUrl;
  final String planCode;
  final String planName;
  final String description;
  final String customerName;
  final String contact;
  final Map<String, dynamic> notes;

  const SubscriptionCheckoutSession({
    required this.keyId,
    required this.brandName,
    required this.themeColor,
    required this.subscriptionId,
    this.shortUrl,
    required this.planCode,
    required this.planName,
    required this.description,
    required this.customerName,
    required this.contact,
    required this.notes,
  });

  factory SubscriptionCheckoutSession.fromJson(Map<String, dynamic> json) {
    return SubscriptionCheckoutSession(
      keyId: (json['keyId'] as String?) ?? '',
      brandName: (json['brandName'] as String?) ?? '',
      themeColor: (json['themeColor'] as String?) ?? '#FF6A3D',
      subscriptionId: (json['subscriptionId'] as String?) ?? '',
      shortUrl: json['shortUrl'] as String?,
      planCode: (json['planCode'] as String?) ?? '',
      planName: (json['planName'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      customerName: (json['customerName'] as String?) ?? '',
      contact: (json['contact'] as String?) ?? '',
      notes: (json['notes'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}
