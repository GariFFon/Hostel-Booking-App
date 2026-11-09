import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/session.dart';
import 'auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.next});

  /// Where to go after signing in (a guarded page the visitor tried to open).
  final String? next;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    TextInput.finishAutofillContext();
    try {
      await ref.read(sessionProvider.notifier).signIn(email: _email.text, password: _password.text);
      if (mounted) leaveAuth(context, widget.next);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = (e.status == 401 || e.isUnauthenticated) ? "That email and password don't match. Check them and try again." : e.userMessage);
      HapticFeedback.mediumImpact();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextQuery = widget.next == null ? '' : '?next=${Uri.encodeComponent(widget.next!)}';
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to see your trips, saved stays and messages.',
      showBack: context.canPop(),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('New here?', style: context.text.bodyMedium?.copyWith(color: context.colors.mutedForeground)),
          const SizedBox(width: 4),
          AppButton(label: 'Create an account', onPressed: () => context.pushReplacement('/register$nextQuery'), variant: AppButtonVariant.ghost, expand: false, compact: true),
        ],
      ),
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              children: [
                AppTextField(
                  label: 'Email',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  prefixIcon: Icons.mail_outline_rounded,
                  enabled: !_busy,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Password',
                  controller: _password,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) => Validators.required(v, 'Enter your password'),
                  onSubmitted: (_) => _submit(),
                  prefixIcon: Icons.lock_outline_rounded,
                  enabled: !_busy,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(label: 'Forgot password?', onPressed: _busy ? null : () => context.push('/forgot-password'), variant: AppButtonVariant.ghost, expand: false, compact: true),
        ),
        if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 16)],
        AppButton(label: 'Sign in', onPressed: _submit, loading: _busy),
      ],
    );
  }
}
