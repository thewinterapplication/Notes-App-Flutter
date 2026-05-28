class CareerGuidanceType {
  final String slug;
  final String name;
  final String? description;
  final int priceInPaise;

  const CareerGuidanceType({
    required this.slug,
    required this.name,
    this.description,
    required this.priceInPaise,
  });

  factory CareerGuidanceType.fromJson(Map<String, dynamic> json) {
    return CareerGuidanceType(
      slug: (json['slug'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      priceInPaise: (json['priceInPaise'] as num?)?.toInt() ?? 0,
    );
  }

  double get price => priceInPaise / 100;

  String get formattedPrice {
    final value = price;
    final text = value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '₹$text';
  }

  String get dropdownLabel => '$name — $formattedPrice';
}
