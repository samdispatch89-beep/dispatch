class InvoiceRecord {
  final String id;
  final String invoiceNumber;
  final String loadId;
  final List<String> loadIds;
  final String companyId;
  final String companyName;
  final String dispatcherId;
  final String driverId;
  final List<String> driversIncluded;
  final int year;
  final int week;
  final String yearWeek;
  final String invoiceDate;
  final String startDate;
  final String endDate;
  final int totalLoads;
  final double totalGross;
  final double feePercentage;
  final double closingRate;
  final double dispatchFeeAmount;
  final double invoiceAmount;
  final String dueDate;
  final String invoiceFileUrl;
  final String storagePath;
  final String agentName;
  final String dedupeKey;
  final String invoiceStatus;
  final String paymentStatus;
  final String sentDate;
  final String paidDate;
  final String notes;

  const InvoiceRecord({
    required this.id,
    required this.invoiceNumber,
    required this.loadId,
    required this.loadIds,
    required this.companyId,
    required this.companyName,
    required this.dispatcherId,
    required this.driverId,
    required this.driversIncluded,
    required this.year,
    required this.week,
    required this.yearWeek,
    required this.invoiceDate,
    required this.startDate,
    required this.endDate,
    required this.totalLoads,
    required this.totalGross,
    required this.feePercentage,
    required this.closingRate,
    required this.dispatchFeeAmount,
    required this.invoiceAmount,
    required this.dueDate,
    required this.invoiceFileUrl,
    required this.storagePath,
    required this.agentName,
    required this.dedupeKey,
    required this.invoiceStatus,
    required this.paymentStatus,
    required this.sentDate,
    required this.paidDate,
    required this.notes,
  });

  factory InvoiceRecord.fromMap(String id, Map<String, dynamic> map) {
    return InvoiceRecord(
      id: id,
      invoiceNumber: (map['invoiceNumber'] ?? '').toString(),
      loadId: (map['loadId'] ?? '').toString(),
      loadIds: ((map['loadIds'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      companyId: (map['companyId'] ?? '').toString(),
      companyName: (map['companyName'] ?? '').toString(),
      dispatcherId: (map['dispatcherId'] ?? '').toString(),
      driverId: (map['driverId'] ?? '').toString(),
      driversIncluded: ((map['driversIncluded'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      year: (map['year'] ?? 0) as int,
      week: (map['week'] ?? 0) as int,
      yearWeek: (map['yearWeek'] ?? '').toString(),
      invoiceDate: (map['invoiceDate'] ?? '').toString(),
      startDate: (map['startDate'] ?? '').toString(),
      endDate: (map['endDate'] ?? '').toString(),
      totalLoads: (map['totalLoads'] ?? 0) as int,
      totalGross: (map['totalGross'] ?? 0).toDouble(),
      feePercentage: (map['feePercentage'] ?? 0).toDouble(),
      closingRate: (map['closingRate'] ?? map['feePercentage'] ?? 0).toDouble(),
      dispatchFeeAmount: (map['dispatchFeeAmount'] ?? 0).toDouble(),
      invoiceAmount: (map['invoiceAmount'] ?? 0).toDouble(),
      dueDate: (map['dueDate'] ?? '').toString(),
      invoiceFileUrl: (map['invoiceFileUrl'] ?? '').toString(),
      storagePath: (map['storagePath'] ?? '').toString(),
      agentName: (map['agentName'] ?? '').toString(),
      dedupeKey: (map['dedupeKey'] ?? '').toString(),
      invoiceStatus: (map['invoiceStatus'] ?? 'Generated').toString(),
      paymentStatus: (map['paymentStatus'] ?? 'Unpaid').toString(),
      sentDate: (map['sentDate'] ?? '').toString(),
      paidDate: (map['paidDate'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceNumber': invoiceNumber,
      'loadId': loadId,
      'loadIds': loadIds,
      'companyId': companyId,
      'companyName': companyName,
      'dispatcherId': dispatcherId,
      'driverId': driverId,
      'driversIncluded': driversIncluded,
      'year': year,
      'week': week,
      'yearWeek': yearWeek,
      'invoiceDate': invoiceDate,
      'startDate': startDate,
      'endDate': endDate,
      'totalLoads': totalLoads,
      'totalGross': totalGross,
      'feePercentage': feePercentage,
      'closingRate': closingRate,
      'dispatchFeeAmount': dispatchFeeAmount,
      'invoiceAmount': invoiceAmount,
      'dueDate': dueDate,
      'invoiceFileUrl': invoiceFileUrl,
      'storagePath': storagePath,
      'agentName': agentName,
      'dedupeKey': dedupeKey,
      'invoiceStatus': invoiceStatus,
      'paymentStatus': paymentStatus,
      'sentDate': sentDate,
      'paidDate': paidDate,
      'notes': notes,
    };
  }
}
