import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/paged_scroll.dart';
import '../../../shared/widgets/price_breakdown.dart';
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/states.dart';
import '../../bookings/presentation/booking_action_sheets.dart';
import '../../host/presentation/host_gate.dart';
import '../../rent/presentation/receipt_widgets.dart';
import '../application/tenancy_providers.dart';
import '../domain/tenancy_models.dart';
import 'add_tenant_sheet.dart';
import 'leaving_widgets.dart';
import 'my_stay_screen.dart';

/// The owner's side: requests for beds, and the people who live at their hostels and PGs.
class HostTenantsScreen extends ConsumerWidget {
  const HostTenantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HostGate(
      title: 'Tenants',
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Tenants'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Requests'),
                Tab(text: 'Stays'),
              ],
            ),
          ),
          body: const TabBarView(children: [_RequestsTab(), _StaysTab()]),
          floatingActionButton: Builder(
            builder: (context) => FloatingActionButton.extended(
              onPressed: () async {
                final added = await showAddTenantSheet(context);
                if (added == true) ref.invalidate(hostTenanciesProvider);
              },
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Add tenant'),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _run(BuildContext context, WidgetRef ref, Future<Object?> Function() action, String done) async {
  try {
    await action();
    ref.invalidate(hostApplicationsProvider);
    ref.invalidate(hostTenanciesProvider);
    if (context.mounted) showToast(context, done);
  } catch (e) {
    if (context.mounted) showErrorToast(context, e);
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(tenancyRepositoryProvider);
    return PagedScroll<TenancyApplication>(
      value: ref.watch(hostApplicationsProvider),
      onLoadMore: () => ref.read(hostApplicationsProvider.notifier).loadMore(),
      onRefresh: () async {
        ref.invalidate(hostApplicationsProvider);
        await ref.read(hostApplicationsProvider.future);
      },
      empty: const EmptyState(icon: Icons.groups_outlined, title: 'No requests waiting', message: 'When a student asks for a bed, it shows up here.'),
      itemBuilder: (context, a, _) => _RequestCard(
        app: a,
        onApprove: () async {
          final terms = await showAppSheet<({String? unitId, int? rent, int? deposit})>(context, builder: (_) => _ApproveSheet(app: a));
          if (terms == null || !context.mounted) return;
          await _run(
            context,
            ref,
            () => repo.approve(a.id, unitId: terms.unitId, rentPaise: terms.rent, depositPaise: terms.deposit),
            'Approved. A bed is reserved.',
          );
        },
        onReject: () async {
          final r = await showReasonSheet(
            context,
            title: 'Decline this request?',
            message: 'The student is told why.',
            confirmLabel: 'Decline',
            hint: 'e.g. We only take final-year students',
          );
          if (r == null || !context.mounted) return;
          await _run(context, ref, () => repo.reject(a.id, r.reason), 'Declined');
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.app, required this.onApprove, required this.onReject});
  final TenancyApplication app;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(app.applicant.display, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              StatusChip(app.status.label, tone: applicationTone(app.status)),
            ],
          ),
          Text('${app.hostel.name} · ${app.roomType.name}', style: t.bodySmall),
          const SizedBox(height: 8),
          Text('Move-in ${fmtLong(app.moveIn)}${app.tenureMonths != null ? ' · ${app.tenureMonths} months' : ''}', style: t.bodyMedium),
          if (app.occupation != null) Text(app.occupation!, style: t.bodySmall),
          Text('Emergency contact: ${app.emergencyContact.name} · ${app.emergencyContact.phone}', style: t.bodySmall),
          if (app.message != null) ...[const SizedBox(height: 8), Text(app.message!, style: t.bodyMedium)],
          if (app.can('approve')) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(label: 'Approve', onPressed: onApprove, compact: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(label: 'Decline', onPressed: onReject, variant: AppButtonVariant.secondary, compact: true),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ApproveSheet extends ConsumerStatefulWidget {
  const _ApproveSheet({required this.app});
  final TenancyApplication app;

  @override
  ConsumerState<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends ConsumerState<_ApproveSheet> {
  final _rent = TextEditingController();
  final _deposit = TextEditingController();
  String? _unitId; // null = assign automatically

  @override
  void dispose() {
    _rent.dispose();
    _deposit.dispose();
    super.dispose();
  }

  int? _paise(TextEditingController c) {
    final v = double.tryParse(c.text.trim());
    return v == null ? null : (v * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final free = ref.watch(freeUnitsProvider(widget.app.roomType.id));
    return SheetFrame(
      title: 'Approve request',
      footer: AppButton(
        label: 'Approve',
        onPressed: () => Navigator.of(context).pop((unitId: _unitId, rent: _paise(_rent), deposit: _paise(_deposit))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.app.applicant.display} · ${widget.app.roomType.name}. Leave the fields empty to use the room\'s rent and your default deposit.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text('Bed', style: t.titleSmall),
          const SizedBox(height: 4),
          free.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
            error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(freeUnitsProvider(widget.app.roomType.id))),
            data: (units) => RadioGroup<String?>(
              groupValue: _unitId,
              onChanged: (v) => setState(() => _unitId = v),
              child: Column(
                children: [
                  const RadioListTile<String?>(value: null, contentPadding: EdgeInsets.zero, title: Text('Assign automatically')),
                  for (final u in units) RadioListTile<String?>(value: u.id, contentPadding: EdgeInsets.zero, title: Text(u.display)),
                  if (units.isEmpty) Text('No beds are free. Add or free a bed first.', style: t.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Rent per month (₹)',
            optional: true,
            controller: _rent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Deposit (₹)',
            optional: true,
            helper: '0 for no deposit',
            controller: _deposit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
    );
  }
}

class _StaysTab extends ConsumerWidget {
  const _StaysTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(tenancyRepositoryProvider);
    return PagedScroll<Tenancy>(
      value: ref.watch(hostTenanciesProvider),
      onLoadMore: () => ref.read(hostTenanciesProvider.notifier).loadMore(),
      onRefresh: () async {
        ref.invalidate(hostTenanciesProvider);
        await ref.read(hostTenanciesProvider.future);
      },
      empty: const EmptyState(
        icon: Icons.groups_outlined,
        title: 'No stays yet',
        message: 'Approve a request to see the stay here. To add a tenant directly, use the website.',
      ),
      itemBuilder: (context, x, _) => _StayRow(
        tenancy: x,
        onDeposit: () async {
          final d = await showAppSheet<({String method, String reference})>(context, builder: (_) => _DepositSheet(tenancy: x));
          if (d == null || !context.mounted) return;
          await _run(context, ref, () => repo.recordDeposit(x.id, method: d.method, reference: d.reference), 'Deposit recorded');
        },
        onActivate: () async {
          if (await confirmAction(
                context,
                title: 'Record move-in?',
                message: '${x.tenantLabel} moves into bed ${x.unit.label} and the stay starts today.',
                confirmLabel: 'Record move-in',
              ) &&
              context.mounted) {
            await _run(context, ref, () => repo.activate(x.id), 'Stay started');
          }
        },
        onNotice: () async {
          final n = await showNoticeSheet(context, noticeDays: x.noticeDays, owner: true);
          if (n == null || !context.mounted) return;
          await _run(context, ref, () => repo.serveNotice(x.id, moveOutDate: n.date, reason: n.reason), 'Notice served. The tenant has been told.');
        },
        onWithdrawNotice: () => _run(context, ref, () => repo.ownerWithdrawNotice(x.id), 'Notice withdrawn'),
        onMoveOut: () async {
          final m = await showMoveOutSheet(context, x);
          if (m == null || !context.mounted) return;
          await _run(context, ref, () => repo.moveOut(x.id, movedOutOn: m.date, note: m.note), 'Move-out recorded. You can settle the deposit now.');
        },
        onSettle: () => showHostSettlementSheet(context, x),
        onCancel: () async {
          final r = await showReasonSheet(
            context,
            title: 'Cancel this stay?',
            message: 'The bed becomes free. Only stays that have not started can be cancelled.',
            confirmLabel: 'Cancel stay',
            hint: 'Tell the tenant why',
          );
          if (r == null || !context.mounted) return;
          await _run(context, ref, () => repo.cancel(x.id, r.reason), 'Stay cancelled');
        },
      ),
    );
  }
}

class _StayRow extends StatelessWidget {
  const _StayRow({
    required this.tenancy,
    required this.onDeposit,
    required this.onActivate,
    required this.onCancel,
    required this.onNotice,
    required this.onWithdrawNotice,
    required this.onMoveOut,
    required this.onSettle,
  });
  final Tenancy tenancy;
  final VoidCallback onNotice;
  final VoidCallback onWithdrawNotice;
  final VoidCallback onMoveOut;
  final VoidCallback onSettle;
  final VoidCallback onDeposit;
  final VoidCallback onActivate;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final x = tenancy;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(x.tenantLabel, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              StatusChip(x.status.label, tone: tenancyTone(x.status)),
            ],
          ),
          Text('${x.hostel.name} · ${x.roomType.name} · bed ${x.unit.label}', style: t.bodySmall),
          const SizedBox(height: 8),
          Text('${money(x.rentPaise)} / month · from ${fmtLong(x.start)}', style: t.bodyMedium?.tabular),
          Text(
            x.deposit.status == 'NONE' ? 'No deposit' : 'Deposit ${money(x.depositPaise)} · ${x.deposit.isReceived ? 'received' : 'due'}',
            style: t.bodySmall,
          ),
          if (x.depositWarning != null) ...[
            const SizedBox(height: 6),
            Text(x.depositWarning!, style: t.bodySmall?.copyWith(color: context.colors.warning)),
          ],
          if (x.notice != null && x.status == TenancyStatus.notice) ...[
            const SizedBox(height: 6),
            Text(
              'Moving out ${x.notice!.moveOut == null ? '' : fmtLong(x.notice!.moveOut!)} · ${x.notice!.byTenant ? 'the tenant gave notice' : 'you served notice'}',
              style: t.bodySmall?.copyWith(color: context.colors.warning),
            ),
          ],
          if (x.status == TenancyStatus.ended && x.settlement != null) ...[
            const SizedBox(height: 6),
            Text(
              'Deposit settlement: ${SettlementStatus.values.firstWhere((s) => s.name == _camel(x.settlement!.status), orElse: () => SettlementStatus.unknown).label}',
              style: t.bodySmall,
            ),
          ],
          if (x.deposit.isReceived)
            Consumer(
              builder: (context, ref, _) =>
                  PdfLinkButton(label: 'Deposit receipt', fetch: (r) => r.read(tenancyRepositoryProvider).depositReceiptLink(x.id, host: true)),
            ),
          if (x.can('record_deposit') ||
              x.can('activate') ||
              x.can('cancel') ||
              x.can('serve_notice') ||
              x.can('withdraw_notice') ||
              x.can('move_out') ||
              x.can('settle')) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (x.can('record_deposit'))
                  AppButton(label: 'Record deposit', onPressed: onDeposit, variant: AppButtonVariant.secondary, compact: true, expand: false),
                if (x.can('activate')) AppButton(label: 'Record move-in', onPressed: onActivate, compact: true, expand: false),
                if (x.can('settle'))
                  AppButton(
                    label: x.settlement?.status == 'COMPLETED' ? 'View deposit settlement' : 'Settle the deposit',
                    onPressed: onSettle,
                    compact: true,
                    expand: false,
                  ),
                if (x.can('serve_notice'))
                  AppButton(label: 'Serve notice', onPressed: onNotice, variant: AppButtonVariant.secondary, compact: true, expand: false),
                if (x.can('withdraw_notice'))
                  AppButton(label: 'Withdraw notice', onPressed: onWithdrawNotice, variant: AppButtonVariant.secondary, compact: true, expand: false),
                if (x.can('move_out'))
                  AppButton(label: 'Record move-out', onPressed: onMoveOut, variant: AppButtonVariant.secondary, compact: true, expand: false),
                if (x.can('cancel')) AppButton(label: 'Cancel', onPressed: onCancel, variant: AppButtonVariant.ghost, compact: true, expand: false),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DepositSheet extends StatefulWidget {
  const _DepositSheet({required this.tenancy});
  final Tenancy tenancy;

  @override
  State<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<_DepositSheet> {
  final _reference = TextEditingController();
  String _method = 'UPI';

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Record deposit',
      footer: AppButton(label: 'Record', onPressed: () => Navigator.of(context).pop((method: _method, reference: _reference.text))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${money(widget.tenancy.depositPaise)} received from ${widget.tenancy.tenantLabel}.', style: context.text.bodyMedium),
          const SizedBox(height: 16),
          AppSegmented<String>(
            semanticLabel: 'How was it paid',
            options: const [(value: 'UPI', label: 'UPI'), (value: 'CASH', label: 'Cash'), (value: 'BANK', label: 'Bank')],
            value: _method,
            onChanged: (v) => setState(() => _method = v),
          ),
          const SizedBox(height: 16),
          AppTextField(label: 'Reference', optional: true, helper: 'UTR, receipt number…', controller: _reference, maxLength: 100),
        ],
      ),
    );
  }
}

String _camel(String screaming) => screaming.toLowerCase();
