import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_registration.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? e.code)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.4,
            colors: [Color(0xFF1D1340), Color(0xFF0A0F1D), Color(0xFF050812)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 920;
                  final heroPanel = Container(
                        padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF22164A), Color(0xFF101727)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: const Color(0xFF2A3554)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.local_shipping_outlined, color: Color(0xFF8B6BFF)),
                                SizedBox(width: 10),
                                Text(
                                  'DISPATCH FLOW',
                                  style: TextStyle(
                                    color: Color(0xFFA78BFA),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 42),
                            Text(
                              'Dispatch\nManagement\nSystem',
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Smarter dispatch. Stronger business. One role-based workspace for operations, paperwork, accounting, and reporting.',
                              style: TextStyle(color: Color(0xFF99A4C2), height: 1.6),
                            ),
                            const SizedBox(height: 28),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: const [
                                _FeaturePill(label: 'Live Dashboards'),
                                _FeaturePill(label: 'Load Tracking'),
                                _FeaturePill(label: 'Paperwork'),
                                _FeaturePill(label: 'Invoices'),
                                _FeaturePill(label: 'Revenue Analytics'),
                                _FeaturePill(label: 'Realtime Sync'),
                              ],
                            ),
                          ],
                        ),
                      );
                  final loginCard = Card(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Welcome back',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Sign in with your assigned company account to access dispatcher, accountant, paperwork, or admin tools.',
                                style: TextStyle(color: Color(0xFF99A4C2)),
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                controller: _email,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _password,
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                obscureText: true,
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 52,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF6C4DFF), Color(0xFF7A2CFF)],
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x556C4DFF),
                                        blurRadius: 18,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _signIn,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Sign in'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const AdminRegistration(),
                                    ),
                                  );
                                },
                                child: const Text('Bootstrap first admin'),
                              ),
                            ],
                          ),
                        ),
                      );

                  if (stacked) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        heroPanel,
                        const SizedBox(height: 18),
                        loginCard,
                      ],
                    );
                  }

                  return IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(flex: 5, child: heroPanel),
                        const SizedBox(width: 22),
                        Expanded(flex: 4, child: loginCard),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151D33),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2A3554)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFD8E0F2),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
