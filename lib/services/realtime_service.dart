import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../firebase_options.dart';
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

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), val),
      );
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
      (event) => _listFromSnapshot(event.snapshot, Company.fromMap)
        ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  Future<void> saveCompany(Company company) async {
    await companiesRef.child(company.id).set(company.toMap());
  }

  Stream<List<Brokerage>> streamBrokerages() {
    return brokeragesRef.onValue.map(
      (event) => _listFromSnapshot(event.snapshot, Brokerage.fromMap)
        ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  Future<void> saveBrokerage(Brokerage brokerage) async {
    await brokeragesRef.child(brokerage.id).set(brokerage.toMap());
  }

  Stream<List<DriverRecord>> streamDrivers() {
    return driversRef.onValue.map(
      (event) => _listFromSnapshot(event.snapshot, DriverRecord.fromMap)
        ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  Future<String> upsertDriver({
    required String name,
    required String truckNumber,
    required String phone,
    String? driverId,
  }) async {
    final id = driverId?.isNotEmpty == true ? driverId! : driversRef.push().key!;
    final driver = DriverRecord(
      id: id,
      name: name,
      truckNumber: truckNumber,
      phone: phone,
    );
    await driversRef.child(id).set(driver.toMap());
    return id;
  }

  Stream<List<LoadItem>> streamLoads() {
    return loadsRef.onValue.map(
      (event) => _listFromSnapshot(event.snapshot, LoadItem.fromMap)
        ..sort((a, b) => b.createdDate.compareTo(a.createdDate)),
    );
  }

  Stream<List<LoadItem>> streamLoadsForUser(AppUser user) {
    return streamLoads().map((loads) {
      switch (user.role) {
        case AppRole.dispatcher:
          return loads.where((load) => load.dispatcherId == user.dispatcherId).toList();
        case AppRole.accountant:
          return loads;
        case AppRole.paperwork:
          return loads;
        case AppRole.admin:
          return loads;
      }
    });
  }

  Future<bool> loadNumberExists(String loadNumber, {String? excludingId}) async {
    final snapshot = await loadsRef.get();
    final loads = _listFromSnapshot(snapshot, LoadItem.fromMap);
    return loads.any(
      (load) =>
          load.loadNumber.trim().toLowerCase() == loadNumber.trim().toLowerCase() &&
          load.id != excludingId,
    );
  }

  Future<void> saveLoad(LoadItem load) async {
    await loadsRef.child(load.id).set(load.toMap());
  }

  Future<void> updateLoad(String loadId, Map<String, dynamic> updates) async {
    await loadsRef.child(loadId).update(updates);
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

  Future<void> saveDocument(DocumentRecord document) async {
    await documentsRef.child(document.id).set(document.toMap());
    await refreshPaperworkStatus(document.loadId);
  }

  Future<void> setDocumentVerification(
    String documentId, {
    required bool verified,
  }) async {
    final snapshot = await documentsRef.child(documentId).get();
    final map = _asMap(snapshot.value);
    if (map.isEmpty) return;
    final loadId = (map['loadId'] ?? '').toString();
    await documentsRef.child(documentId).update({'verified': verified});
    if (loadId.isNotEmpty) {
      await refreshPaperworkStatus(loadId);
    }
  }

  Future<void> refreshPaperworkStatus(String loadId) async {
    final load = await getLoad(loadId);
    final snapshot = await documentsRef.get();
    final docs = _listFromSnapshot(snapshot, DocumentRecord.fromMap)
        .where((doc) => doc.loadId == loadId)
        .toList();

    bool hasType(String type) {
      return docs.any(
        (doc) => doc.documentType.toLowerCase() == type.toLowerCase(),
      );
    }

    final rate = hasType('Rate Confirmation');
    final pod = hasType('POD');
    final bol = hasType('BOL');
    final missing = [rate, pod, bol].where((present) => !present).length;
    final nextPaperworkStatus = missing == 0 ? 'Complete' : 'Incomplete';
    final currentInvoiceStatus = load?.invoiceStatus ?? 'Pending';
    final nextInvoiceStatus = switch (currentInvoiceStatus) {
      'Generated' || 'Sent' || 'Paid' => currentInvoiceStatus,
      _ => missing == 0 ? 'Pending' : 'Blocked',
    };

    await updateLoad(loadId, {
      'rateConfirmationUploaded': rate,
      'podUploaded': pod,
      'bolUploaded': bol,
      'missingDocumentsCount': missing,
      'paperworkStatus': nextPaperworkStatus,
      'invoiceStatus': nextInvoiceStatus,
      'updatedDate': DateTime.now().toIso8601String(),
    });
  }

  Stream<List<InvoiceRecord>> streamInvoices() {
    return invoicesRef.onValue.map(
      (event) => _listFromSnapshot(event.snapshot, InvoiceRecord.fromMap)
        ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate)),
    );
  }

  Future<String> nextInvoiceNumber() async {
    final snapshot = await invoicesRef.get();
    final invoices = _listFromSnapshot(snapshot, InvoiceRecord.fromMap);
    int max = 1000;
    for (final invoice in invoices) {
      final match = RegExp(r'(\d+)$').firstMatch(invoice.invoiceNumber);
      final number = int.tryParse(match?.group(1) ?? '');
      if (number != null && number > max) {
        max = number;
      }
    }
    return 'INV-${max + 1}';
  }

  Future<void> saveInvoice(InvoiceRecord invoice) async {
    await invoicesRef.child(invoice.id).set(invoice.toMap());
    await updateLoad(invoice.loadId, {
      'invoiceStatus': invoice.invoiceStatus,
      'paymentStatus': invoice.paymentStatus,
      'updatedDate': DateTime.now().toIso8601String(),
    });
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
