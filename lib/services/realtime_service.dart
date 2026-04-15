import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../firebase_options.dart';
import '../models/activity_log_record.dart';
import '../models/app_notification.dart';
import '../models/app_role.dart';
import '../models/app_user.dart';
import '../models/brokerage.dart';
import '../models/company.dart';
import '../models/document_record.dart';
import '../models/driver_record.dart';
import '../models/invoice_record.dart';
import '../models/load_item.dart';

class RealtimeService {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  final DatabaseReference _root = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: DefaultFirebaseOptions.currentPlatform.databaseURL,
  ).ref();

  DatabaseReference get usersRef => _root.child('users');
  DatabaseReference get companiesRef => _root.child('companies');
  DatabaseReference get dispatchersRef => _root.child('dispatchers');
  DatabaseReference get driversRef => _root.child('drivers');
  DatabaseReference get brokeragesRef => _root.child('brokerages');
  DatabaseReference get loadsRef => _root.child('loads');
  DatabaseReference get documentsRef => _root.child('documents');
  DatabaseReference get invoicesRef => _root.child('invoices');
  DatabaseReference get activityLogsRef => _root.child('activity_logs');
  DatabaseReference get notificationsRef => _root.child('notifications');
  DatabaseReference get weeklySummariesRef => _root.child('weekly_summaries');

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return {};
  }

  List<T> _listFromSnapshot<T>(
    DataSnapshot snapshot,
    T Function(String id, Map<String, dynamic> map) converter,
  ) {
    final raw = _asMap(snapshot.value);
    return raw.entries
        .map((entry) => converter(entry.key, _asMap(entry.value)))
        .toList();
  }

  ({int year, int week, String yearWeek}) isoWeekParts(DateTime date) {
    final normalized = DateTime.utc(date.year, date.month, date.day);
    final weekday = normalized.weekday == 7 ? 0 : normalized.weekday;
    final thursday = normalized.add(Duration(days: 4 - weekday));
    final firstDay = DateTime.utc(thursday.year, 1, 1);
    final week = ((thursday.difference(firstDay).inDays) / 7).floor() + 1;
    final year = thursday.year;
    return (
      year: year,
      week: week,
      yearWeek: '$year-W${week.toString().padLeft(2, '0')}',
    );
  }

  Stream<AppUser?> streamUser(String uid) {
    return usersRef.child(uid).onValue.map((event) {
      final map = _asMap(event.snapshot.value);
      if (map.isEmpty) return null;
      return AppUser.fromMap(uid, map);
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final snapshot = await usersRef.child(uid).get();
    final map = _asMap(snapshot.value);
    if (map.isEmpty) return null;
    return AppUser.fromMap(uid, map);
  }

  Future<void> saveUser(AppUser user) async {
    await usersRef.child(user.uid).set(user.toMap());
    if (user.dispatcherId.isNotEmpty) {
      await dispatchersRef.child(user.dispatcherId).set({
        'name': user.name,
        'email': user.email,
      });
    }
  }

  Stream<List<AppUser>> streamUsers() {
    return usersRef.onValue.map(
      (event) => _listFromSnapshot(event.snapshot, AppUser.fromMap),
    );
  }

  Stream<List<Company>> streamCompanies() {
    return companiesRef.onValue.map(
      (event) =>
          _listFromSnapshot(event.snapshot, Company.fromMap)
            ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  Future<void> saveCompany(Company company) async {
    await companiesRef.child(company.id).set(company.toMap());
  }

  Future<void> deleteCompany(String companyId) async {
    final loads = await streamLoads().first;
    final linked = loads.any((load) => load.companyId == companyId);
    if (linked) {
      throw Exception(
        'This company is linked to existing loads and cannot be deleted.',
      );
    }
    await companiesRef.child(companyId).remove();
  }

  Stream<List<Brokerage>> streamBrokerages() {
    return brokeragesRef.onValue.map(
      (event) =>
          _listFromSnapshot(event.snapshot, Brokerage.fromMap)
            ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  Future<void> saveBrokerage(Brokerage brokerage) async {
    await brokeragesRef.child(brokerage.id).set(brokerage.toMap());
  }

  Future<void> deleteBrokerage(String brokerageId) async {
    final loads = await streamLoads().first;
    final linked = loads.any((load) => load.brokerageId == brokerageId);
    if (linked) {
      throw Exception(
        'This brokerage is linked to existing loads and cannot be deleted.',
      );
    }
    await brokeragesRef.child(brokerageId).remove();
  }

  Stream<List<DriverRecord>> streamDrivers() {
    return driversRef.onValue.map(
      (event) =>
          _listFromSnapshot(event.snapshot, DriverRecord.fromMap)
            ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  Future<String> upsertDriver({
    required String name,
    required String truckNumber,
    required String phone,
    String? driverId,
  }) async {
    final id = driverId?.isNotEmpty == true
        ? driverId!
        : driversRef.push().key!;
    final driver = DriverRecord(
      id: id,
      name: name,
      truckNumber: truckNumber,
      phone: phone,
    );
    await driversRef.child(id).set(driver.toMap());
    return id;
  }

  Future<void> saveDriver(DriverRecord driver) async {
    await driversRef.child(driver.id).set(driver.toMap());
  }

  Future<void> deleteDriver(String driverId) async {
    final loads = await streamLoads().first;
    final linked = loads.any((load) => load.driverId == driverId);
    if (linked) {
      throw Exception(
        'This driver is linked to existing loads and cannot be deleted.',
      );
    }
    await driversRef.child(driverId).remove();
  }

  Stream<List<LoadItem>> streamLoads() {
    return loadsRef.onValue.map(
      (event) =>
          _listFromSnapshot(event.snapshot, LoadItem.fromMap)
            ..sort((a, b) => b.createdDate.compareTo(a.createdDate)),
    );
  }

  Stream<List<LoadItem>> streamLoadsForUser(AppUser user) {
    return streamLoads().map((loads) {
      switch (user.role) {
        case AppRole.dispatcher:
          return loads
              .where((load) => load.dispatcherId == user.dispatcherId)
              .toList();
        case AppRole.accountant:
          return loads;
        case AppRole.paperwork:
          return loads;
        case AppRole.admin:
          return loads;
      }
    });
  }

  Stream<List<ActivityLogRecord>> streamActivityLogsForLoad(String loadId) {
    return activityLogsRef.onValue.map((event) {
      final logs = _listFromSnapshot(event.snapshot, ActivityLogRecord.fromMap);
      return logs.where((log) => log.loadId == loadId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Stream<List<AppNotification>> streamNotificationsForUser(String uid) {
    return notificationsRef.onValue.map((event) {
      final items = _listFromSnapshot(event.snapshot, AppNotification.fromMap);
      return items.where((item) => item.userId == uid).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Future<void> markNotificationRead(String notificationId) async {
    await notificationsRef.child(notificationId).update({'read': true});
  }

  Future<bool> loadNumberExists(
    String loadNumber, {
    String? excludingId,
  }) async {
    final snapshot = await loadsRef.get();
    final loads = _listFromSnapshot(snapshot, LoadItem.fromMap);
    return loads.any(
      (load) =>
          load.loadNumber.trim().toLowerCase() ==
              loadNumber.trim().toLowerCase() &&
          load.id != excludingId,
    );
  }

  Future<void> saveLoad(LoadItem load, {bool logCreation = true}) async {
    await loadsRef.child(load.id).set(load.toMap());
    await _updateWeeklySummaries(load);
    if (logCreation) {
      await addActivityLog(
        loadId: load.id,
        type: 'load_created',
        message: 'Load ${load.loadNumber} created.',
        actorId: load.createdBy,
        actorName: load.dispatcherName,
      );
    }
  }

  Future<void> updateLoad(String loadId, Map<String, dynamic> updates) async {
    await loadsRef.child(loadId).update(updates);
    final updatedLoad = await getLoad(loadId);
    if (updatedLoad != null) {
      await _updateWeeklySummaries(updatedLoad);
    }
  }

  Future<void> deleteLoad(String loadId) async {
    final load = await getLoad(loadId);
    if (load == null) return;
    if (load.financialStatus != 'Not Invoiced' ||
        load.invoiceStatus != 'Not Invoiced') {
      throw Exception(
        'This load is already tied to invoicing and cannot be deleted.',
      );
    }

    final documents = await streamDocumentsForLoad(loadId).first;
    for (final document in documents) {
      await documentsRef.child(document.id).remove();
    }

    final logs = await streamActivityLogsForLoad(loadId).first;
    for (final log in logs) {
      await activityLogsRef.child(log.id).remove();
    }

    await loadsRef.child(loadId).remove();
  }

  Future<LoadItem?> getLoad(String loadId) async {
    final snapshot = await loadsRef.child(loadId).get();
    final map = _asMap(snapshot.value);
    if (map.isEmpty) return null;
    return LoadItem.fromMap(loadId, map);
  }

  Stream<List<DocumentRecord>> streamDocumentsForLoad(String loadId) {
    return documentsRef.onValue.map((event) {
      final docs = _listFromSnapshot(event.snapshot, DocumentRecord.fromMap);
      return docs.where((doc) => doc.loadId == loadId).toList()
        ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    });
  }

  Stream<List<DocumentRecord>> streamDocuments() {
    return documentsRef.onValue.map((event) {
      final docs = _listFromSnapshot(event.snapshot, DocumentRecord.fromMap);
      docs.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      return docs;
    });
  }

  Future<void> saveDocument(DocumentRecord document) async {
    await documentsRef.child(document.id).set(document.toMap());
    await refreshPaperworkStatus(document.loadId, changedDocument: document);
  }

  Future<void> updateDocument(
    String documentId,
    Map<String, dynamic> updates,
  ) async {
    await documentsRef.child(documentId).update(updates);
  }

  Future<void> deleteDocument(String documentId) async {
    final snapshot = await documentsRef.child(documentId).get();
    final map = _asMap(snapshot.value);
    if (map.isEmpty) return;
    final document = DocumentRecord.fromMap(documentId, map);
    await documentsRef.child(documentId).remove();
    await refreshPaperworkStatus(document.loadId);
    await addActivityLog(
      loadId: document.loadId,
      type: 'document_deleted',
      message: '${_labelForDocType(document.documentType)} removed from load.',
      actorId: document.uploadedBy,
      actorName: 'System',
    );
  }

  Future<void> setDocumentVerification(
    String documentId, {
    required bool verified,
  }) async {
    final snapshot = await documentsRef.child(documentId).get();
    final map = _asMap(snapshot.value);
    if (map.isEmpty) return;
    final document = DocumentRecord.fromMap(documentId, map);
    await documentsRef.child(documentId).update({'verified': verified});
    await addActivityLog(
      loadId: document.loadId,
      type: 'document_verified',
      message:
          '${document.documentType} verification set to ${verified ? 'verified' : 'unverified'}.',
      actorId: document.uploadedBy,
      actorName: 'System',
    );
    await refreshPaperworkStatus(document.loadId);
  }

  Future<void> refreshPaperworkStatus(
    String loadId, {
    DocumentRecord? changedDocument,
  }) async {
    final load = await getLoad(loadId);
    if (load == null) return;

    final docs = await streamDocumentsForLoad(loadId).first;

    bool hasType(String type) =>
        docs.any((doc) => doc.documentType.toLowerCase() == type.toLowerCase());

    final rate = hasType('rate_confirmation');
    final podDoc = docs.where((doc) => doc.documentType == 'pod').toList();
    final pod = podDoc.isNotEmpty;
    final bol = hasType('bol');
    final missing = [rate, pod, bol].where((present) => !present).length;
    final paperworkStatus = missing == 0 ? 'Complete' : 'Incomplete';

    var operationalStatus = load.operationalStatus;
    if (rate) operationalStatus = 'Booked';
    if (bol) operationalStatus = 'Picked';
    if (pod) operationalStatus = 'Delivered';

    final podUploadedAt = podDoc.isEmpty
        ? load.podUploadedAt
        : podDoc.first.uploadedAt;
    final updates = <String, dynamic>{
      'rateConfirmationUploaded': rate,
      'podUploaded': pod,
      'podUploadedAt': podUploadedAt,
      'bolUploaded': bol,
      'missingDocumentsCount': missing,
      'paperworkStatus': paperworkStatus,
      'operationalStatus': operationalStatus,
      'status': operationalStatus,
      'updatedDate': DateTime.now().toIso8601String(),
    };

    if (operationalStatus == 'Delivered' && load.deliveryDateTime.isEmpty) {
      updates['deliveryDateTime'] = DateTime.now().toIso8601String();
    }

    await loadsRef.child(loadId).update(updates);
    final updatedLoad = (await getLoad(loadId))!;
    await _updateWeeklySummaries(updatedLoad);

    if (changedDocument != null && changedDocument.affectsStatus) {
      await addActivityLog(
        loadId: loadId,
        type: '${changedDocument.documentType}_uploaded',
        message: '${_labelForDocType(changedDocument.documentType)} uploaded.',
        actorId: changedDocument.uploadedBy,
        actorName: changedDocument.uploadedBy,
      );
    }
  }

  Future<String> nextInvoiceNumber() async {
    final snapshot = await invoicesRef.get();
    final invoices = _listFromSnapshot(snapshot, InvoiceRecord.fromMap);
    int max = 1000;
    for (final invoice in invoices) {
      final match = RegExp(r'(\d+)$').firstMatch(invoice.invoiceNumber);
      final number = int.tryParse(match?.group(1) ?? '');
      if (number != null && number > max) max = number;
    }
    return 'INV-${max + 1}';
  }

  Stream<List<InvoiceRecord>> streamInvoices() {
    return invoicesRef.onValue.map(
      (event) =>
          _listFromSnapshot(event.snapshot, InvoiceRecord.fromMap)
            ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate)),
    );
  }

  Future<InvoiceRecord?> getInvoice(String invoiceId) async {
    final snapshot = await invoicesRef.child(invoiceId).get();
    final map = _asMap(snapshot.value);
    if (map.isEmpty) return null;
    return InvoiceRecord.fromMap(invoiceId, map);
  }

  Future<void> saveInvoice(InvoiceRecord invoice) async {
    await invoicesRef.child(invoice.id).set(invoice.toMap());
    final financialStatus = invoice.paymentStatus == 'Paid'
        ? 'Paid'
        : invoice.invoiceStatus == 'Invoice Sent'
        ? 'Invoice Sent'
        : 'Invoice Generated';
    final targetLoadIds = invoice.loadIds.isNotEmpty
        ? invoice.loadIds
        : [invoice.loadId];
    for (final loadId in targetLoadIds.where((id) => id.isNotEmpty)) {
      await updateLoad(loadId, {
        'invoiceStatus': invoice.invoiceStatus,
        'financialStatus': financialStatus,
        'paymentStatus': invoice.paymentStatus,
        'latestInvoiceId': invoice.id,
        'updatedDate': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> setInvoiceSent(InvoiceRecord invoice) async {
    final updated = InvoiceRecord(
      id: invoice.id,
      invoiceNumber: invoice.invoiceNumber,
      loadId: invoice.loadId,
      loadIds: invoice.loadIds,
      companyId: invoice.companyId,
      companyName: invoice.companyName,
      dispatcherId: invoice.dispatcherId,
      driverId: invoice.driverId,
      driversIncluded: invoice.driversIncluded,
      year: invoice.year,
      week: invoice.week,
      yearWeek: invoice.yearWeek,
      invoiceDate: invoice.invoiceDate,
      startDate: invoice.startDate,
      endDate: invoice.endDate,
      totalLoads: invoice.totalLoads,
      totalGross: invoice.totalGross,
      feePercentage: invoice.feePercentage,
      closingRate: invoice.closingRate,
      dispatchFeeAmount: invoice.dispatchFeeAmount,
      invoiceAmount: invoice.invoiceAmount,
      dueDate: invoice.dueDate,
      invoiceFileUrl: invoice.invoiceFileUrl,
      storagePath: invoice.storagePath,
      agentName: invoice.agentName,
      dedupeKey: invoice.dedupeKey,
      invoiceStatus: 'Invoice Sent',
      paymentStatus: invoice.paymentStatus,
      sentDate: DateTime.now().toIso8601String(),
      paidDate: invoice.paidDate,
      notes: invoice.notes,
    );
    await saveInvoice(updated);
    await addActivityLog(
      loadId: invoice.loadId,
      type: 'invoice_sent',
      message: 'Invoice ${invoice.invoiceNumber} marked as sent.',
      actorId: '',
      actorName: 'Accounting',
    );
  }

  Future<void> setInvoicePaid(InvoiceRecord invoice) async {
    final updated = InvoiceRecord(
      id: invoice.id,
      invoiceNumber: invoice.invoiceNumber,
      loadId: invoice.loadId,
      loadIds: invoice.loadIds,
      companyId: invoice.companyId,
      companyName: invoice.companyName,
      dispatcherId: invoice.dispatcherId,
      driverId: invoice.driverId,
      driversIncluded: invoice.driversIncluded,
      year: invoice.year,
      week: invoice.week,
      yearWeek: invoice.yearWeek,
      invoiceDate: invoice.invoiceDate,
      startDate: invoice.startDate,
      endDate: invoice.endDate,
      totalLoads: invoice.totalLoads,
      totalGross: invoice.totalGross,
      feePercentage: invoice.feePercentage,
      closingRate: invoice.closingRate,
      dispatchFeeAmount: invoice.dispatchFeeAmount,
      invoiceAmount: invoice.invoiceAmount,
      dueDate: invoice.dueDate,
      invoiceFileUrl: invoice.invoiceFileUrl,
      storagePath: invoice.storagePath,
      agentName: invoice.agentName,
      dedupeKey: invoice.dedupeKey,
      invoiceStatus: invoice.invoiceStatus,
      paymentStatus: 'Paid',
      sentDate: invoice.sentDate,
      paidDate: DateTime.now().toIso8601String(),
      notes: invoice.notes,
    );
    await saveInvoice(updated);
    await addActivityLog(
      loadId: invoice.loadId,
      type: 'payment_marked_paid',
      message: 'Payment marked as paid for ${invoice.invoiceNumber}.',
      actorId: '',
      actorName: 'Accounting',
    );
  }

  Future<void> addActivityLog({
    required String loadId,
    required String type,
    required String message,
    required String actorId,
    required String actorName,
  }) async {
    final id = activityLogsRef.push().key!;
    final record = ActivityLogRecord(
      id: id,
      loadId: loadId,
      type: type,
      message: message,
      actorId: actorId,
      actorName: actorName,
      createdAt: DateTime.now().toIso8601String(),
    );
    await activityLogsRef.child(id).set(record.toMap());
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String loadId,
    required String type,
  }) async {
    final id = notificationsRef.push().key!;
    final notification = AppNotification(
      id: id,
      userId: userId,
      title: title,
      message: message,
      loadId: loadId,
      createdAt: DateTime.now().toIso8601String(),
      read: false,
      type: type,
    );
    await notificationsRef.child(id).set(notification.toMap());
  }

  Future<void> _updateWeeklySummaries(LoadItem load) async {
    final loads = await streamLoads().first;
    final weekLoads = loads
        .where((item) => item.yearWeek == load.yearWeek)
        .toList();

    Map<String, dynamic> buildSummary({
      required String key,
      required String Function(LoadItem load) valueSelector,
      required String labelKey,
      required String labelValue,
    }) {
      final scoped = weekLoads
          .where((item) => valueSelector(item) == key)
          .toList();
      return {
        labelKey: labelValue,
        'yearWeek': load.yearWeek,
        'totalLoads': scoped.length,
        'totalGross': scoped.fold<double>(
          0,
          (sum, item) => sum + item.loadRate,
        ),
        'totalDispatchFee': scoped.fold<double>(
          0,
          (sum, item) => sum + item.dispatchFeeAmount,
        ),
        'totalRevenue': scoped.fold<double>(
          0,
          (sum, item) => sum + item.dispatcherRevenue,
        ),
        'deliveredLoads': scoped
            .where((item) => item.operationalStatus == 'Delivered')
            .length,
        'updatedAt': DateTime.now().toIso8601String(),
      };
    }

    await weeklySummariesRef
        .child('dispatchers')
        .child(load.dispatcherId)
        .child(load.yearWeek)
        .set(
          buildSummary(
            key: load.dispatcherId,
            valueSelector: (item) => item.dispatcherId,
            labelKey: 'dispatcherName',
            labelValue: load.dispatcherName,
          ),
        );
    await weeklySummariesRef
        .child('drivers')
        .child(load.driverId)
        .child(load.yearWeek)
        .set(
          buildSummary(
            key: load.driverId,
            valueSelector: (item) => item.driverId,
            labelKey: 'driverName',
            labelValue: load.driverName,
          ),
        );
    await weeklySummariesRef
        .child('companies')
        .child(load.companyId)
        .child(load.yearWeek)
        .set(
          buildSummary(
            key: load.companyId,
            valueSelector: (item) => item.companyId,
            labelKey: 'companyName',
            labelValue: load.companyName,
          ),
        );
  }

  String _labelForDocType(String type) {
    return switch (type) {
      'rate_confirmation' => 'Rate Confirmation',
      'bol' => 'BOL',
      'pod' => 'POD',
      'invoice' => 'Invoice',
      _ => type,
    };
  }

  Future<void> seedDefaultDataIfEmpty() async {
    final companiesSnap = await companiesRef.get();
    if (!companiesSnap.exists) {
      await companiesRef.set({
        'comp_01': {
          'name': 'Company A',
          'feePercentage': 2.3,
          'billingEmail': 'billing@companya.com',
          'billingTerms': 'Net 15',
          'active': true,
          'notes': 'Default seeded company',
        },
        'comp_02': {
          'name': 'Company B',
          'feePercentage': 2.5,
          'billingEmail': 'billing@companyb.com',
          'billingTerms': 'Net 30',
          'active': true,
          'notes': '',
        },
      });
    }

    final brokeragesSnap = await brokeragesRef.get();
    if (!brokeragesSnap.exists) {
      await brokeragesRef.set({
        'bro_01': {
          'name': 'ABC Brokerage',
          'mc': '123456',
          'contact': 'ops@abcbrokerage.com',
        },
      });
    }
  }
}
