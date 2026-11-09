import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';

/// What a tab shows to a signed-out visitor: why signing in helps, and the two ways to do it. [next] returns them here afterwards.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.icon, required this.title, required this.message, this.next});

  final IconData icon;
  final String title;
  final String message;
  final String? next;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = next == null ? '' : '?next=${Uri.encodeComponent(next!)}';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                child: Icon(icon, size: 32, color: c.accentForeground),
              ),
              const SizedBox(height: 20),
              Text(title, textAlign: TextAlign.center, style: context.text.headlineSmall),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: c.mutedForeground)),
              const SizedBox(height: 24),
              AppButton(label: 'Sign in', onPressed: () => context.push('/login$q')),
              const SizedBox(height: 10),
              AppButton(label: 'Create an account', onPressed: () => context.push('/register$q'), variant: AppButtonVariant.secondary),
            ],
          ),
        ),
      ),
    );
  }
}
