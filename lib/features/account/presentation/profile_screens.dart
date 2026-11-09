import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback.dart';
import '../../auth/application/session.dart';
import '../../auth/presentation/auth_widgets.dart';

/// Name and mobile number. The email is shown but read-only (it is the sign-in identity).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  bool _busy = false;
  String? _error;
  Map<String, String> _server = const {};

  @override
  void initState() {
    super.initState();
    final u = ref.read(currentUserProvider);
    _name = TextEditingController(text: u?.fullName ?? '');
    final digits = (u?.phone ?? '').replaceAll(RegExp(r'\D'), '');
    _phone = TextEditingController(text: digits.length >= 10 ? digits.substring(digits.length - 10) : '');
    _email = TextEditingController(text: u?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _server = const {};
    });
    try {
      await ref.read(sessionProvider.notifier).updateProfile(
            fullName: _name.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : Validators.normaliseMobile(_phone.text),
          );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      showToast(context, 'Details saved');
      FocusScope.of(context).unfocus();
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _server = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.userMessage : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Personal details',
      subtitle: 'Hosts see your name on bookings. Your mobile number is shared only once a stay is confirmed.',
      showBack: true,
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
                  maxLength: 100,
                  enabled: !_busy,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Mobile number',
                  optional: true,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  prefixText: '+91  ',
                  validator: (v) => Validators.mobile(v, optional: true),
                  errorText: _server['phone'],
                  onSubmitted: (_) => _save(),
                  enabled: !_busy,
                ),
                const SizedBox(height: 16),
                AppTextField(label: 'Email', controller: _email, readOnly: true, enabled: false, helper: "Your email is your sign-in and can't be changed here."),
              ],
            ),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 16), FormErrorBanner(_error!)],
        const SizedBox(height: 24),
        AppButton(label: 'Save', onPressed: _save, loading: _busy),
      ],
    );
  }
}

/// Current + new password. Changing it signs out every other device (the server hands this device a fresh session).
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, String> _server = const {};

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _server = const {};
    });
    TextInput.finishAutofillContext();
    try {
      await ref.read(sessionProvider.notifier).changePassword(currentPassword: _current.text, newPassword: _next.text);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      showToast(context, 'Password changed. Other devices were signed out.');
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _server = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.userMessage : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AuthScaffold(
      title: 'Change password',
      subtitle: 'Choose something you do not use anywhere else. Other devices will be signed out.',
      showBack: true,
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              children: [
                AppTextField(
                  label: 'Current password',
                  controller: _current,
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) => Validators.required(v, 'Enter your current password'),
                  errorText: _server['currentPassword'],
                  enabled: !_busy,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'New password',
                  controller: _next,
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) {
                    final e = Validators.newPassword(v);
                    if (e != null) return e;
                    if (v == _current.text) return 'Choose a different password from the current one';
                    return null;
                  },
                  errorText: _server['newPassword'],
                  helper: 'At least 8 characters.',
                  enabled: !_busy,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Repeat new password',
                  controller: _confirm,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => v == _next.text ? null : 'The passwords do not match',
                  onSubmitted: (_) => _save(),
                  enabled: !_busy,
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 16), FormErrorBanner(_error!)],
        const SizedBox(height: 24),
        AppButton(label: 'Change password', onPressed: _save, loading: _busy),
        const SizedBox(height: 12),
        Text('Forgot it? Sign out and use "Forgot password" on the sign-in screen.', style: context.text.bodySmall?.copyWith(color: c.mutedForeground)),
      ],
    );
  }
}
