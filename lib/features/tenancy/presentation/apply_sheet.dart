import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/states.dart';
import '../../hostels/domain/enums.dart';
import '../application/tenancy_providers.dart';
import '../domain/tenancy_models.dart';

/// Asks for a bed at a hostel or PG. Resolves to true once the request was sent.
Future<bool?> showApplySheet(BuildContext context, {required String hostelId, required String hostelName, required GenderPolicy genderPolicy}) {
  return showAppSheet<bool>(
    context,
    builder: (_) => ApplySheet(hostelId: hostelId, hostelName: hostelName, genderPolicy: genderPolicy),
  );
}

class ApplySheet extends ConsumerStatefulWidget {
  const ApplySheet({super.key, required this.hostelId, required this.hostelName, required this.genderPolicy});
  final String hostelId;
  final String hostelName;
  final GenderPolicy genderPolicy;

  @override
  ConsumerState<ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends ConsumerState<ApplySheet> {
  final _tenure = TextEditingController();
  final _occupation = TextEditingController();
  final _message = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  String? _roomId;
  String? _gender;
  DateTime _moveIn = today().add(const Duration(days: 7));
  bool _busy = false;
  String? _error;
  Map<String, String> _fields = const {};

  @override
  void dispose() {
    for (final c in [_tenure, _occupation, _message, _contactName, _contactPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _moveIn, firstDate: today(), lastDate: today().add(const Duration(days: 180)));
    if (picked != null) setState(() => _moveIn = picked);
  }

  Future<void> _send(TenancyTerms terms) async {
    final room = terms.rooms.where((r) => r.roomTypeId == _roomId && r.freeUnits > 0).firstOrNull;
    final local = <String, String>{
      if (room == null) 'roomTypeId': 'Choose a room',
      if (_contactName.text.trim().length < 2) 'emergencyContactName': 'Enter a contact name',
      if (!RegExp(r'^\+?[1-9]\d{7,14}$').hasMatch(_contactPhone.text.replaceAll(RegExp(r'[\s-]'), '')))
        'emergencyContactPhone': 'Use international format, e.g. +919876543210',
    };
    if (local.isNotEmpty) return setState(() => _fields = local);
    setState(() {
      _busy = true;
      _error = null;
      _fields = const {};
    });
    try {
      await ref
          .read(tenancyRepositoryProvider)
          .apply(
            widget.hostelId,
            roomTypeId: room!.roomTypeId,
            moveInDate: toApiDate(_moveIn),
            tenureMonths: int.tryParse(_tenure.text),
            gender: _gender,
            occupation: _occupation.text,
            message: _message.text,
            emergencyContactName: _contactName.text,
            emergencyContactPhone: _contactPhone.text,
          );
      ref.invalidate(myApplicationsProvider);
      ref.invalidate(tenancyTermsProvider(widget.hostelId));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.fieldErrors.isEmpty ? e.userMessage : null;
        _fields = e.fieldErrors;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final terms = ref.watch(tenancyTermsProvider(widget.hostelId));
    return terms.when(
      loading: () => const SheetFrame(
        title: 'Request a bed',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ),
      error: (e, _) => SheetFrame(
        title: 'Request a bed',
        child: ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(tenancyTermsProvider(widget.hostelId))),
      ),
      data: (terms) {
        final rooms = terms.rooms.where((r) => r.freeUnits > 0).toList();
        _roomId ??= rooms.firstOrNull?.roomTypeId;
        final room = rooms.where((r) => r.roomTypeId == _roomId).firstOrNull;
        final needGender = widget.genderPolicy != GenderPolicy.mixed || (room != null && room.gender != RoomGender.mixed);
        return SheetFrame(
          title: 'Request a bed',
          footer: AppButton(label: 'Send request', loading: _busy, onPressed: rooms.isEmpty ? null : () => _send(terms)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.hostelName}. The owner decides, usually within a few days.', style: t.bodyMedium),
              const SizedBox(height: 16),
              if (_error != null) ...[Text(_error!, style: t.bodyMedium?.copyWith(color: c.destructive)), const SizedBox(height: 12)],
              if (rooms.isEmpty)
                const Text('No beds are free right now.')
              else ...[
                Text('Room', style: t.titleSmall),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: _roomId,
                  onChanged: (v) => setState(() => _roomId = v),
                  child: Column(
                    children: [
                      for (final r in rooms)
                        RadioListTile<String>(
                          value: r.roomTypeId,
                          contentPadding: EdgeInsets.zero,
                          title: Text(r.name),
                          subtitle: Text('${money(r.rentPaise)} / month · ${r.freeUnits} free'),
                        ),
                    ],
                  ),
                ),
                if (_fields['roomTypeId'] != null) Text(_fields['roomTypeId']!, style: t.bodySmall?.copyWith(color: c.destructive)),
                const SizedBox(height: 12),
                Text('Move-in date', style: t.titleSmall),
                const SizedBox(height: 8),
                AppButton(label: fmtLong(_moveIn), icon: Icons.event_outlined, variant: AppButtonVariant.secondary, onPressed: _pickDate),
                if (_fields['moveInDate'] != null) Text(_fields['moveInDate']!, style: t.bodySmall?.copyWith(color: c.destructive)),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Planned stay (months)',
                  optional: true,
                  controller: _tenure,
                  keyboardType: TextInputType.number,
                  errorText: _fields['tenureMonths'],
                ),
                if (needGender) ...[
                  const SizedBox(height: 16),
                  Text('Your gender', style: t.titleSmall),
                  const SizedBox(height: 8),
                  AppSegmented<String?>(
                    semanticLabel: 'Your gender',
                    options: const [(value: 'FEMALE', label: 'Female'), (value: 'MALE', label: 'Male'), (value: 'OTHER', label: 'Other')],
                    value: _gender,
                    onChanged: (v) => setState(() => _gender = v),
                  ),
                  if (_fields['gender'] != null) Text(_fields['gender']!, style: t.bodySmall?.copyWith(color: c.destructive)),
                ],
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Studying or working at',
                  optional: true,
                  controller: _occupation,
                  maxLength: 100,
                  errorText: _fields['occupation'],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Emergency contact name',
                  controller: _contactName,
                  textCapitalization: TextCapitalization.words,
                  errorText: _fields['emergencyContactName'],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Emergency contact phone',
                  controller: _contactPhone,
                  keyboardType: TextInputType.phone,
                  helper: 'With country code, e.g. +919876543210',
                  errorText: _fields['emergencyContactPhone'],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Message to the owner',
                  optional: true,
                  controller: _message,
                  maxLength: 1000,
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  errorText: _fields['message'],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Shown on the property page: the rent and terms of a long-term stay.
class TermsSummary extends StatelessWidget {
  const TermsSummary({super.key, required this.terms});
  final TenancyTerms terms;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final lines = [
      terms.depositMonths == 0 ? 'No deposit' : 'Deposit: ${plural(terms.depositMonths, 'month')} of rent',
      'Notice period: ${plural(terms.noticeDays, 'day')}',
      'Rent due on the ${ordinal(terms.rentDueDay)} (${plural(terms.rentGraceDays, 'day')} grace)',
      '${terms.freeUnits} ${terms.freeUnits == 1 ? 'bed' : 'beds'} free right now',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(l, style: t.bodySmall),
          ),
      ],
    );
  }
}
