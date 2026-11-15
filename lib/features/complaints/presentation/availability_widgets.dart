import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/format/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/chips.dart';
import '../../../shared/widgets/sheet.dart';
import '../domain/complaint_models.dart';

/// When a tenant is free to let someone in: one day and a time range, in their own timezone.
class FreeTime {
  const FreeTime({required this.date, required this.from, required this.to, this.allowEntry = false});
  final DateTime date;
  final TimeOfDay from;
  final TimeOfDay to;
  final bool allowEntry;

  factory FreeTime.initial() =>
      FreeTime(date: today().add(const Duration(days: 1)), from: const TimeOfDay(hour: 9, minute: 0), to: const TimeOfDay(hour: 21, minute: 0));

  FreeTime copyWith({DateTime? date, TimeOfDay? from, TimeOfDay? to, bool? allowEntry}) =>
      FreeTime(date: date ?? this.date, from: from ?? this.from, to: to ?? this.to, allowEntry: allowEntry ?? this.allowEntry);

  DateTime get start => DateTime(date.year, date.month, date.day, from.hour, from.minute);
  DateTime get end => DateTime(date.year, date.month, date.day, to.hour, to.minute);

  /// What is wrong with this choice, in words, or null when it is good to send.
  String? get problem {
    if (!end.isAfter(start)) return 'The end time must be after the start time';
    if (end.difference(start) < const Duration(hours: 1)) return 'Be free for at least an hour so staff can reach you';
    if (!end.isAfter(DateTime.now())) return 'That time has already passed';
    return null;
  }
}

final _day = DateFormat('EEE, d MMM');
final _time = DateFormat('h:mm a');

/// "Tue, 18 Nov, 10:00 AM to 1:00 PM" in the viewer's own timezone.
String fmtSpan(DateTime a, DateTime b) {
  final s = a.toLocal();
  final e = b.toLocal();
  final same = s.year == e.year && s.month == e.month && s.day == e.day;
  return same
      ? '${_day.format(s)}, ${_time.format(s)} to ${_time.format(e)}'
      : '${_day.format(s)}, ${_time.format(s)} to ${_day.format(e)}, ${_time.format(e)}';
}

String fmtTimeOfDay(BuildContext context, TimeOfDay t) => t.format(context);

/// Day + from/to + quick presets + "may go in if I'm out". Required wherever it is used: staff cannot plan a visit without it.
class FreeTimeFields extends StatelessWidget {
  const FreeTimeFields({super.key, required this.value, required this.onChanged, this.error});
  final FreeTime value;
  final ValueChanged<FreeTime> onChanged;
  final String? error;

  static const _presets = [
    ('Morning', TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 12, minute: 0)),
    ('Afternoon', TimeOfDay(hour: 12, minute: 0), TimeOfDay(hour: 17, minute: 0)),
    ('Evening', TimeOfDay(hour: 17, minute: 0), TimeOfDay(hour: 21, minute: 0)),
    ('Any time', TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 21, minute: 0)),
  ];

  Future<void> _pickDate(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: value.date.isBefore(today()) ? today() : value.date,
      firstDate: today(),
      lastDate: today().add(const Duration(days: 30)),
    );
    if (d != null) onChanged(value.copyWith(date: d));
  }

  Future<void> _pickTime(BuildContext context, bool from) async {
    final t = await showTimePicker(context: context, initialTime: from ? value.from : value.to);
    if (t != null) onChanged(from ? value.copyWith(from: t) : value.copyWith(to: t));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('When are you free to let someone in? *', style: t.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final p in _presets)
              ChoiceChip(
                label: Text(p.$1),
                selected: value.from == p.$2 && value.to == p.$3,
                onSelected: (_) => onChanged(value.copyWith(from: p.$2, to: p.$3)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _Pick(label: 'Day', text: _day.format(value.date), icon: Icons.event_outlined, onTap: () => _pickDate(context)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Pick(
                label: 'From',
                text: fmtTimeOfDay(context, value.from),
                icon: Icons.schedule_rounded,
                onTap: () => _pickTime(context, true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Pick(
                label: 'Until',
                text: fmtTimeOfDay(context, value.to),
                icon: Icons.schedule_rounded,
                onTap: () => _pickTime(context, false),
              ),
            ),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text('Staff may go in even if I am not in the room', style: t.bodyMedium),
          value: value.allowEntry,
          onChanged: (v) => onChanged(value.copyWith(allowEntry: v)),
        ),
        if (error != null) Text(error!, style: t.bodySmall?.copyWith(color: c.destructive)),
      ],
    );
  }
}

class _Pick extends StatelessWidget {
  const _Pick({required this.label, required this.text, required this.icon, required this.onTap});
  final String label;
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: '$label: $text',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.baseR,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: Radii.baseR,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: context.text.bodySmall?.copyWith(color: c.mutedForeground)),
              Row(
                children: [
                  Icon(icon, size: 14, color: c.mutedForeground),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(text, style: context.text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks the tenant for a (new) free time. Resolves to it, or null if dismissed.
Future<FreeTime?> showFreeTimeSheet(
  BuildContext context, {
  String title = 'Change your free time',
  String message = 'If a visit was already booked outside this time, staff are asked to book a new one.',
  String confirmLabel = 'Save',
}) => showAppSheet<FreeTime>(
  context,
  builder: (_) => _FreeTimeSheet(title: title, message: message, confirmLabel: confirmLabel),
);

class _FreeTimeSheet extends StatefulWidget {
  const _FreeTimeSheet({required this.title, required this.message, required this.confirmLabel});
  final String title;
  final String message;
  final String confirmLabel;

  @override
  State<_FreeTimeSheet> createState() => _FreeTimeSheetState();
}

class _FreeTimeSheetState extends State<_FreeTimeSheet> {
  FreeTime _v = FreeTime.initial();
  String? _error;

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: widget.title,
      footer: AppButton(
        label: widget.confirmLabel,
        onPressed: () {
          final p = _v.problem;
          if (p != null) return setState(() => _error = p);
          Navigator.of(context).pop(_v);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: context.text.bodyMedium),
          const SizedBox(height: 12),
          FreeTimeFields(
            value: _v,
            error: _error,
            onChanged: (v) => setState(() {
              _v = v;
              _error = null;
            }),
          ),
        ],
      ),
    );
  }
}

/// Staff and owners book the visit inside the tenant's free time; the server re-checks it and tells the tenant.
Future<({DateTime start, DateTime end})?> showVisitSheet(BuildContext context, ComplaintDetail c) =>
    showAppSheet<({DateTime start, DateTime end})>(context, builder: (_) => _VisitSheet(c: c));

class _VisitSheet extends StatefulWidget {
  const _VisitSheet({required this.c});
  final ComplaintDetail c;

  @override
  State<_VisitSheet> createState() => _VisitSheetState();
}

class _VisitSheetState extends State<_VisitSheet> {
  late FreeTime _v;
  String? _error;

  @override
  void initState() {
    super.initState();
    final base = (widget.c.visit?.start ?? widget.c.availability?.from ?? DateTime.now().add(const Duration(hours: 1))).toLocal();
    final end = (widget.c.visit?.end ?? base.add(const Duration(hours: 1))).toLocal();
    _v = FreeTime(
      date: dateOnly(base),
      from: TimeOfDay(hour: base.hour, minute: base.minute),
      to: TimeOfDay(hour: end.hour, minute: end.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.c.availability;
    return SheetFrame(
      title: widget.c.visit == null ? 'Book a visit' : 'Change the visit time',
      footer: AppButton(
        label: widget.c.visit == null ? 'Book visit' : 'Save visit',
        onPressed: () {
          if (!_v.end.isAfter(_v.start)) return setState(() => _error = 'The visit must end after it starts');
          if (a != null && (_v.start.isBefore(a.from.toLocal()) || _v.end.isAfter(a.to.toLocal()))) {
            return setState(() => _error = 'Pick a time inside the tenant’s free time');
          }
          Navigator.of(context).pop((start: _v.start, end: _v.end));
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            a == null ? 'Pick a time that suits you both.' : 'The tenant is free ${fmtSpan(a.from, a.to)}. Pick a time inside it.',
            style: context.text.bodyMedium,
          ),
          if (a != null && !a.allowEntryIfAway) ...[
            const SizedBox(height: 8),
            const StatusChip('The tenant wants someone to be home', tone: Tone.info),
          ],
          const SizedBox(height: 12),
          _VisitPickers(
            value: _v,
            onChanged: (v) => setState(() {
              _v = v;
              _error = null;
            }),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: context.text.bodySmall?.copyWith(color: context.colors.destructive)),
            ),
        ],
      ),
    );
  }
}

class _VisitPickers extends StatelessWidget {
  const _VisitPickers({required this.value, required this.onChanged});
  final FreeTime value;
  final ValueChanged<FreeTime> onChanged;

  @override
  Widget build(BuildContext context) {
    Future<void> day() async {
      final d = await showDatePicker(
        context: context,
        initialDate: value.date.isBefore(today()) ? today() : value.date,
        firstDate: today(),
        lastDate: today().add(const Duration(days: 60)),
      );
      if (d != null) onChanged(value.copyWith(date: d));
    }

    Future<void> time(bool from) async {
      final t = await showTimePicker(context: context, initialTime: from ? value.from : value.to);
      if (t != null) onChanged(from ? value.copyWith(from: t) : value.copyWith(to: t));
    }

    return Row(
      children: [
        Expanded(
          child: _Pick(label: 'Day', text: _day.format(value.date), icon: Icons.event_outlined, onTap: day),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Pick(label: 'From', text: value.from.format(context), icon: Icons.schedule_rounded, onTap: () => time(true)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Pick(label: 'Until', text: value.to.format(context), icon: Icons.schedule_rounded, onTap: () => time(false)),
        ),
      ],
    );
  }
}
