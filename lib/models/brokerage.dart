class Brokerage {
  final String id;
  final String name;
  final String mc;
  final String contact;

  const Brokerage({
    required this.id,
    required this.name,
    required this.mc,
    required this.contact,
  });

  factory Brokerage.fromMap(String id, Map<String, dynamic> map) {
    return Brokerage(
      id: id,
      name: (map['name'] ?? '').toString(),
      mc: (map['mc'] ?? '').toString(),
      contact: (map['contact'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mc': mc,
      'contact': contact,
    };
  }
}
