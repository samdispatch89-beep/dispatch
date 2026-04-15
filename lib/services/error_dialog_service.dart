import 'dart:async';

import 'package:flutter/material.dart';

class ErrorDialogService {
  ErrorDialogService._();

  static Future<void> show(
    BuildContext context, {
    required String message,
    String title = 'Error',
  }) async {
    if (!context.mounted) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    var closed = false;
    late final Timer timer;

    void closeDialog() {
      if (closed || !navigator.mounted || !navigator.canPop()) return;
      closed = true;
      navigator.pop();
    }

    timer = Timer(const Duration(seconds: 10), closeDialog);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: closeDialog,
              child: const Text('Close'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      closed = true;
      timer.cancel();
    });
  }
}
