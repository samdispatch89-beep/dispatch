import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

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
    final storagePath = _storage.buildInvoicePath(
      companyName: load.companyName,
      driverName: load.driverName,
      yearWeek: load.yearWeek,
      loadNumber: load.loadNumber,
      fileName: fileName,
    );
    final upload = await _storage.uploadBytes(
      pdfBytes,
      storagePath,
      fileName: fileName,
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
      invoiceFileUrl: upload.downloadUrl,
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
}
