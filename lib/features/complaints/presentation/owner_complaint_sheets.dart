import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/sheet.dart';
import '../application/complaint_providers.dart';
import '../domain/complaint_models.dart';
import 'complaint_widgets.dart';

/// Pick who fixes it: only active people who work at this property are listed. Resolves to the chosen user id.
Future<String?> showAssignSheet(BuildContext context, ComplaintDetail c) => showAppSheet<String>(context, builder: (_) => _AssignSheet(c: c));

class _AssignSheet extends ConsumerStatefulWidget {
  const _AssignSheet({required this.c});
  final ComplaintDetail c;

  @override
  ConsumerState<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends ConsumerState<_AssignSheet> {
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(ownerTeamProvider);
    final options = (team.value?.staff ?? const <StaffMember>[]).where((s) => s.active && s.hostels.any((h) => h.id == widget.c.hostel.id)).toList();
    return SheetFrame(
      title: widget.c.assignedStaff == null ? 'Assign to staff' : 'Reassign',
      footer: AppButton(label: 'Assign', onPressed: _picked == null ? null : () => Navigator.of(context).pop(_picked)),
      child: team.isLoading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          : options.isEmpty
          ? Text('Nobody is working at ${widget.c.hostel.name} yet. Invite staff or engage a vendor from Staff.', style: context.text.bodyMedium)
          : RadioGroup<String>(
              groupValue: _picked,
              onChanged: (v) => setState(() => _picked = v),
              child: Column(
                children: [
                  for (final s in options)
                    RadioListTile<String>(
                      value: s.userId,
                      title: Text(s.display),
                      subtitle: Text('${tradeLabel(s.trade)} · ${s.openJobs} open'),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
    );
  }
}

/// Change how urgent it is; urgent complaints must be answered within 4 hours, high within a day.
Future<ComplaintPriority?> showPrioritySheet(BuildContext context, ComplaintPriority current) =>
    showAppSheet<ComplaintPriority>(context, builder: (_) => _PrioritySheet(current: current));

class _PrioritySheet extends StatefulWidget {
  const _PrioritySheet({required this.current});
  final ComplaintPriority current;

  @override
  State<_PrioritySheet> createState() => _PrioritySheetState();
}

class _PrioritySheetState extends State<_PrioritySheet> {
  late ComplaintPriority _p = widget.current;

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Change priority',
      footer: AppButton(label: 'Save', onPressed: _p == widget.current ? null : () => Navigator.of(context).pop(_p)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Urgent complaints must be answered within 4 hours, high within a day, medium within 3 days, low within a week.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: 16),
          AppSegmented<ComplaintPriority>(
            semanticLabel: 'Priority',
            value: _p,
            options: const [
              (value: ComplaintPriority.low, label: 'Low'),
              (value: ComplaintPriority.medium, label: 'Medium'),
              (value: ComplaintPriority.high, label: 'High'),
              (value: ComplaintPriority.urgent, label: 'Urgent'),
            ],
            onChanged: (v) => setState(() => _p = v),
          ),
        ],
      ),
    );
  }
}
