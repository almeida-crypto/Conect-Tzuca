import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/labels.dart';
import '../../core/money.dart';
import '../../core/save/save_file.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/product_icons.dart';

/// Etiquetas con código de barras y precio, en PDF: se eligen los productos y cuántas de cada uno.
/// A los que no traen código se les crea uno interno, que el lector de la app ya reconoce.
class LabelsScreen extends ConsumerStatefulWidget {
  const LabelsScreen({super.key});

  @override
  ConsumerState<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends ConsumerState<LabelsScreen> {
  final _count = <String, int>{};
  LabelFormat _format = LabelFormat.carta;
  bool _price = true;
  String _q = '';
  bool _busy = false;

  int get _total => _count.values.fold(0, (a, n) => a + n);

  void _set(String id, int n) => setState(() => n <= 0 ? _count.remove(id) : _count[id] = n.clamp(1, 300));

  Future<void> _make() async {
    final store = ref.read(storeProvider);
    final chosen = [
      for (final e in _count.entries)
        if (store.productById(e.key) case final p?) (p, e.value),
    ];
    if (chosen.isEmpty) return;
    final missing = chosen.where((c) => (c.$1.barcode ?? '').isEmpty).length;
    if (missing > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(missing == 1 ? '1 producto no tiene código' : '$missing productos no tienen código'),
          content: Text(
            'Se les crea uno para su etiqueta (empieza con 20, el que usan las tiendas para lo suyo) y se guarda '
            'en el producto. Así, al pasarlo por el lector, la app lo encuentra.',
            style: GText.sans(size: 14, weight: FontWeight.w400),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sí, crear códigos')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      ref.read(storeProvider.notifier).giveCodes([for (final (p, _) in chosen) p.id]);
    }
    final now = ref.read(storeProvider);
    final items = [for (final (p, n) in chosen) (now.productById(p.id)!, n)];
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final pdf = await labelsPdf(items: items, format: _format, showPrice: _price);
      await saveFile(pdf, name: 'etiquetas.pdf', mimeType: 'application/pdf');
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo hacer el PDF. Intenta otra vez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final q = _q.trim().toLowerCase();
    final list =
        store.sellableProducts
            .where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || (p.barcode?.contains(q) ?? false))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final total = _total;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Etiquetas con código', style: GText.sans(size: 17, weight: FontWeight.w800)),
        actions: [
          if (_count.isNotEmpty)
            TextButton(onPressed: () => setState(_count.clear), child: const Text('Quitar todas'))
          else
            TextButton(
              onPressed: () => setState(() => _count.addAll({for (final p in list) p.id: 1})),
              child: const Text('Una de cada uno'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: SegmentedButton<LabelFormat>(
                showSelectedIcon: false,
                segments: [
                  for (final f in LabelFormat.values)
                    ButtonSegment(
                      value: f,
                      label: Column(
                        children: [
                          Text(f.label, style: GText.sans(size: 13.5, weight: FontWeight.w700)),
                          Text(f.caption, style: GText.muted(size: 11)),
                        ],
                      ),
                    ),
                ],
                selected: {_format},
                onSelectionChanged: (s) => setState(() => _format = s.first),
              ),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              value: _price,
              onChanged: (v) => setState(() => _price = v),
              activeThumbColor: Colors.white,
              activeTrackColor: GColors.cenote,
              title: Text('Con precio', style: GText.sans(size: 14, weight: FontWeight.w700)),
              subtitle: Text('Si cambias precios seguido, mejor sin precio', style: GText.muted(size: 12)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar producto',
                  prefixIcon: Icon(Icons.search_rounded, size: 22),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 68, color: GColors.linea),
                itemBuilder: (_, i) {
                  final p = list[i];
                  final n = _count[p.id] ?? 0;
                  final hasCode = (p.barcode ?? '').isNotEmpty;
                  return ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
                    leading: ProductThumb(p, size: 40),
                    title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      hasCode
                          ? '${money(p.priceCents)} · ${p.barcode}'
                          : '${money(p.priceCents)} · sin código: se le crea',
                      style: GText.muted(size: 12),
                    ),
                    onTap: () => _set(p.id, n + 1),
                    trailing: n == 0
                        ? IconButton(
                            tooltip: 'Agregar',
                            onPressed: () => _set(p.id, 1),
                            icon: const Icon(Icons.add_circle_outline, color: GColors.cenote),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Una menos',
                                onPressed: () => _set(p.id, n - 1),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '$n',
                                  textAlign: TextAlign.center,
                                  style: GText.figures(size: 15, weight: FontWeight.w800),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Una más',
                                onPressed: () => _set(p.id, n + 1),
                                icon: const Icon(Icons.add_circle, color: GColors.cenote),
                              ),
                            ],
                          ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: GButton(
                label: total == 0
                    ? 'Elige los productos'
                    : 'Hacer PDF · $total ${total == 1 ? 'etiqueta' : 'etiquetas'}'
                          '${_format == LabelFormat.carta && total > 30 ? ' (${(total / 30).ceil()} hojas)' : ''}',
                icon: Icons.picture_as_pdf_outlined,
                expand: true,
                big: true,
                onPressed: total == 0 || _busy ? null : _make,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
