import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/brand.dart';
import '../application/session.dart';

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
            Expanded(
              child: Text(message, style: context.text.bodyMedium?.copyWith(color: c.destructive)),
            ),
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

/// "or" divider + "Continue with Google". Closing the Google sheet is silent; real failures are shown in words.
class GoogleSignInSection extends ConsumerStatefulWidget {
  const GoogleSignInSection({super.key, required this.next, this.enabled = true});
  final String? next;
  final bool enabled;

  @override
  ConsumerState<GoogleSignInSection> createState() => _GoogleSignInSectionState();
}

class _GoogleSignInSectionState extends ConsumerState<GoogleSignInSection> {
  bool _busy = false;
  String? _error;

  Future<void> _go() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await ref.read(googleSignerProvider).idToken();
      if (token == null) return; // closed the Google sheet
      await ref.read(sessionProvider.notifier).signInWithGoogle(token);
      if (mounted) leaveAuth(context, widget.next);
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _error = e.userMessage);
    } catch (_) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _error = "Google sign-in didn't work. Try again, or use your email and password.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Divider(color: c.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or', style: context.text.bodySmall),
            ),
            Expanded(child: Divider(color: c.border)),
          ],
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 12)],
        AppButton(
          label: 'Continue with Google',
          icon: Icons.g_mobiledata_rounded,
          variant: AppButtonVariant.secondary,
          loading: _busy,
          onPressed: widget.enabled ? _go : null,
        ),
      ],
    );
  }
}
