import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/offline/offline.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/common.dart';

/// "Usar sin internet en esta computadora" (solo en el navegador). Nada se guarda hasta que el dueño lo pide:
/// primero se le explica qué pasa y decide. El ícono en el escritorio lo pregunta el propio navegador.
class OfflineCard extends StatefulWidget {
  const OfflineCard({super.key});

  /// Solo tiene sentido en la versión de computadora (en el celular la app ya funciona sin internet).
  static bool get applies => kIsWeb;

  @override
  State<OfflineCard> createState() => _OfflineCardState();
}

class _OfflineCardState extends State<OfflineCard> {
  bool _busy = false;
  late bool _on = offlineEnabled();

  void _say(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Archivos de la app que quizá aún no se han visto (dibujos del gavilán, iconos): también se guardan.
  Future<List<String>> _assets() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return [for (final key in manifest.listAssets()) 'assets/${Uri(path: key)}'];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _enable() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Guardar Gavilán en esta computadora?'),
        content: const Text(
          'Se guardan los archivos de la app en este navegador (unos 20 MB), para que abra aunque no haya '
          'internet; por ejemplo, cuando regresa la luz y el módem todavía no.\n\n'
          'No se instala ningún programa ni se toca nada más de la computadora. Lo puedes quitar cuando quieras '
          'desde aquí mismo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Ahora no')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sí, guardar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final r = await enableOffline(await _assets());
      setState(() => _on = true);
      _say(
        r.failed == 0
            ? 'Listo: Gavilán ya abre sin internet en esta computadora'
            : 'Listo. ${r.failed} archivos no se pudieron guardar; se guardan solos la próxima vez que haya internet',
      );
    } catch (_) {
      _say('No se pudo guardar. Revisa que haya internet e inténtalo otra vez');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar lo guardado?'),
        content: const Text(
          'Gavilán ya no abrirá en esta computadora si no hay internet. Tus ventas y productos no se borran.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Quitar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    await disableOffline();
    if (mounted) {
      setState(() {
        _busy = false;
        _on = false;
      });
    }
    _say('Listo: se quitó');
  }

  Future<void> _install() async {
    final accepted = await installApp();
    if (accepted) _say('Gavilán quedó con su ícono en esta computadora');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final supported = offlineSupported();
    final showInstall = _on && canInstallApp() && !runningInstalled();
    return GCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (_on ? GColors.cenote : GColors.tintaSuave).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _on ? Icons.offline_pin_rounded : Icons.wifi_off_rounded,
                  color: _on ? GColors.cenote : GColors.tintaSuave,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _on ? 'Abre sin internet' : 'Usar sin internet en esta computadora',
                      style: GText.sans(size: 15, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !supported
                          ? 'Este navegador no lo permite. Usa Chrome o Edge.'
                          : _on
                          ? 'Gavilán está guardado en este navegador: abre aunque se vaya el internet o la luz, '
                                'y se pone al día solo cuando hay conexión.'
                          : 'Para que la caja abra aunque se vaya el internet (por ejemplo, después de un apagón). '
                                'Tú decides; no se guarda nada si no lo activas.',
                      style: GText.muted(size: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (supported) ...[
            const SizedBox(height: 10),
            if (_busy)
              Row(
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4)),
                  const SizedBox(width: 10),
                  Text('Guardando en esta computadora…', style: GText.muted(size: 13)),
                ],
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (!_on)
                    SoftButton(label: 'Activar', icon: Icons.download_done_rounded, onTap: _enable)
                  else ...[
                    if (showInstall)
                      SoftButton(
                        label: 'Poner ícono en el escritorio',
                        icon: Icons.install_desktop_rounded,
                        onTap: _install,
                      ),
                    SoftButton(label: 'Quitar', icon: Icons.close_rounded, color: GColors.tintaSuave, onTap: _disable),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }
}
