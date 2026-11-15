import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback.dart';
import '../../auth/application/session.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../domain/invite_code.dart';

/// Join a maintenance team from inside the app: paste the link (or code) from the invitation email. The invitation only works for
/// the account whose email it was sent to, so the server decides; this screen just carries the code there.
class JoinTeamScreen extends ConsumerStatefulWidget {
  const JoinTeamScreen({super.key});

  @override
  ConsumerState<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends ConsumerState<JoinTeamScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final token = parseInviteToken(_code.text);
    if (token == null) return setState(() => _error = 'Paste the link or code from the invitation email');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(complaintRepositoryProvider).acceptInvite(token);
      // The server revoked the old access token when it granted the role: reloading the user refreshes the session and the roles.
      await ref.read(sessionProvider.notifier).reload();
      if (!mounted) return;
      showToast(context, 'Welcome aboard. Your jobs will appear here.');
      context.go(Routes.staffJobs);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Scaffold(
      appBar: AppBar(title: const Text('Join a maintenance team')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('An owner invited you by email.', style: t.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Open the invitation email, copy the link (or the code at the end of it) and paste it here. Sign in with the same email address the invitation was sent to.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 12)],
          AppTextField(
            label: 'Invitation link or code',
            controller: _code,
            maxLines: 3,
            minLines: 2,
            autofillHints: const [],
            onChanged: (_) => _error == null ? null : setState(() => _error = null),
          ),
          const SizedBox(height: 16),
          AppButton(label: 'Join the team', onPressed: _busy ? null : _join, loading: _busy),
        ],
      ),
    );
  }
}
