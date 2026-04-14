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
}
