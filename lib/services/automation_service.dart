import 'package:intl/intl.dart';

import '../models/company.dart';
import '../models/invoice_record.dart';
import 'invoice_service.dart';
import 'realtime_service.dart';

class AutomationService {
  AutomationService({
    RealtimeService? realtimeService,
    InvoiceService? invoiceService,
  }) : _realtime = realtimeService ?? RealtimeService.instance,
       _invoiceService = invoiceService ?? InvoiceService();

  final RealtimeService _realtime;
  final InvoiceService _invoiceService;

  Future<Map<String, dynamic>> generateInvoice(String loadId) async {
    final load = await _realtime.getLoad(loadId);
    if (load == null) {
      throw StateError('Load not found.');
    }
    final invoice = await _invoiceService.generateInvoice(load);
    return {
      'invoiceId': invoice.id,
      'invoiceNumber': invoice.invoiceNumber,
      'storagePath': invoice.storagePath,
      'invoiceFileUrl': invoice.invoiceFileUrl,
      'existing': false,
    };
  }

  Future<Map<String, dynamic>> generateCompanyInvoice({
    required String companyId,
    required String startDate,
    required String endDate,
    required List<String> driverIds,
    required String agentName,
  }) async {
    final rangeStart = DateTime.tryParse(startDate);
    final rangeEnd = DateTime.tryParse(endDate);
    if (rangeStart == null || rangeEnd == null) {
      throw StateError('Invalid invoice date range.');
    }
    if (rangeStart.isAfter(rangeEnd)) {
      throw StateError('Start date must be on or before end date.');
    }

    final companies = await _realtime.streamCompanies().first;
    Company? company;
    for (final item in companies) {
      if (item.id == companyId) {
        company = item;
        break;
      }
    }
    if (company == null) {
      throw StateError('Selected company could not be found.');
    }

    final loads = await _realtime.streamLoads().first;
    final selectedDriverIds = driverIds.where((id) => id.trim().isNotEmpty).toSet();
    final filteredLoads =
        loads.where((load) {
          if (load.companyId != companyId) return false;
          final loadDate = DateTime.tryParse(load.date);
          if (loadDate == null) return false;
          final day = DateTime(loadDate.year, loadDate.month, loadDate.day);
          final start = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
          final end = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
          if (day.isBefore(start) || day.isAfter(end)) return false;
          if (selectedDriverIds.isNotEmpty &&
              !selectedDriverIds.contains(load.driverId)) {
            return false;
          }
          return true;
        }).toList()
          ..sort((a, b) => a.loadNumber.compareTo(b.loadNumber));

    if (filteredLoads.isEmpty) {
      throw StateError('No matching loads found for the selected company and date range.');
    }

    final effectiveDriverIds =
        (selectedDriverIds.isNotEmpty
                ? selectedDriverIds
                : filteredLoads.map((load) => load.driverId))
            .where((id) => id.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final dedupeKey = [
      companyId,
      DateFormat('yyyy-MM-dd').format(rangeStart),
      DateFormat('yyyy-MM-dd').format(rangeEnd),
      effectiveDriverIds.join('_'),
    ].join('__');

    final invoices = await _realtime.streamInvoices().first;
    InvoiceRecord? existing;
    for (final invoice in invoices) {
      if (invoice.dedupeKey == dedupeKey) {
        existing = invoice;
        break;
      }
    }
    if (existing != null) {
      return {
        'invoiceId': existing.id,
        'invoiceNumber': existing.invoiceNumber,
        'storagePath': existing.storagePath,
        'invoiceFileUrl': existing.invoiceFileUrl,
        'existing': true,
      };
    }

    final invoice = await _invoiceService.generateCompanyInvoice(
      company: company,
      loads: filteredLoads,
      startDate: rangeStart,
      endDate: rangeEnd,
      agentName: agentName,
      dedupeKey: dedupeKey,
      driverIds: effectiveDriverIds,
    );

    return {
      'invoiceId': invoice.id,
      'invoiceNumber': invoice.invoiceNumber,
      'storagePath': invoice.storagePath,
      'invoiceFileUrl': invoice.invoiceFileUrl,
      'totalLoads': invoice.totalLoads,
      'totalAmount': invoice.invoiceAmount,
      'totalGross': invoice.totalGross,
      'existing': false,
    };
  }
}
