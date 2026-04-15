import 'package:cloud_functions/cloud_functions.dart';

class AutomationService {
  AutomationService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> generateInvoice(String loadId) async {
    final callable = _functions.httpsCallable('generateInvoice');
    final result = await callable.call({'loadId': loadId});
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<Map<String, dynamic>> generateCompanyInvoice({
    required String companyId,
    required String startDate,
    required String endDate,
    required List<String> driverIds,
    required String agentName,
  }) async {
    final callable = _functions.httpsCallable('generateCompanyInvoice');
    final result = await callable.call({
      'companyId': companyId,
      'startDate': startDate,
      'endDate': endDate,
      'driverIds': driverIds,
      'agentName': agentName,
    });
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }
}
