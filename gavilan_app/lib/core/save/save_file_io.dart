import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// En el celular: abre el menú de compartir con el archivo (guardarlo, mandarlo por WhatsApp o imprimirlo).
Future<void> saveFile(Uint8List bytes, {required String name, required String mimeType}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: mimeType, name: name)],
      fileNameOverrides: [name],
    ),
  );
}
