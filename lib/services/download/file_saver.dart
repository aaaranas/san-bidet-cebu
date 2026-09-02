import 'dart:typed_data';

import 'file_saver_io.dart' if (dart.library.js_interop) 'file_saver_web.dart'
    as impl;

/// Hands a generated file to the user.
///
/// Web and native need genuinely different mechanisms: the Web Share API is
/// unavailable in desktop Firefox and restricted in Safari, so the browser
/// build triggers a real anchor download instead of a share sheet.
Future<void> saveFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) =>
    impl.saveFile(bytes: bytes, fileName: fileName, mimeType: mimeType);
