import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/tokens.dart';

/// A short, non-blocking message. Replaces the previous one instead of queueing. Errors are red and say what to do.
void showToast(BuildContext context, String message, {bool error = false, String? actionLabel, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final c = context.colors;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? c.destructive : null,
        duration: const Duration(seconds: 4),
        action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}, textColor: error ? Colors.white : null),
      ),
    );
}

void showErrorToast(BuildContext context, Object error) {
  HapticFeedback.mediumImpact();
  showToast(context, errorText(error), error: true);
}

/// Yes/no confirmation. The destructive choice is named for what it does ("Cancel booking", not "OK").
/// Platform-native: a Cupertino alert on iOS, a Material dialog on Android.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Keep',
  bool destructive = false,
}) async {
  final ios = Theme.of(context).platform == TargetPlatform.iOS;
  final result = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = ctx.colors;
      Widget action(String label, bool value, {bool danger = false, bool bold = false}) {
        if (ios) {
          return CupertinoDialogAction(
            isDestructiveAction: danger,
            isDefaultAction: bold,
            onPressed: () => Navigator.of(ctx).pop(value),
            child: Text(label),
          );
        }
        return TextButton(
          onPressed: () => Navigator.of(ctx).pop(value),
          style: TextButton.styleFrom(foregroundColor: danger ? c.destructive : c.primary, minimumSize: const Size(64, 44)),
          child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w600 : FontWeight.w500)),
        );
      }

      return AlertDialog.adaptive(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          action(cancelLabel, false, bold: !destructive),
          action(confirmLabel, true, danger: destructive, bold: destructive),
        ],
      );
    },
  );
  return result ?? false;
}
