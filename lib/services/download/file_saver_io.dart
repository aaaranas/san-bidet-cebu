import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Native: write to the temp directory and open the platform share sheet.
Future<void> saveFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType, name: fileName)],
    subject: 'SanBidet Cebu — GIS export',
  );
}
