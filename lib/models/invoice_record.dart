class InvoiceRecord {
  final String id;
  final String invoiceNumber;
  final String loadId;
  final String companyName;
  final String invoiceDate;
  final double feePercentage;
  final double dispatchFeeAmount;
  final double invoiceAmount;
  final String dueDate;
  final String invoiceFileUrl;
  final String storagePath;
  final String invoiceStatus;
  final String paymentStatus;
  final String sentDate;
  final String paidDate;
  final String notes;

  const InvoiceRecord({
    required this.id,
    required this.invoiceNumber,
    required this.loadId,
    required this.companyName,
    required this.invoiceDate,
    required this.feePercentage,
    required this.dispatchFeeAmount,
    required this.invoiceAmount,
    required this.dueDate,
    required this.invoiceFileUrl,
    required this.storagePath,
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
      companyName: (map['companyName'] ?? '').toString(),
      invoiceDate: (map['invoiceDate'] ?? '').toString(),
      feePercentage: (map['feePercentage'] ?? 0).toDouble(),
      dispatchFeeAmount: (map['dispatchFeeAmount'] ?? 0).toDouble(),
      invoiceAmount: (map['invoiceAmount'] ?? 0).toDouble(),
      dueDate: (map['dueDate'] ?? '').toString(),
      invoiceFileUrl: (map['invoiceFileUrl'] ?? '').toString(),
      storagePath: (map['storagePath'] ?? '').toString(),
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
      'companyName': companyName,
      'invoiceDate': invoiceDate,
      'feePercentage': feePercentage,
      'dispatchFeeAmount': dispatchFeeAmount,
      'invoiceAmount': invoiceAmount,
      'dueDate': dueDate,
      'invoiceFileUrl': invoiceFileUrl,
      'storagePath': storagePath,
      'invoiceStatus': invoiceStatus,
      'paymentStatus': paymentStatus,
      'sentDate': sentDate,
      'paidDate': paidDate,
      'notes': notes,
    };
  }
}
