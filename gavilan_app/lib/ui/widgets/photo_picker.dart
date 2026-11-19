import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/colors.dart';

/// Lo que eligió la persona: una foto nueva o quitar la que había.
class PhotoChoice {
  const PhotoChoice.photo(Uint8List this.bytes);
  const PhotoChoice.remove() : bytes = null;

  /// null = quitar la foto.
  final Uint8List? bytes;
}

/// Muestra la foto en grande; se puede acercar con dos dedos. Se cierra tocando fuera o con la X.
Future<void> showPhotoViewer(BuildContext context, Uint8List photo) => showDialog<void>(
  context: context,
  barrierColor: Colors.black87,
  builder: (ctx) => Stack(
    children: [
      Positioned.fill(
        child: InteractiveViewer(
          maxScale: 5,
          child: Center(child: Image.memory(photo, fit: BoxFit.contain)),
        ),
      ),
      Positioned(
        top: 12,
        right: 12,
        child: SafeArea(
          child: IconButton.filled(
            tooltip: 'Cerrar',
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            onPressed: () => Navigator.of(ctx).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ),
      ),
    ],
  ),
);

/// Toma o elige una foto y la deja chica (600×600, JPEG, unos 50 KB). null si se canceló.
Future<PhotoChoice?> pickPhoto(BuildContext context, {required bool hasPhoto}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: GColors.cenote),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.of(ctx).pop('camara'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: GColors.cenote),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.of(ctx).pop('galeria'),
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.hide_image_outlined, color: GColors.rojo),
              title: const Text('Quitar la foto', style: TextStyle(color: GColors.rojo)),
              onTap: () => Navigator.of(ctx).pop('quitar'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return null;
  if (choice == 'quitar') return const PhotoChoice.remove();
  try {
    final file = await ImagePicker().pickImage(
      source: choice == 'camara' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 75,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return PhotoChoice.photo(await file.readAsBytes());
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la cámara o la galería. Revisa los permisos de la app.')),
      );
    }
    return null;
  }
}
