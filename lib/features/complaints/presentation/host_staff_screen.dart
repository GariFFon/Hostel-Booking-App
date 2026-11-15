import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/states.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../host/application/host_providers.dart';
import '../../host/presentation/host_gate.dart';
import '../application/complaint_providers.dart';
import '../domain/complaint_models.dart';
import 'complaint_widgets.dart';

/// The owner's maintenance team: invite staff, engage platform vendors, choose where each person works, pause someone.
class HostStaffScreen extends ConsumerWidget {
  const HostStaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HostGate(
      title: 'Staff',
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Staff'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'My team'),
                Tab(text: 'Vendors'),
              ],
            ),
          ),
          body: const TabBarView(children: [_TeamTab(), _VendorsTab()]),
          floatingActionButton: Builder(
            builder: (context) => FloatingActionButton.extended(
              onPressed: () async {
                final sent = await showAppSheet<bool>(context, builder: (_) => const _InviteSheet());
                if (sent == true) {
                  ref.invalidate(ownerTeamProvider);
                  if (context.mounted) showToast(context, 'Invitation sent');
                }
              },
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Invite staff'),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action, String done) async {
  try {
    await action();
    ref.invalidate(ownerTeamProvider);
    ref.invalidate(vendorsProvider);
    if (context.mounted) showToast(context, done);
  } catch (e) {
    if (context.mounted) showErrorToast(context, e);
  }
}

class _TeamTab extends ConsumerWidget {
  const _TeamTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(ownerTeamProvider);
    final repo = ref.read(complaintRepositoryProvider);
    return team.when(
      loading: () => const CardSkeletonList(),
      error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(ownerTeamProvider)),
      data: (t) => RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(ownerTeamProvider);
          await ref.read(ownerTeamProvider.future);
        },
        child: t.staff.isEmpty && t.invites.isEmpty
            ? const EmptyState(
                icon: Icons.engineering_outlined,
                title: 'No staff yet',
                message: 'Invite an electrician, plumber, cook or anyone else by email, or engage a platform vendor. Complaints go to the right trade automatically.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (t.invites.isNotEmpty) ...[
                    const SectionTitle('Waiting to join'),
                    for (final i in t.invites) ...[
                      SurfaceCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(i.email, style: context.text.titleSmall),
                                  Text(
                                    '${tradeLabel(i.trade)} · ${i.hostels.map((h) => h.name).join(', ')} · expires ${fmtShort(i.expiresAt.toLocal())}',
                                    style: context.text.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                if (await confirmAction(
                                      context,
                                      title: 'Cancel this invitation?',
                                      message: 'The link in the email stops working.',
                                      confirmLabel: 'Cancel invitation',
                                      destructive: true,
                                    ) &&
                                    context.mounted) {
                                  await _run(context, ref, () => repo.cancelInvite(i.id), 'Invitation cancelled');
                                }
                              },
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 8),
                  ],
                  for (final s in t.staff) ...[_MemberCard(member: s), const SizedBox(height: 12)],
                ],
              ),
      ),
    );
  }
}

class _MemberCard extends ConsumerWidget {
  const _MemberCard({required this.member});
  final StaffMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.text;
    final repo = ref.read(complaintRepositoryProvider);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(member.display, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              StatusChip(member.active ? 'Active' : 'Paused', tone: member.active ? Tone.success : Tone.neutral),
            ],
          ),
          Text(
            '${tradeLabel(member.trade)}${member.isVendor ? ' · platform vendor' : ''} · ${plural(member.openJobs, 'open job')}',
            style: t.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            member.hostels.isEmpty ? 'Not assigned to any property' : 'Works at ${member.hostels.map((h) => h.name).join(', ')}',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              AppButton(
                label: 'Change properties',
                compact: true,
                expand: false,
                variant: AppButtonVariant.secondary,
                onPressed: () async {
                  final picked = await showAppSheet<List<String>>(
                    context,
                    builder: (_) => _PropertiesSheet(name: member.display, current: member.hostels.map((h) => h.id).toList()),
                  );
                  if (picked == null || !context.mounted) return;
                  await _run(context, ref, () => repo.setStaffHostels(member.userId, picked), 'Saved');
                },
              ),
              if (!member.isVendor)
                AppButton(
                  label: member.active ? 'Pause' : 'Resume',
                  compact: true,
                  expand: false,
                  variant: AppButtonVariant.ghost,
                  onPressed: () async {
                    if (member.active &&
                        !(await confirmAction(
                          context,
                          title: 'Pause ${member.display}?',
                          message: 'Their open jobs come back to your inbox and they stop receiving new ones.',
                          confirmLabel: 'Pause',
                          destructive: true,
                        ))) {
                      return;
                    }
                    if (!context.mounted) return;
                    await _run(
                      context,
                      ref,
                      () => repo.setStaffStatus(member.userId, member.active ? 'INACTIVE' : 'ACTIVE'),
                      member.active ? 'Paused' : 'Resumed',
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VendorsTab extends ConsumerWidget {
  const _VendorsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(vendorsProvider);
    final repo = ref.read(complaintRepositoryProvider);
    return vendors.when(
      loading: () => const CardSkeletonList(),
      error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(vendorsProvider)),
      data: (list) => list.isEmpty
          ? const EmptyState(
              icon: Icons.handyman_outlined,
              title: 'No vendors available',
              message: 'Vendors are professionals onboarded by the platform. None are available right now.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final v = list[i];
                return SurfaceCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.display, style: context.text.titleMedium),
                            Text(tradeLabel(v.trade), style: context.text.bodySmall),
                            Text(
                              v.hostels.isEmpty ? 'Not engaged at your properties' : 'Engaged at ${v.hostels.map((h) => h.name).join(', ')}',
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      AppButton(
                        label: v.hostels.isEmpty ? 'Engage' : 'Change',
                        compact: true,
                        expand: false,
                        variant: v.hostels.isEmpty ? AppButtonVariant.primary : AppButtonVariant.secondary,
                        onPressed: () async {
                          final picked = await showAppSheet<List<String>>(
                            context,
                            builder: (_) => _PropertiesSheet(name: v.display, current: v.hostels.map((h) => h.id).toList()),
                          );
                          if (picked == null || !context.mounted) return;
                          await _run(context, ref, () => repo.setStaffHostels(v.userId, picked), 'Saved');
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Tick the properties someone works at. Only hostels and PGs are listed: hotels have no tenants to complain.
class _PropertiesSheet extends ConsumerStatefulWidget {
  const _PropertiesSheet({required this.name, required this.current});
  final String name;
  final List<String> current;

  @override
  ConsumerState<_PropertiesSheet> createState() => _PropertiesSheetState();
}

class _PropertiesSheetState extends ConsumerState<_PropertiesSheet> {
  late final Set<String> _picked = {...widget.current};

  @override
  Widget build(BuildContext context) {
    final hostels = (ref.watch(hostHostelsProvider).value?.items ?? const []).where((h) => h.propertyType.isLongTerm).toList();
    final removing = widget.current.any((id) => !_picked.contains(id));
    return SheetFrame(
      title: 'Where does ${widget.name} work?',
      footer: AppButton(label: 'Save', onPressed: () => Navigator.of(context).pop(_picked.toList())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hostels.isEmpty) const Text('Add a hostel or PG first.'),
          for (final h in hostels)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _picked.contains(h.id),
              title: Text(h.name),
              onChanged: (v) => setState(() => v == true ? _picked.add(h.id) : _picked.remove(h.id)),
            ),
          if (removing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Open jobs at the properties you remove come back to your inbox.', style: context.text.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet();

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _email = TextEditingController();
  final _picked = <String>{};
  String _trade = 'PLUMBER';
  bool _busy = false;
  String? _error;
  Map<String, String> _fields = const {};

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final local = <String, String>{
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) 'email': 'Enter a valid email address',
      if (_picked.isEmpty) 'hostelIds': 'Pick at least one property',
    };
    if (local.isNotEmpty) return setState(() => _fields = local);
    setState(() {
      _busy = true;
      _error = null;
      _fields = const {};
    });
    try {
      await ref.read(complaintRepositoryProvider).invite(email: _email.text, trade: _trade, hostelIds: _picked.toList());
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.userMessage;
          _fields = e.fieldErrors;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hostels = (ref.watch(hostHostelsProvider).value?.items ?? const []).where((h) => h.propertyType.isLongTerm).toList();
    return SheetFrame(
      title: 'Invite staff',
      footer: AppButton(label: 'Send invitation', onPressed: _send, loading: _busy),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('They get an email with a link that works for 7 days.', style: context.text.bodyMedium),
          const SizedBox(height: 12),
          if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 12)],
          AppTextField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress, errorText: _fields['email']),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _trade,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Trade'),
            items: [for (final t in staffTrades) DropdownMenuItem(value: t, child: Text(tradeLabel(t)))],
            onChanged: _busy ? null : (v) => setState(() => _trade = v ?? _trade),
          ),
          const SizedBox(height: 12),
          Text('Works at', style: context.text.titleSmall),
          if (hostels.isEmpty) const Text('Add a hostel or PG first.'),
          for (final h in hostels)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _picked.contains(h.id),
              title: Text(h.name),
              onChanged: (v) => setState(() => v == true ? _picked.add(h.id) : _picked.remove(h.id)),
            ),
          if (_fields['hostelIds'] != null) Text(_fields['hostelIds']!, style: context.text.bodySmall?.copyWith(color: context.colors.destructive)),
        ],
      ),
    );
  }
}
