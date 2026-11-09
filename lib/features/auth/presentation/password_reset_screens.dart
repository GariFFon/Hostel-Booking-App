import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback.dart';
import 'auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_email.text);
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return AuthScaffold(
        title: 'Check your inbox',
        subtitle: "If ${_email.text.trim()} has an account, we've sent a link to reset the password. It can take a minute to arrive.",
        showBack: true,
        children: [
          AppButton(label: 'I have a reset code', onPressed: () => context.push('/reset-password')),
          const SizedBox(height: 12),
          AppButton(label: 'Back to sign in', onPressed: () => context.go('/login'), variant: AppButtonVariant.secondary),
        ],
      );
    }
    return AuthScaffold(
      title: 'Reset your password',
      subtitle: "Enter the email you signed up with and we'll send you a reset link.",
      showBack: true,
      children: [
        Form(
          key: _form,
          child: AppTextField(
            label: 'Email',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            validator: Validators.email,
            onSubmitted: (_) => _submit(),
            prefixIcon: Icons.mail_outline_rounded,
            enabled: !_busy,
          ),
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 16)],
        AppButton(label: 'Send reset link', onPressed: _submit, loading: _busy),
      ],
    );
  }
}

/// For people who copied the token from the reset email: paste it here and choose a new password.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.token});
  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _token = TextEditingController(text: widget.token ?? '');
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(token: _token.text, password: _password.text);
      if (!mounted) return;
      showToast(context, 'Password updated. Sign in with your new password.');
      context.go('/login');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.fieldErrors.isNotEmpty || e.status == 400 || e.status == 422 ? 'That code is invalid or has expired. Request a new reset link.' : e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Choose a new password',
      subtitle: 'Paste the code from the reset email, then pick a new password.',
      showBack: true,
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              AppTextField(
                label: 'Reset code',
                controller: _token,
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().length < 20) ? 'Paste the full code from the email' : null,
                enabled: !_busy,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'New password',
                controller: _password,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.newPassword,
                helper: 'At least 8 characters.',
                onSubmitted: (_) => _submit(),
                enabled: !_busy,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 16)],
        AppButton(label: 'Update password', onPressed: _submit, loading: _busy),
        const SizedBox(height: 4),
        Align(child: Text('Reset links expire after a while.', style: context.text.bodySmall)),
      ],
    );
  }
}
