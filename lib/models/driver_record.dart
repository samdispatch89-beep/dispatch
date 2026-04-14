class DriverRecord {
  final String id;
  final String name;
  final String truckNumber;
  final String phone;

  const DriverRecord({
    required this.id,
    required this.name,
    required this.truckNumber,
    required this.phone,
  });

  factory DriverRecord.fromMap(String id, Map<String, dynamic> map) {
    return DriverRecord(
      id: id,
      name: (map['name'] ?? '').toString(),
      truckNumber: (map['truckNumber'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'truckNumber': truckNumber,
      'phone': phone,
    };
  }
}
