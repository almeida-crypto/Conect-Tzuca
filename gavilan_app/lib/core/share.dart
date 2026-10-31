import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

/// Abre el menú de compartir del teléfono (WhatsApp aparece ahí).
Future<void> shareText(BuildContext context, String text) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await SharePlus.instance.share(ShareParams(text: text));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el menú para compartir en este dispositivo.')),
    );
  }
}

/// Convierte en imagen PNG lo que está dentro del [RepaintBoundary] con [boundaryKey]
/// y lo comparte. Se hace en el teléfono y no se guarda en ningún servidor.
/// Si algo falla, comparte [fallbackText].
Future<void> shareAsImage(
  BuildContext context,
  GlobalKey boundaryKey, {
  required String fileName,
  required String fallbackText,
}) async {
  try {
    await WidgetsBinding.instance.endOfFrame;
    final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(data!.buffer.asUint8List(), mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
      ),
    );
  } catch (_) {
    if (context.mounted) await shareText(context, fallbackText);
  }
}
