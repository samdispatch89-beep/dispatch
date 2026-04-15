import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_role.dart';
import '../models/app_user.dart';
import '../responsive/breakpoints.dart';
import '../services/error_dialog_service.dart';
import '../services/realtime_service.dart';
import '../shared/widgets/responsive_page_container.dart';

class AdminRegistration extends StatefulWidget {
  const AdminRegistration({super.key, this.bootstrapMode = false});

  final bool bootstrapMode;

  @override
  State<AdminRegistration> createState() => _AdminRegistrationState();
}

class _AdminRegistrationState extends State<AdminRegistration> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.trim().length < 6) {
      await ErrorDialogService.show(
        context,
        message: 'Enter a name, email, and password with 6+ characters.',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _email.text.trim(),
            password: _password.text.trim(),
          );

      await credential.user?.updateDisplayName(_name.text.trim());
      final user = AppUser(
        uid: credential.user!.uid,
        name: _name.text.trim(),
        email: _email.text.trim(),
        role: AppRole.admin,
        dispatcherId: '',
        active: true,
      );

      await RealtimeService.instance.saveUser(user);

      if (!mounted) return;
      _name.clear();
      _email.clear();
      _password.clear();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      await ErrorDialogService.show(context, message: e.message ?? e.code);
    } finally {
      if (mounted) {
        _name.clear();
        _email.clear();
        _password.clear();
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.bootstrapMode ? 'Create First Admin' : 'Admin Registration',
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ResponsivePageContainer(
            padding: EdgeInsets.all(AppBreakpoints.pagePadding(context)),
            child: SizedBox(
              width: AppBreakpoints.isMobile(context) ? double.infinity : 520,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Create an admin account to manage users, company settings, invoices, paperwork, and reporting.',
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _showPassword = !_showPassword);
                            },
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        obscureText: !_showPassword,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Create admin account'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
