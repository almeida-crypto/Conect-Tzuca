import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/logo.dart';
import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/common.dart';

/// "Logo del negocio" en Más: lo pone, lo cambia o lo quita. Sale arriba del ticket impreso y del de WhatsApp.
class LogoCard extends ConsumerWidget {
  const LogoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    final logo = ref.watch(storeProvider).logo;
    final unlocked = plan.limits.logo;
    return GCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      onTap: () => unlocked
          ? pickLogo(context, ref, hasLogo: logo != null)
          : showUpgradeSheet(
              context,
              reason:
                  'En el plan ${plan.label} el ticket lleva el nombre de tu negocio. '
                  'Con tu logo arriba se ve más formal, impreso y por WhatsApp.',
              needed: Plan.emprendedor,
            ),
      child: Row(
        children: [
          if (logo != null && unlocked)
            Container(
              width: 56,
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GColors.linea),
              ),
              child: Image.memory(logo, fit: BoxFit.contain, gaplessPlayback: true),
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: GColors.marca.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                unlocked ? Icons.add_photo_alternate_outlined : Icons.lock_outline,
                size: 21,
                color: GColors.marca,
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Logo del negocio', style: GText.sans(size: 15, weight: FontWeight.w700)),
                Text(
                  !unlocked
                      ? 'Desde el plan Emprendedor'
                      : (logo == null
                            ? 'Sale arriba del ticket impreso y del de WhatsApp'
                            : 'Toca para cambiarlo o quitarlo'),
                  style: GText.muted(size: 12.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: GColors.tintaTenue),
        ],
      ),
    );
  }
}

/// Elige el logo de la galería (o le toma foto) y lo guarda ya listo para el ticket.
Future<void> pickLogo(BuildContext context, WidgetRef ref, {required bool hasLogo}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: GColors.cenote),
            title: const Text('Elegir de la galería'),
            subtitle: const Text('Mejor si es el archivo del logo, con fondo blanco o transparente'),
            onTap: () => Navigator.of(ctx).pop('galeria'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: GColors.cenote),
            title: const Text('Tomarle foto'),
            subtitle: const Text('Por ejemplo, al letrero o a una tarjeta'),
            onTap: () => Navigator.of(ctx).pop('camara'),
          ),
          if (hasLogo)
            ListTile(
              leading: const Icon(Icons.hide_image_outlined, color: GColors.rojo),
              title: const Text('Quitar el logo', style: TextStyle(color: GColors.rojo)),
              onTap: () => Navigator.of(ctx).pop('quitar'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final store = ref.read(storeProvider.notifier);
  if (choice == 'quitar') {
    store.setLogo(null);
    messenger.showSnackBar(const SnackBar(content: Text('Se quitó el logo. El ticket lleva solo el nombre.')));
    return;
  }
  try {
    // Sin bajarle calidad aquí: un PNG transparente se queda PNG y prepareLogo le pone el fondo blanco.
    final file = await ImagePicker().pickImage(
      source: choice == 'camara' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      requestFullMetadata: false,
    );
    if (file == null) return;
    final logo = await prepareLogo(await file.readAsBytes());
    if (logo == null) {
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo leer esa imagen. Prueba con otra.')));
      return;
    }
    store.setLogo(logo);
    messenger.showSnackBar(const SnackBar(content: Text('Listo: tu logo ya sale en el ticket.')));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo abrir la cámara o la galería. Revisa los permisos de la app.')),
    );
  }
}
