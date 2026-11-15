import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/util/photo_picker.dart';
import '../../../core/router/routes.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/paged_scroll.dart';
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/states.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/tenancy_models.dart';
import '../application/complaint_providers.dart';
import '../domain/complaint_models.dart';
import 'availability_widgets.dart';
import 'complaint_widgets.dart';
import 'photo_widgets.dart';

/// The tenant's complaints, and a way to report a new problem.
class MyComplaintsScreen extends ConsumerWidget {
  const MyComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stays = ref.watch(myTenanciesProvider).value?.items ?? const <Tenancy>[];
    final livesThere = stays.any((t) => t.status == TenancyStatus.active || t.status == TenancyStatus.notice);
    final stayLoaded = ref.watch(myTenanciesProvider).hasValue;
    return Scaffold(
      appBar: AppBar(title: const Text('Complaints')),
      floatingActionButton: livesThere
          ? FloatingActionButton.extended(
              onPressed: () async {
                final id = await showAppSheet<String>(context, builder: (_) => const _FileSheet());
                if (id == null || !context.mounted) return;
                ref.invalidate(myComplaintsProvider);
                showToast(context, 'Complaint sent');
                context.push('${Routes.myComplaints}/$id');
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New complaint'),
            )
          : null,
      body: PagedScroll<ComplaintSummary>(
        value: ref.watch(myComplaintsProvider),
        onLoadMore: () => ref.read(myComplaintsProvider.notifier).loadMore(),
        onRefresh: () async {
          ref.invalidate(myComplaintsProvider);
          await ref.read(myComplaintsProvider.future);
        },
        bottomPadding: 72,
        empty: EmptyState(
          icon: Icons.build_circle_outlined,
          title: 'No complaints',
          message: livesThere
              ? 'If something breaks in your room or building, report it here and we will get it to the right person.'
              : stayLoaded
              ? 'You can report problems once you have moved in to a hostel or PG.'
              : 'Report problems in your room or building here.',
        ),
        itemBuilder: (context, c, _) => ComplaintCard(complaint: c, onTap: () => context.push('${Routes.myComplaints}/${c.id}')),
      ),
    );
  }
}

class _FileSheet extends ConsumerStatefulWidget {
  const _FileSheet();

  @override
  ConsumerState<_FileSheet> createState() => _FileSheetState();
}

class _FileSheetState extends ConsumerState<_FileSheet> {
  static const _categories = [
    ('PLUMBING', 'Plumbing'),
    ('ELECTRICAL', 'Electrical'),
    ('CARPENTRY', 'Carpentry'),
    ('CLEANING', 'Cleaning'),
    ('FOOD', 'Food'),
    ('WIFI', 'Wi-Fi'),
    ('SECURITY', 'Security'),
    ('BEHAVIOUR', 'Behaviour'),
    ('OTHER', 'Other'),
  ];

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  String _category = 'PLUMBING';
  String _priority = 'MEDIUM';
  FreeTime _free = FreeTime.initial();
  List<PickedPhoto> _photos = const [];
  String? _freeError;
  bool _busy = false;
  String? _error;
  Map<String, String> _fields = const {};

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final local = <String, String>{
      if (_title.text.trim().length < 3) 'title': 'Give it a short title',
      if (_description.text.trim().length < 5) 'description': 'Describe what is wrong',
    };
    final problem = _free.problem;
    if (local.isNotEmpty || problem != null) {
      return setState(() {
        _fields = local;
        _freeError = problem;
      });
    }
    setState(() {
      _busy = true;
      _error = null;
      _fields = const {};
    });
    try {
      final c = await ref
          .read(complaintRepositoryProvider)
          .file(
            category: _category,
            priority: _priority,
            title: _title.text,
            description: _description.text,
            location: _location.text,
            availableFrom: _free.start,
            availableTo: _free.end,
            allowEntryIfAway: _free.allowEntry,
          );
      // The complaint exists now: photos are best effort, so a bad upload never loses the report.
      final failed = await uploadPhotos(ref, c.id, _photos);
      if (failed > 0 && mounted) {
        showToast(context, '$failed of ${_photos.length} photos could not be uploaded. You can add them from the complaint.', error: true);
      }
      if (mounted) Navigator.of(context).pop(c.id);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.userMessage;
          _fields = e.fieldErrors;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'New complaint',
      footer: AppButton(label: 'Send complaint', onPressed: _submit, loading: _busy),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 12)],
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'What kind of problem?'),
            items: [for (final c in _categories) DropdownMenuItem(value: c.$1, child: Text(c.$2))],
            onChanged: _busy ? null : (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 16),
          AppSegmented<String>(
            semanticLabel: 'How urgent',
            value: _priority,
            options: const [(value: 'LOW', label: 'Can wait'), (value: 'MEDIUM', label: 'Normal'), (value: 'HIGH', label: 'Quick')],
            onChanged: (v) => setState(() => _priority = v),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Short title',
            controller: _title,
            hint: 'Tap is leaking',
            maxLength: 120,
            errorText: _fields['title'],
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'What is wrong?',
            controller: _description,
            maxLength: 2000,
            maxLines: 4,
            minLines: 3,
            errorText: _fields['description'],
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Where?',
            optional: true,
            controller: _location,
            hint: 'Bathroom, corridor… (defaults to your bed)',
            maxLength: 100,
            errorText: _fields['location'],
          ),
          const SizedBox(height: 16),
          FreeTimeFields(
            value: _free,
            error: _freeError ?? _fields['availableFrom'] ?? _fields['availableTo'],
            onChanged: (v) => setState(() {
              _free = v;
              _freeError = null;
            }),
          ),
          const SizedBox(height: 8),
          PhotoStrip(photos: _photos, enabled: !_busy, onChanged: (p) => setState(() => _photos = p)),
        ],
      ),
    );
  }
}
