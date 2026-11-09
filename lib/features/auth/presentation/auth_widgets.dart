import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/brand.dart';

/// Shared frame for the sign-in family of screens: brand mark, headline, scrollable keyboard-safe body.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.children, this.showBack = false, this.footer});

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(),
                  const SizedBox(height: 24),
                  Text(title, style: t.headlineLarge),
                  const SizedBox(height: 8),
                  Text(subtitle, style: t.bodyLarge?.copyWith(color: context.colors.mutedForeground)),
                  const SizedBox(height: 28),
                  ...children,
                  if (footer != null) ...[const SizedBox(height: 24), footer!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline error banner above a form's submit button (for failures that belong to no single field).
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.tint(c.destructive), borderRadius: Radii.baseR),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 20, color: c.destructive),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: context.text.bodyMedium?.copyWith(color: c.destructive))),
          ],
        ),
      ),
    );
  }
}

/// Leaves sign-in / registration once a session exists. Relying on the router's redirect alone does not move a sign-in screen
/// that was *pushed* over another page (the Reserve -> sign in -> checkout detour), so this is explicit:
/// pushed -> pop back, then continue to [next] unless that is already where we landed; not pushed -> go to [next].
void leaveAuth(BuildContext context, String? next) {
  final router = GoRouter.of(context);
  final target = Routes.safeNext(next);
  if (!router.canPop()) {
    router.go(target ?? Routes.explore);
    return;
  }
  router.pop();
  if (target == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final here = router.routeInformationProvider.value.uri.toString();
    if (here != target) router.push(target);
  });
}
