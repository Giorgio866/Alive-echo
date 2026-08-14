import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class DocumentScanService {
  DocumentScanService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  static const _uuid = Uuid();

  Future<String?> captureFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (file == null) return null;
    return _persist(file);
  }

  Future<String?> pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (file == null) return null;
    return _persist(file);
  }

  Future<String> _persist(XFile file) async {
    if (kIsWeb) {
      // Su web restituiamo il path originale / blob path.
      return file.path;
    }
    final docsDir = await getApplicationDocumentsDirectory();
    final scanDir = Directory(p.join(docsDir.path, 'scans'));
    if (!await scanDir.exists()) {
      await scanDir.create(recursive: true);
    }
    final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final dest = p.join(scanDir.path, '${_uuid.v4()}$ext');
    await File(file.path).copy(dest);
    return dest;
  }
}
