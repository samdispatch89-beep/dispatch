import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/company.dart';
import '../models/invoice_record.dart';
import '../models/load_item.dart';
import 'realtime_service.dart';
import 'storage_service.dart';

class InvoiceService {
  InvoiceService({
    RealtimeService? realtimeService,
    StorageService? storageService,
  }) : _realtime = realtimeService ?? RealtimeService.instance,
       _storage = storageService ?? StorageService();

  final RealtimeService _realtime;
  final StorageService _storage;

  String _fmtDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<Uint8List> buildInvoicePdf({
    required LoadItem load,
    required String invoiceNumber,
    required String dueDate,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Dispatch Invoice')),
          pw.Text('Invoice Number: $invoiceNumber'),
          pw.Text(
            'Invoice Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
          ),
          pw.Text('Due Date: $dueDate'),
          pw.SizedBox(height: 16),
          pw.Text('Company: ${load.companyName}'),
          pw.Text('Load Number: ${load.loadNumber}'),
          pw.Text('Route: ${load.routeSummary}'),
          pw.Text('Dispatcher: ${load.dispatcherName}'),
          pw.Text('Brokerage: ${load.brokerageName}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Description', 'Amount'],
            data: [
              ['Load Rate', load.loadRate.toStringAsFixed(2)],
              ['Dispatch Fee %', load.feePercentage.toStringAsFixed(2)],
              [
                'Dispatch Fee Amount',
                load.dispatchFeeAmount.toStringAsFixed(2),
              ],
              ['Invoice Amount', load.dispatcherRevenue.toStringAsFixed(2)],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Notes: ${load.notes.isEmpty ? 'N/A' : load.notes}'),
        ],
      ),
    );
    return pdf.save();
  }

  Future<Uint8List> buildCompanyInvoicePdf({
    required Company company,
    required List<LoadItem> loads,
    required String invoiceNumber,
    required String invoiceDate,
    required String dueDate,
    required String agentName,
  }) async {
    final pdf = pw.Document();
    final totalGross = loads.fold<double>(0, (sum, load) => sum + load.loadRate);
    final totalDispatchFee = loads.fold<double>(
      0,
      (sum, load) => sum + load.dispatchFeeAmount,
    );

    pdf.addPage(
      pw.MultiPage(
        build:
            (context) => [
              pw.Text(
                'Invoice',
                style: pw.TextStyle(
                  fontSize: 30,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Customer Weekly Report',
                style: const pw.TextStyle(fontSize: 18),
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date: $invoiceDate'),
                  pw.Text(
                    'Closing Rate: ${company.feePercentage.toStringAsFixed(2)}%',
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Carrier',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(company.name),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Agent',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(agentName),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.black,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                headers: const [
                  'Load #',
                  'Load Details',
                  'Duration',
                  'Amount',
                  'Status',
                ],
                data:
                    loads
                        .map(
                          (load) => [
                            load.loadNumber,
                            '${load.pickupLocation} → ${load.deliveryLocation}',
                            '${load.date} → ${load.deliveryDateTime.isEmpty ? load.date : load.deliveryDateTime}',
                            load.dispatchFeeAmount.toStringAsFixed(2),
                            load.paymentStatus == 'Paid'
                                ? 'Paid'
                                : load.financialStatus == 'Invoice Sent'
                                ? 'Invoice Sent'
                                : load.operationalStatus,
                          ],
                        )
                        .toList(),
              ),
              pw.SizedBox(height: 16),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Loads: ${loads.length}'),
                    pw.Text('Gross: \$${totalGross.toStringAsFixed(2)}'),
                    pw.Text(
                      'Dispatch Fee: \$${totalDispatchFee.toStringAsFixed(2)}',
                    ),
                    pw.Text('Invoice Number: $invoiceNumber'),
                    pw.Text('Due Date: $dueDate'),
                  ],
                ),
              ),
              pw.SizedBox(height: 42),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _SignatureBlock(label: 'AGENT'),
                  _SignatureBlock(label: 'SUPERVISOR'),
                  _SignatureBlock(label: 'ACCOUNTS'),
                ],
              ),
            ],
      ),
    );
    return pdf.save();
  }

  Future<InvoiceRecord> generateInvoice(LoadItem load) async {
    if (load.operationalStatus != 'Delivered') {
      throw StateError('A load cannot be invoiced unless it is Delivered.');
    }
    if (!load.paperworkComplete) {
      throw StateError(
        'A load cannot enter invoice-ready state until POD, BOL, and Rate Confirmation are uploaded.',
      );
    }

    final invoiceId = _realtime.invoicesRef.push().key!;
    final invoiceNumber = await _realtime.nextInvoiceNumber();
    final invoiceDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dueDate = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().add(const Duration(days: 15)));
    final pdfBytes = await buildInvoicePdf(
      load: load,
      invoiceNumber: invoiceNumber,
      dueDate: dueDate,
    );

    final fileName = '$invoiceNumber.pdf';
    final upload = await _storage.uploadDocumentBytes(
      bytes: pdfBytes,
      companyName: load.companyName,
      driverName: load.driverName,
      yearWeek: load.yearWeek,
      loadNumber: load.loadNumber,
      documentType: 'invoice',
      fileName: fileName,
      mimeType: 'application/pdf',
    );
    final invoice = InvoiceRecord(
      id: invoiceId,
      invoiceNumber: invoiceNumber,
      loadId: load.id,
      loadIds: [load.id],
      companyId: load.companyId,
      companyName: load.companyName,
      dispatcherId: load.dispatcherId,
      driverId: load.driverId,
      driversIncluded: [load.driverId],
      year: load.year,
      week: load.week,
      yearWeek: load.yearWeek,
      invoiceDate: invoiceDate,
      startDate: load.date,
      endDate: load.deliveryDateTime.isEmpty
          ? load.date
          : load.deliveryDateTime,
      totalLoads: 1,
      totalGross: load.loadRate,
      feePercentage: load.feePercentage,
      closingRate: load.feePercentage,
      dispatchFeeAmount: load.dispatchFeeAmount,
      invoiceAmount: load.dispatcherRevenue,
      dueDate: dueDate,
      invoiceFileUrl: '',
      storagePath: upload.storagePath,
      agentName: load.dispatcherName,
      dedupeKey: '${load.companyId}_${load.loadNumber}',
      invoiceStatus: 'Invoice Generated',
      paymentStatus: 'Unpaid',
      sentDate: '',
      paidDate: '',
      notes: '',
    );

    await _realtime.saveInvoice(invoice);
    await _realtime.updateLoad(load.id, {
      'invoiceStatus': 'Invoice Generated',
      'financialStatus': 'Invoice Generated',
      'updatedDate': DateTime.now().toIso8601String(),
    });
    await _realtime.addActivityLog(
      loadId: load.id,
      type: 'invoice_generated',
      message: 'Invoice $invoiceNumber generated.',
      actorId: '',
      actorName: 'Accounting',
    );

    return invoice;
  }

  Future<InvoiceRecord> generateCompanyInvoice({
    required Company company,
    required List<LoadItem> loads,
    required DateTime startDate,
    required DateTime endDate,
    required String agentName,
    required String dedupeKey,
    required List<String> driverIds,
  }) async {
    if (loads.isEmpty) {
      throw StateError('No loads were selected for invoicing.');
    }
    final hasInvalidLoad = loads.any((load) => !load.invoiceReady);
    if (hasInvalidLoad) {
      throw StateError(
        'All selected loads must be delivered and have complete paperwork before invoicing.',
      );
    }

    final firstLoad = loads.first;
    final invoiceId = _realtime.invoicesRef.push().key!;
    final invoiceNumber = await _realtime.nextInvoiceNumber();
    final invoiceDate = _fmtDate(DateTime.now());
    final dueDate = _fmtDate(DateTime.now().add(const Duration(days: 15)));
    final pdfBytes = await buildCompanyInvoicePdf(
      company: company,
      loads: loads,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      dueDate: dueDate,
      agentName: agentName,
    );

    final fileName = '$invoiceNumber.pdf';
    final upload = await _storage.uploadDocumentBytes(
      bytes: pdfBytes,
      companyName: company.name,
      driverName: firstLoad.driverName,
      yearWeek: firstLoad.yearWeek,
      loadNumber: invoiceNumber,
      documentType: 'invoice',
      fileName: fileName,
      mimeType: 'application/pdf',
    );

    final totalGross = loads.fold<double>(0, (sum, load) => sum + load.loadRate);
    final totalDispatchFee = loads.fold<double>(
      0,
      (sum, load) => sum + load.dispatchFeeAmount,
    );
    final invoice = InvoiceRecord(
      id: invoiceId,
      invoiceNumber: invoiceNumber,
      loadId: firstLoad.id,
      loadIds: loads.map((load) => load.id).toList(),
      companyId: company.id,
      companyName: company.name,
      dispatcherId: firstLoad.dispatcherId,
      driverId: firstLoad.driverId,
      driversIncluded: driverIds,
      year: firstLoad.year,
      week: firstLoad.week,
      yearWeek: firstLoad.yearWeek,
      invoiceDate: invoiceDate,
      startDate: _fmtDate(startDate),
      endDate: _fmtDate(endDate),
      totalLoads: loads.length,
      totalGross: totalGross,
      feePercentage: company.feePercentage,
      closingRate: company.feePercentage,
      dispatchFeeAmount: totalDispatchFee,
      invoiceAmount: totalDispatchFee,
      dueDate: dueDate,
      invoiceFileUrl: upload.downloadUrl,
      storagePath: upload.storagePath,
      agentName: agentName,
      dedupeKey: dedupeKey,
      invoiceStatus: 'Generated',
      paymentStatus: 'Unpaid',
      sentDate: '',
      paidDate: '',
      notes: '',
    );

    await _realtime.saveInvoice(invoice);
    for (final load in loads) {
      await _realtime.addActivityLog(
        loadId: load.id,
        type: 'invoice_generated',
        message: 'Invoice $invoiceNumber generated.',
        actorId: '',
        actorName: agentName,
      );
    }
    return invoice;
  }
}

class _SignatureBlock extends pw.StatelessWidget {
  _SignatureBlock({required this.label});

  final String label;

  @override
  pw.Widget build(pw.Context context) {
    return pw.SizedBox(
      width: 150,
      child: pw.Column(
        children: [
          pw.Divider(),
          pw.SizedBox(height: 6),
          pw.Text(label),
        ],
      ),
    );
  }
}
