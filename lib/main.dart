import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/app_user.dart';
import 'screens/admin_registration.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/realtime_service.dart';
import 'services/session_cache_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      Firebase.app();
    }
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') rethrow;
    Firebase.app();
  }

  unawaited(
    RealtimeService.instance.seedDefaultDataIfEmpty().catchError((_) {}),
  );

  final themeController = ThemeController();
  await themeController.load();

  runApp(
    ChangeNotifierProvider.value(
      value: themeController,
      child: const DispatchApp(),
    ),
  );
}

class DispatchApp extends StatelessWidget {
  const DispatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (context, themeController, _) {
        return MaterialApp(
          title: 'Dispatch Management',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeController.themeMode,
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.hasError) {
          return const _StartupIssueScreen(
            title: 'Authentication failed to initialize',
            message: 'Please restart the app and try again.',
          );
        }

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(label: 'Checking session...');
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return const LoginScreen();
        }

        return FutureBuilder<AppUser?>(
          future: _resolveProfile(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen(label: 'Loading your profile...');
            }

            if (profileSnapshot.hasError) {
              return _StartupIssueScreen(
                title: 'Profile unavailable',
                message:
                    'The app could not load your Realtime Database profile. Check the Firebase database URL and rules, then retry.',
                primaryLabel: 'Retry',
                onPrimary: () async {
                  await SessionCacheService.instance.clear();
                  await FirebaseAuth.instance.signOut();
                },
              );
            }

            final appUser = profileSnapshot.data;
            if (appUser == null) {
              return const AdminRegistration(bootstrapMode: true);
            }

            if (!appUser.active) {
              return const _InactiveAccountScreen();
            }

            return HomeShell(user: appUser);
          },
        );
      },
    );
  }

  Future<AppUser?> _resolveProfile(String uid) async {
    final cachedUser = await SessionCacheService.instance.loadUser(uid);
    try {
      final liveUser = await RealtimeService.instance
          .getUser(uid)
          .timeout(const Duration(seconds: 12));
      if (liveUser != null) {
        await SessionCacheService.instance.saveUser(liveUser);
      }
      return liveUser ?? cachedUser;
    } catch (_) {
      if (cachedUser != null) return cachedUser;
      rethrow;
    }
  }
}

class _StartupIssueScreen extends StatelessWidget {
  const _StartupIssueScreen({
    required this.title,
    required this.message,
    this.primaryLabel = 'Sign out',
    this.onPrimary,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final Future<void> Function()? onPrimary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 52,
                      color: Color(0xFF8B6BFF),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF9AA7C7),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () async {
                        if (onPrimary != null) {
                          await onPrimary!.call();
                        } else {
                          await SessionCacheService.instance.clear();
                          await FirebaseAuth.instance.signOut();
                        }
                      },
                      child: Text(primaryLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _InactiveAccountScreen extends StatelessWidget {
  const _InactiveAccountScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 56,
                color: Color(0xFF5B7284),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your account is currently inactive.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please contact your administrator for access.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await SessionCacheService.instance.clear();
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
