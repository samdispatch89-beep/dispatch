import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_options.dart';

class AdminAuthService {
  /// Create a new Firebase Authentication user without signing out the current admin.
  /// Uses a secondary FirebaseApp instance to create the user, then deletes it.
  static Future<UserCredential> createUser(String email, String password) async {
    final name = 'admin-create-${DateTime.now().millisecondsSinceEpoch}';
    final app = await Firebase.initializeApp(name: name, options: DefaultFirebaseOptions.currentPlatform);
    try {
      final auth = FirebaseAuth.instanceFor(app: app);
      final cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
      return cred;
    } finally {
      await app.delete();
    }
  }
}
