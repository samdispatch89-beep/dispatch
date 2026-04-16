import 'package:flutter/material.dart';

class ErrorDialogService {
  ErrorDialogService._();

  static Future<void> show(
    BuildContext context, {
    required String message,
    String title = 'Error',
  }) async {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(days: 1),
        showCloseIcon: true,
        dismissDirection: DismissDirection.none,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
      ),
    );
  }
}
