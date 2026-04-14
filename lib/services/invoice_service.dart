import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/widgets.dart' as pw;

import '../models/invoice_record.dart';
import '../models/load_item.dart';
import 'realtime_service.dart';
import 'storage_service.dart';

class InvoiceService {
  InvoiceService({
    RealtimeService? realtimeService,
    StorageService? storageService,
  })  : _realtime = realtimeService ?? RealtimeService.instance,
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
          pw.Text('Invoice Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
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
              ['Dispatch Fee Amount', load.dispatchFeeAmount.toStringAsFixed(2)],
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
    if (load.status != 'Delivered') {
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
    final dueDate = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().add(const Duration(days: 15)));
    final pdfBytes = await buildInvoicePdf(
      load: load,
      invoiceNumber: invoiceNumber,
      dueDate: dueDate,
    );

    final year = DateTime.now().year;
    final fileName = '$invoiceNumber.pdf';
    final storagePath = 'invoices/$year/$fileName';
    final tempFile = File(path.join(Directory.systemTemp.path, fileName));
    await tempFile.writeAsBytes(pdfBytes);

    final upload = await _storage.uploadFile(tempFile, storagePath);
    final invoice = InvoiceRecord(
      id: invoiceId,
      invoiceNumber: invoiceNumber,
      loadId: load.id,
      companyName: load.companyName,
      invoiceDate: invoiceDate,
      feePercentage: load.feePercentage,
      dispatchFeeAmount: load.dispatchFeeAmount,
      invoiceAmount: load.dispatcherRevenue,
      dueDate: dueDate,
      invoiceFileUrl: upload.downloadUrl,
      storagePath: upload.storagePath,
      invoiceStatus: 'Generated',
      paymentStatus: 'Unpaid',
      sentDate: '',
      paidDate: '',
      notes: '',
    );

    await _realtime.saveInvoice(invoice);
    await _realtime.updateLoad(load.id, {
      'invoiceStatus': 'Generated',
      'updatedDate': DateTime.now().toIso8601String(),
    });

    return invoice;
  }
}
