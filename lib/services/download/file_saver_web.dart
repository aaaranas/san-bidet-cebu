import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: build a Blob and click a synthetic anchor.
///
/// This replaces `Share.shareXFiles(XFile.fromData(...))`, which routes through
/// the Web Share API — unimplemented in desktop Firefox and limited for files
/// in Safari, so exports silently did nothing for a good share of admins.
Future<void> saveFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();

  // Give the browser a moment to start the download before reclaiming memory.
  await Future<void>.delayed(const Duration(seconds: 1));
  web.URL.revokeObjectURL(url);
}
