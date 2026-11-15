import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/photo_picker.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/sheet.dart';
import '../domain/complaint_models.dart';

const maxComplaintPhotos = 6;

/// Gallery or camera, as the person prefers. Returns what they chose (possibly nothing).
Future<List<PickedPhoto>> choosePhotos(BuildContext context, WidgetRef ref, {required int max}) async {
  if (max <= 0) return const [];
  final picker = ref.read(photoPickerProvider);
  final source = await showAppSheet<String>(
    context,
    builder: (ctx) => SheetFrame(
      title: 'Add photos',
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(ctx).pop('gallery'),
          ),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.of(ctx).pop('camera')),
        ],
      ),
    ),
  );
  try {
    if (source == 'gallery') return await picker.fromGallery(max: max);
    if (source == 'camera') {
      final one = await picker.fromCamera();
      return one == null ? const [] : [one];
    }
  } catch (_) {
    if (context.mounted) showToast(context, 'Could not open your photos. Check the app has permission.', error: true);
  }
  return const [];
}

/// Uploads photos one by one. A bad photo never stops the others (or loses the complaint). Returns how many failed.
Future<int> uploadPhotos(
  WidgetRef ref,
  String complaintId,
  List<PickedPhoto> photos, {
  void Function(Object error, PickedPhoto photo)? onError,
}) async {
  var failed = 0;
  for (final p in photos) {
    try {
      await ref.read(complaintRepositoryProvider).addPhoto(complaintId, p);
    } catch (e) {
      failed++;
      onError?.call(e, p);
    }
  }
  return failed;
}

/// Thumbnails of the photos picked so far, each removable, and a button to add more.
class PhotoStrip extends ConsumerWidget {
  const PhotoStrip({super.key, required this.photos, required this.onChanged, this.enabled = true});
  final List<PickedPhoto> photos;
  final ValueChanged<List<PickedPhoto>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isNotEmpty)
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      photos[i].bytes,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      semanticLabel: 'Photo ${i + 1}',
                      errorBuilder: (_, _, _) => const SizedBox(width: 84, height: 84, child: Icon(Icons.broken_image_outlined)),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Semantics(
                      button: true,
                      label: 'Remove photo ${i + 1}',
                      child: InkWell(
                        onTap: enabled ? () => onChanged([...photos]..removeAt(i)) : null,
                        child: Container(
                          decoration: BoxDecoration(color: c.foreground.withValues(alpha: 0.7), shape: BoxShape.circle),
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 14, color: c.background),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (photos.length < maxComplaintPhotos)
          TextButton.icon(
            onPressed: enabled
                ? () async {
                    final more = await choosePhotos(context, ref, max: maxComplaintPhotos - photos.length);
                    if (more.isNotEmpty) onChanged([...photos, ...more].take(maxComplaintPhotos).toList());
                  }
                : null,
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: Text(photos.isEmpty ? 'Add photos (optional)' : 'Add more (${maxComplaintPhotos - photos.length} left)'),
          ),
      ],
    );
  }
}

/// A complaint's photos as a row of thumbnails that open full size in the browser/viewer.
class ComplaintPhotos extends ConsumerWidget {
  const ComplaintPhotos(this.photos, {super.key});
  final List<ComplaintPhoto> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => ref.read(urlOpenerProvider)(photos[i].url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Semantics(
              label: 'Photo ${i + 1}, added by the ${photos[i].uploadedByRole.label}. Opens full size.',
              image: true,
              child: Image.network(
                photos[i].url,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(width: 96, height: 96, child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Add photos" button on a complaint that is still open: picks, uploads, then refreshes the complaint.
class AddPhotosButton extends ConsumerStatefulWidget {
  const AddPhotosButton({super.key, required this.complaintId, required this.have, required this.onAdded});
  final String complaintId;
  final int have;
  final VoidCallback onAdded;

  @override
  ConsumerState<AddPhotosButton> createState() => _AddPhotosButtonState();
}

class _AddPhotosButtonState extends ConsumerState<AddPhotosButton> {
  bool _busy = false;

  Future<void> _add() async {
    final picked = await choosePhotos(context, ref, max: maxComplaintPhotos - widget.have);
    if (picked.isEmpty || !mounted) return;
    setState(() => _busy = true);
    String? firstError;
    final failed = await uploadPhotos(ref, widget.complaintId, picked, onError: (e, _) => firstError ??= errorText(e));
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onAdded();
    if (failed == 0) {
      showToast(context, picked.length == 1 ? 'Photo added' : 'Photos added');
    } else {
      showToast(
        context,
        failed == picked.length ? (firstError ?? 'The photos could not be uploaded.') : '$failed of ${picked.length} photos could not be uploaded.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _busy ? null : _add,
    icon: _busy
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.add_a_photo_outlined, size: 18),
    label: Text(_busy ? 'Uploading…' : 'Add photos'),
  );
}
