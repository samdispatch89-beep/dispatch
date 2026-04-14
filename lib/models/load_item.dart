class LoadItem {
  final String id;
  final String loadNumber;
  final String date;
  final String companyId;
  final String companyName;
  final String dispatcherId;
  final String dispatcherName;
  final String dispatcherEmail;
  final String driverId;
  final String driverName;
  final String truckNumber;
  final String pickupLocation;
  final String deliveryLocation;
  final String routeSummary;
  final String brokerageId;
  final String brokerageName;
  final String brokerageMc;
  final String brokerContact;
  final double loadRate;
  final double feePercentage;
  final double dispatchFeeAmount;
  final double dispatcherRevenue;
  final String status;
  final String invoiceStatus;
  final String paymentStatus;
  final String paperworkStatus;
  final String notes;
  final String createdBy;
  final String createdDate;
  final String updatedDate;
  final bool rateConfirmationUploaded;
  final bool podUploaded;
  final bool bolUploaded;
  final int missingDocumentsCount;

  const LoadItem({
    required this.id,
    required this.loadNumber,
    required this.date,
    required this.companyId,
    required this.companyName,
    required this.dispatcherId,
    required this.dispatcherName,
    required this.dispatcherEmail,
    required this.driverId,
    required this.driverName,
    required this.truckNumber,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.routeSummary,
    required this.brokerageId,
    required this.brokerageName,
    required this.brokerageMc,
    required this.brokerContact,
    required this.loadRate,
    required this.feePercentage,
    required this.dispatchFeeAmount,
    required this.dispatcherRevenue,
    required this.status,
    required this.invoiceStatus,
    required this.paymentStatus,
    required this.paperworkStatus,
    required this.notes,
    required this.createdBy,
    required this.createdDate,
    required this.updatedDate,
    required this.rateConfirmationUploaded,
    required this.podUploaded,
    required this.bolUploaded,
    required this.missingDocumentsCount,
  });

  bool get paperworkComplete =>
      rateConfirmationUploaded && podUploaded && bolUploaded;

  bool get invoiceReady =>
      status == 'Delivered' &&
      paperworkComplete &&
      invoiceStatus == 'Pending';

  factory LoadItem.fromMap(String id, Map<String, dynamic> map) {
    return LoadItem(
      id: id,
      loadNumber: (map['loadNumber'] ?? '').toString(),
      date: (map['date'] ?? '').toString(),
      companyId: (map['companyId'] ?? '').toString(),
      companyName: (map['companyName'] ?? '').toString(),
      dispatcherId: (map['dispatcherId'] ?? '').toString(),
      dispatcherName: (map['dispatcherName'] ?? '').toString(),
      dispatcherEmail: (map['dispatcherEmail'] ?? '').toString(),
      driverId: (map['driverId'] ?? '').toString(),
      driverName: (map['driverName'] ?? '').toString(),
      truckNumber: (map['truckNumber'] ?? '').toString(),
      pickupLocation: (map['pickupLocation'] ?? '').toString(),
      deliveryLocation: (map['deliveryLocation'] ?? '').toString(),
      routeSummary: (map['routeSummary'] ?? '').toString(),
      brokerageId: (map['brokerageId'] ?? '').toString(),
      brokerageName: (map['brokerageName'] ?? '').toString(),
      brokerageMc: (map['brokerageMc'] ?? '').toString(),
      brokerContact: (map['brokerContact'] ?? '').toString(),
      loadRate: (map['loadRate'] ?? 0).toDouble(),
      feePercentage: (map['feePercentage'] ?? 0).toDouble(),
      dispatchFeeAmount: (map['dispatchFeeAmount'] ?? 0).toDouble(),
      dispatcherRevenue: (map['dispatcherRevenue'] ?? 0).toDouble(),
      status: (map['status'] ?? 'Active').toString(),
      invoiceStatus: (map['invoiceStatus'] ?? 'Pending').toString(),
      paymentStatus: (map['paymentStatus'] ?? 'Unpaid').toString(),
      paperworkStatus: (map['paperworkStatus'] ?? 'Incomplete').toString(),
      notes: (map['notes'] ?? '').toString(),
      createdBy: (map['createdBy'] ?? '').toString(),
      createdDate: (map['createdDate'] ?? '').toString(),
      updatedDate: (map['updatedDate'] ?? '').toString(),
      rateConfirmationUploaded: map['rateConfirmationUploaded'] == true,
      podUploaded: map['podUploaded'] == true,
      bolUploaded: map['bolUploaded'] == true,
      missingDocumentsCount: (map['missingDocumentsCount'] ?? 3) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'loadNumber': loadNumber,
      'date': date,
      'companyId': companyId,
      'companyName': companyName,
      'dispatcherId': dispatcherId,
      'dispatcherName': dispatcherName,
      'dispatcherEmail': dispatcherEmail,
      'driverId': driverId,
      'driverName': driverName,
      'truckNumber': truckNumber,
      'pickupLocation': pickupLocation,
      'deliveryLocation': deliveryLocation,
      'routeSummary': routeSummary,
      'brokerageId': brokerageId,
      'brokerageName': brokerageName,
      'brokerageMc': brokerageMc,
      'brokerContact': brokerContact,
      'loadRate': loadRate,
      'feePercentage': feePercentage,
      'dispatchFeeAmount': dispatchFeeAmount,
      'dispatcherRevenue': dispatcherRevenue,
      'status': status,
      'invoiceStatus': invoiceStatus,
      'paymentStatus': paymentStatus,
      'paperworkStatus': paperworkStatus,
      'notes': notes,
      'createdBy': createdBy,
      'createdDate': createdDate,
      'updatedDate': updatedDate,
      'rateConfirmationUploaded': rateConfirmationUploaded,
      'podUploaded': podUploaded,
      'bolUploaded': bolUploaded,
      'missingDocumentsCount': missingDocumentsCount,
    };
  }

  LoadItem copyWith({
    String? loadNumber,
    String? date,
    String? companyId,
    String? companyName,
    String? dispatcherId,
    String? dispatcherName,
    String? dispatcherEmail,
    String? driverId,
    String? driverName,
    String? truckNumber,
    String? pickupLocation,
    String? deliveryLocation,
    String? routeSummary,
    String? brokerageId,
    String? brokerageName,
    String? brokerageMc,
    String? brokerContact,
    double? loadRate,
    double? feePercentage,
    double? dispatchFeeAmount,
    double? dispatcherRevenue,
    String? status,
    String? invoiceStatus,
    String? paymentStatus,
    String? paperworkStatus,
    String? notes,
    String? createdBy,
    String? createdDate,
    String? updatedDate,
    bool? rateConfirmationUploaded,
    bool? podUploaded,
    bool? bolUploaded,
    int? missingDocumentsCount,
  }) {
    return LoadItem(
      id: id,
      loadNumber: loadNumber ?? this.loadNumber,
      date: date ?? this.date,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      dispatcherId: dispatcherId ?? this.dispatcherId,
      dispatcherName: dispatcherName ?? this.dispatcherName,
      dispatcherEmail: dispatcherEmail ?? this.dispatcherEmail,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      truckNumber: truckNumber ?? this.truckNumber,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      routeSummary: routeSummary ?? this.routeSummary,
      brokerageId: brokerageId ?? this.brokerageId,
      brokerageName: brokerageName ?? this.brokerageName,
      brokerageMc: brokerageMc ?? this.brokerageMc,
      brokerContact: brokerContact ?? this.brokerContact,
      loadRate: loadRate ?? this.loadRate,
      feePercentage: feePercentage ?? this.feePercentage,
      dispatchFeeAmount: dispatchFeeAmount ?? this.dispatchFeeAmount,
      dispatcherRevenue: dispatcherRevenue ?? this.dispatcherRevenue,
      status: status ?? this.status,
      invoiceStatus: invoiceStatus ?? this.invoiceStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paperworkStatus: paperworkStatus ?? this.paperworkStatus,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      rateConfirmationUploaded:
          rateConfirmationUploaded ?? this.rateConfirmationUploaded,
      podUploaded: podUploaded ?? this.podUploaded,
      bolUploaded: bolUploaded ?? this.bolUploaded,
      missingDocumentsCount:
          missingDocumentsCount ?? this.missingDocumentsCount,
    );
  }
}
