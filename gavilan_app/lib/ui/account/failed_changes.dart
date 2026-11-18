import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ticket_text.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';

/// Cambios que el servidor no aceptó. Ya no traban el respaldo: los demás siguen subiendo.
/// Se pueden reintentar todos (por si ya se arregló, por ejemplo al darle permisos a la cuenta)
/// o descartar uno: no se sube y el teléfono vuelve a quedar como la nube.
class FailedChanges extends ConsumerStatefulWidget {
  const FailedChanges({super.key});

  @override
  ConsumerState<FailedChanges> createState() => _FailedChangesState();
}

class _FailedChangesState extends ConsumerState<FailedChanges> {
  Future<List<FailedChange>>? _list;
  int? _loadedFor;
  bool _working = false;

  SyncController get _sync => ref.read(syncProvider.notifier);

  Future<void> _retry() async {
    setState(() => _working = true);
    await _sync.retryFailed();
    if (mounted) setState(() => _working = false);
  }

  Future<void> _discard(FailedChange c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Descartar "${c.what}"?'),
        content: const Text(
          'Este cambio ya no se va a subir. Lo que ya estaba en la nube vuelve a quedar en este teléfono '
          'como está allá.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar', style: TextStyle(color: GColors.rojo)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _working = true);
    await _sync.discardFailed(c.id);
    if (mounted) setState(() => _working = false);
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncProvider);
    if (sync.failed == 0) return const SizedBox.shrink();
    // Se vuelve a leer la lista cada vez que cambia cuántos hay o termina un respaldo.
    final key = Object.hash(sync.failed, sync.lastSync);
    if (_loadedFor != key) {
      _loadedFor = key;
      _list = _sync.failedChanges();
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(color: GColors.rojoSuave, borderRadius: BorderRadius.circular(GShape.radiusSmall)),
      child: FutureBuilder<List<FailedChange>>(
        future: _list,
        builder: (context, snap) {
          final items = snap.data ?? const <FailedChange>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sync.failed == 1 ? 'Un cambio no se pudo subir' : '${sync.failed} cambios no se pudieron subir',
                style: GText.sans(size: 14.5, weight: FontWeight.w800, color: GColors.rojo),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  'Lo demás sí se respalda. Todo sigue guardado en este teléfono.',
                  style: GText.muted(size: 12.5),
                ),
              ),
              const SizedBox(height: 6),
              for (final c in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${c.what} · ${dateTimeLabel(c.createdAt)}',
                              style: GText.sans(size: 13.5, weight: FontWeight.w700),
                            ),
                            Text(c.error, maxLines: 3, overflow: TextOverflow.ellipsis, style: GText.muted(size: 12)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _working ? null : () => _discard(c),
                        child: Text(
                          'Descartar',
                          style: GText.sans(size: 13, weight: FontWeight.w700, color: GColors.tintaSuave),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 4),
                child: GButton(
                  label: _working ? 'Un momento…' : 'Reintentar',
                  icon: Icons.refresh_rounded,
                  kind: GButtonKind.outline,
                  expand: true,
                  onPressed: _working ? null : _retry,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
