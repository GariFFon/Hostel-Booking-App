import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// A photo chosen on the phone, held in memory until it is uploaded.
class PickedPhoto {
  const PickedPhoto({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;

  /// The lower-case file extension, which is what the upload policy checks ("jpg", "png", "webp").
  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}

/// Where photos come from. An interface so tests can hand in photos without a gallery.
abstract interface class PhotoPicker {
  /// Lets the person choose up to [max] photos from the gallery. Empty when they cancel.
  Future<List<PickedPhoto>> fromGallery({required int max});

  /// Opens the camera for one photo. Null when they cancel.
  Future<PickedPhoto?> fromCamera();
}

class DevicePhotoPicker implements PhotoPicker {
  DevicePhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  // Phone photos are large; 2000 px on the long side at 85% quality is plenty for a complaint and keeps uploads fast.
  static const _maxSide = 2000.0;
  static const _quality = 85;

  Future<PickedPhoto> _read(XFile f) async => PickedPhoto(name: _nameOf(f), bytes: await f.readAsBytes());

  // The picker re-encodes as JPEG: make sure the name says so, whatever the original file was called.
  String _nameOf(XFile f) {
    final base = f.name.contains('.') ? f.name.substring(0, f.name.lastIndexOf('.')) : f.name;
    return '${base.isEmpty ? 'photo' : base}.jpg';
  }

  @override
  Future<List<PickedPhoto>> fromGallery({required int max}) async {
    final files = await _picker.pickMultiImage(maxWidth: _maxSide, maxHeight: _maxSide, imageQuality: _quality, limit: max < 2 ? null : max);
    return [for (final f in files.take(max)) await _read(f)];
  }

  @override
  Future<PickedPhoto?> fromCamera() async {
    final f = await _picker.pickImage(source: ImageSource.camera, maxWidth: _maxSide, maxHeight: _maxSide, imageQuality: _quality);
    return f == null ? null : _read(f);
  }
}
