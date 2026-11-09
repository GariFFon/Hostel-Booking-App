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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.next});
  final String? next;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, String> _server = const {};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _server = const {};
    });
    TextInput.finishAutofillContext();
    try {
      await ref.read(sessionProvider.notifier).signUp(
            fullName: _name.text,
            email: _email.text,
            password: _password.text,
            phone: _phone.text.trim().isEmpty ? null : Validators.normaliseMobile(_phone.text),
          );
      if (mounted) leaveAuth(context, widget.next);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _server = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? (e.code == 'CONFLICT' ? 'An account with this email already exists. Try signing in instead.' : e.userMessage) : null;
      });
      HapticFeedback.mediumImpact();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextQuery = widget.next == null ? '' : '?next=${Uri.encodeComponent(widget.next!)}';
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Book hostels and PGs across India in a few taps.',
      showBack: context.canPop(),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Already have an account?', style: context.text.bodyMedium?.copyWith(color: context.colors.mutedForeground)),
          const SizedBox(width: 4),
          AppButton(label: 'Sign in', onPressed: () => context.pushReplacement('/login$nextQuery'), variant: AppButtonVariant.ghost, expand: false, compact: true),
        ],
      ),
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              children: [
                AppTextField(
                  label: 'Full name',
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: Validators.fullName,
                  errorText: _server['fullName'],
                  enabled: !_busy,
                  maxLength: 100,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Email',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  errorText: _server['email'],
                  enabled: !_busy,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Mobile number',
                  optional: true,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  prefixText: '+91  ',
                  validator: (v) => Validators.mobile(v, optional: true),
                  errorText: _server['phone'],
                  enabled: !_busy,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Password',
                  controller: _password,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.newPassword,
                  errorText: _server['password'],
                  helper: 'At least 8 characters.',
                  onSubmitted: (_) => _submit(),
                  enabled: !_busy,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 16)],
        AppButton(label: 'Create account', onPressed: _submit, loading: _busy),
      ],
    );
  }
}
