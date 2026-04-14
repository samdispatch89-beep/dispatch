class Company {
  final String id;
  final String name;
  final double feePercentage;
  final String billingEmail;
  final String billingTerms;
  final bool active;
  final String notes;

  const Company({
    required this.id,
    required this.name,
    required this.feePercentage,
    required this.billingEmail,
    required this.billingTerms,
    required this.active,
    required this.notes,
  });

  factory Company.fromMap(String id, Map<String, dynamic> map) {
    return Company(
      id: id,
      name: (map['name'] ?? '').toString(),
      feePercentage: (map['feePercentage'] ?? 0).toDouble(),
      billingEmail: (map['billingEmail'] ?? '').toString(),
      billingTerms: (map['billingTerms'] ?? '').toString(),
      active: map['active'] != false,
      notes: (map['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'feePercentage': feePercentage,
      'billingEmail': billingEmail,
      'billingTerms': billingTerms,
      'active': active,
      'notes': notes,
    };
  }
}
