import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/settings_tile.dart';
import '../../auth/application/session.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/sign_in_prompt.dart';
import '../../notifications/application/notification_providers.dart';

/// The Account tab: who you are, your inbox and settings, hosting, appearance, sign out.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: user == null ? const _SignedOut() : _SignedIn(user: user),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: const [
        SizedBox(
          height: 420,
          child: SignInPrompt(
            icon: Icons.person_outline_rounded,
            title: 'Sign in to book',
            message: 'Create an account to book stays, save favourites and manage your trips.',
            next: Routes.account,
          ),
        ),
        SizedBox(height: 8),
        SettingsGroup(title: 'Appearance', children: [_ThemeRow()]),
      ],
    );
  }
}

class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.user});
  final AppUser user;

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(context, title: 'Sign out?', message: 'You can sign back in any time.', confirmLabel: 'Sign out', cancelLabel: 'Stay signed in', destructive: true);
    if (!ok) return;
    await ref.read(sessionProvider.notifier).signOut();
  }

  Future<void> _becomeHost(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(
      context,
      title: 'Start hosting?',
      message: 'This adds hosting to your account. You can list stays, manage bookings and reply to reviews. Your guest account stays as it is.',
      confirmLabel: 'Start hosting',
      cancelLabel: 'Not now',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(sessionProvider.notifier).becomeHost();
      if (context.mounted) context.push(Routes.host);
    } on ApiException catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  Future<void> _resend(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).resendVerification(user.email);
      if (context.mounted) showToast(context, 'Verification email sent to ${user.email}');
    } on ApiException catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Row(
          children: [
            Avatar(name: user.displayName, url: user.avatarUrl, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: t.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(user.email, style: t.bodyMedium?.copyWith(color: c.mutedForeground), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        if (!user.emailVerified) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.tint(c.warning), borderRadius: Radii.baseR, border: Border.all(color: c.warning.withValues(alpha: 0.35))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verify your email', style: t.titleSmall),
                const SizedBox(height: 2),
                Text('Confirm ${user.email} so we can send booking confirmations.', style: t.bodyMedium),
                const SizedBox(height: 8),
                AppButton(label: 'Resend email', onPressed: () => _resend(context, ref), variant: AppButtonVariant.secondary, expand: false, compact: true),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        SettingsGroup(
          title: 'You',
          children: [
            SettingsTile(icon: Icons.notifications_none_rounded, title: 'Notifications', subtitle: unread > 0 ? '$unread unread' : 'You are all caught up', badge: unread, onTap: () => context.push(Routes.notifications)),
            SettingsTile(icon: Icons.person_outline_rounded, title: 'Personal details', subtitle: 'Name and mobile number', onTap: () => context.push(Routes.profile)),
            SettingsTile(icon: Icons.star_outline_rounded, title: 'Your reviews', onTap: () => context.push(Routes.myReviews)),
            if (user.hasPassword) SettingsTile(icon: Icons.lock_outline_rounded, title: 'Change password', onTap: () => context.push(Routes.password)),
            SettingsTile(icon: Icons.tune_rounded, title: 'Notification settings', onTap: () => context.push(Routes.notificationSettings)),
          ],
        ),
        const SizedBox(height: 24),
        SettingsGroup(
          title: 'Hosting',
          children: [
            if (user.isOwner)
              SettingsTile(icon: Icons.home_work_outlined, title: 'Switch to hosting', subtitle: 'Bookings, listings and reviews', onTap: () => context.push(Routes.host))
            else
              SettingsTile(icon: Icons.add_home_work_outlined, title: 'Become a host', subtitle: 'List your hostel or PG', onTap: () => _becomeHost(context, ref)),
          ],
        ),
        const SizedBox(height: 24),
        const SettingsGroup(title: 'Appearance', children: [_ThemeRow()]),
        const SizedBox(height: 24),
        SettingsGroup(children: [SettingsTile(icon: Icons.logout_rounded, title: 'Sign out', destructive: true, onTap: () => _signOut(context, ref))]),
      ],
    );
  }
}

class _ThemeRow extends ConsumerWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: AppSegmented<ThemeMode>(
        semanticLabel: 'Theme',
        options: const [(value: ThemeMode.system, label: 'System'), (value: ThemeMode.light, label: 'Light'), (value: ThemeMode.dark, label: 'Dark')],
        value: mode,
        onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
      ),
    );
  }
}
