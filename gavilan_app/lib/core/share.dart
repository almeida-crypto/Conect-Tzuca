import 'package:flutter/material.dart';
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
