import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../responsive/breakpoints.dart';
import '../services/error_dialog_service.dart';
import '../shared/widgets/responsive_page_container.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;

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
      _email.clear();
      _password.clear();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      await ErrorDialogService.show(context, message: e.message ?? e.code);
    } finally {
      if (mounted) {
        _email.clear();
        _password.clear();
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dashboardColors;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.4,
            colors: [colors.heroGradientStart, colors.background, colors.panel],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: ResponsivePageContainer(
              padding: EdgeInsets.all(AppBreakpoints.pagePadding(context)),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 920;
                  final heroPanel = Container(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        colors: [
                          colors.heroGradientStart,
                          colors.heroGradientEnd,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'DISPATCH FLOW',
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 42),
                        Text(
                          'Dispatch\nManagement\nSystem',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Smarter dispatch. Stronger business. One role-based workspace for operations, paperwork, accounting, and reporting.',
                          style: TextStyle(color: colors.muted, height: 1.6),
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
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in with your assigned company account to access dispatcher, accountant, paperwork, or admin tools.',
                            style: TextStyle(color: colors.muted),
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
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(
                                    () => _showPassword = !_showPassword,
                                  );
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
                            height: 52,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    colors.primary,
                                    colors.primary.withBlue(255),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _loading ? null : _signIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
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
    final colors = context.dashboardColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
