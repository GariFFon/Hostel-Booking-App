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
import '../../host/application/host_providers.dart';
import '../../host/domain/host_models.dart';
import '../application/tenancy_providers.dart';

/// Adds or invites a tenant by email: someone who already lives there or applied off-platform. Resolves to true once added.
Future<bool?> showAddTenantSheet(BuildContext context) => showAppSheet<bool>(context, builder: (_) => const AddTenantSheet());

class AddTenantSheet extends ConsumerStatefulWidget {
  const AddTenantSheet({super.key});

  @override
  ConsumerState<AddTenantSheet> createState() => _AddTenantSheetState();
}

class _AddTenantSheetState extends ConsumerState<AddTenantSheet> {
  final _email = TextEditingController();
  final _rent = TextEditingController();
  final _deposit = TextEditingController();
  String? _hostelId;
  String? _roomId;
  String? _unitId; // null = assign automatically
  DateTime _start = today();
  bool _received = false;
  String _method = 'CASH';
  bool _busy = false;
  String? _error;
  Map<String, String> _fields = const {};

  @override
  void dispose() {
    _email.dispose();
    _rent.dispose();
    _deposit.dispose();
    super.dispose();
  }

  int? _paise(TextEditingController c) {
    final v = double.tryParse(c.text.trim());
    return v == null ? null : (v * 100).round();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: today().subtract(const Duration(days: 1095)),
      lastDate: today().add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _submit() async {
    final local = <String, String>{
      if (_roomId == null) 'roomTypeId': 'Choose a room',
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) 'tenantEmail': 'Enter a valid email address',
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
          .createTenancy(
            roomTypeId: _roomId!,
            unitId: _unitId,
            tenantEmail: _email.text,
            startDate: toApiDate(_start),
            rentPaise: _paise(_rent),
            depositPaise: _paise(_deposit),
            depositMethod: _received ? _method : null,
          );
      ref.invalidate(freeUnitsProvider);
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
    final hostels = ref.watch(hostHostelsProvider);
    final longTerm = (hostels.value?.items ?? const <OwnerHostel>[]).where((h) => h.propertyType.isLongTerm).toList();
    final rooms = _hostelId == null ? null : ref.watch(hostRoomsProvider(_hostelId!));
    final free = _roomId == null ? null : ref.watch(freeUnitsProvider(_roomId!));

    return SheetFrame(
      title: 'Add a tenant',
      footer: AppButton(label: 'Add tenant', loading: _busy, onPressed: longTerm.isEmpty ? null : _submit),
      child: hostels.isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          : hostels.hasError
          ? ErrorState(error: hostels.error!, compact: true, onRetry: () => ref.invalidate(hostHostelsProvider))
          : longTerm.isEmpty
          ? const Text('Tenants live at hostels and PGs. Create a Hostel or PG listing on the website first.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'For someone who already lives with you. They get an email and accept the stay. Past start dates are fine.',
                  style: t.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[Text(_error!, style: t.bodyMedium?.copyWith(color: c.destructive)), const SizedBox(height: 12)],
                DropdownButtonFormField<String>(
                  key: const ValueKey('property'),
                  isExpanded: true,
                  initialValue: _hostelId,
                  decoration: const InputDecoration(labelText: 'Property'),
                  items: [
                    for (final h in longTerm)
                      DropdownMenuItem(
                        value: h.id,
                        child: Text(h.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _hostelId = v;
                    _roomId = null;
                    _unitId = null;
                  }),
                ),
                if (rooms != null) ...[
                  const SizedBox(height: 16),
                  rooms.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(hostRoomsProvider(_hostelId!))),
                    data: (list) => DropdownButtonFormField<String>(
                      key: ValueKey('room-$_hostelId'),
                      isExpanded: true,
                      initialValue: _roomId,
                      decoration: InputDecoration(labelText: 'Room', errorText: _fields['roomTypeId']),
                      items: [
                        for (final r in list)
                          DropdownMenuItem(
                            value: r.id,
                            child: Text('${r.name} · ${money(r.basePricePaise)}/month', overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _roomId = v;
                        _unitId = null;
                      }),
                    ),
                  ),
                ],
                if (free != null) ...[
                  const SizedBox(height: 16),
                  free.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(freeUnitsProvider(_roomId!))),
                    data: (units) => DropdownButtonFormField<String?>(
                      key: ValueKey('unit-$_roomId'),
                      isExpanded: true,
                      initialValue: _unitId,
                      decoration: InputDecoration(
                        labelText: 'Bed',
                        helperText: units.isEmpty ? 'No beds are free in this room' : null,
                        errorText: _fields['unitId'],
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Assign automatically')),
                        for (final u in units) DropdownMenuItem<String?>(value: u.id, child: Text(u.display)),
                      ],
                      onChanged: (v) => setState(() => _unitId = v),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppTextField(
                  label: "Tenant's email",
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _fields['tenantEmail'],
                ),
                const SizedBox(height: 16),
                Text('Start date', style: t.titleSmall),
                const SizedBox(height: 8),
                AppButton(label: fmtLong(_start), icon: Icons.event_outlined, variant: AppButtonVariant.secondary, onPressed: _pickDate),
                if (_fields['startDate'] != null) Text(_fields['startDate']!, style: t.bodySmall?.copyWith(color: c.destructive)),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Rent per month (₹)',
                  optional: true,
                  helper: "Empty = the room's rent",
                  controller: _rent,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  errorText: _fields['rentPaise'],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Deposit (₹)',
                  optional: true,
                  helper: 'Empty = your default; 0 = none',
                  controller: _deposit,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  errorText: _fields['depositPaise'],
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deposit already received'),
                  value: _received,
                  onChanged: (v) => setState(() => _received = v),
                ),
                if (_received)
                  AppSegmented<String>(
                    semanticLabel: 'Deposit paid by',
                    options: const [(value: 'CASH', label: 'Cash'), (value: 'UPI', label: 'UPI'), (value: 'BANK', label: 'Bank')],
                    value: _method,
                    onChanged: (v) => setState(() => _method = v),
                  ),
              ],
            ),
    );
  }
}
