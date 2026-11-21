import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/limits.dart' show QtyInputFormatter, parseQty;
import '../../core/money.dart';
import '../../core/share.dart';
import '../../core/ticket_text.dart';
import '../../domain/models.dart';
import '../../domain/purchases.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../scan/scan_screen.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

enum _Show { todos, contados, diferencia }

/// Contar lo que hay en la tienda (con el lector, la cámara o a mano) y dejar la existencia como lo contado.
/// Lo contado se guarda en este aparato mientras tanto: se puede cerrar la app y seguir después.
class StockCountScreen extends ConsumerStatefulWidget {
  const StockCountScreen({super.key});

  @override
  ConsumerState<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends ConsumerState<StockCountScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  String _q = '';
  _Show _show = _Show.todos;

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Enter en el buscador: un código suma una pieza; un nombre se queda como búsqueda.
  void _submit(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    final store = ref.read(storeProvider);
    final p = store.productByBarcode(text);
    if (p == null) {
      if (RegExp(r'^\d{6,}$').hasMatch(text)) {
        HapticFeedback.heavyImpact();
        _snack('El código $text no está en tus productos');
        _search.clear();
        setState(() => _q = '');
      }
      _focus.requestFocus();
      return;
    }
    _countOne(p);
    _search.clear();
    setState(() => _q = '');
    _focus.requestFocus();
  }

  void _countOne(Product p) {
    if (!p.trackStock) {
      _snack('${p.name} no lleva existencia');
      return;
    }
    ref.read(storeProvider.notifier).countOne(p.id);
    HapticFeedback.selectionClick();
    _snack('+1 ${p.name} · van ${qtyLabel(ref.read(storeProvider).countDraft[p.id] ?? 0)}');
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(milliseconds: 1400)));

  Future<void> _type(Product p) async {
    final current = ref.read(storeProvider).countDraft[p.id];
    final controller = TextEditingController(text: current == null ? '' : qtyLabel(current));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [QtyInputFormatter()],
          decoration: InputDecoration(labelText: '¿Cuántos hay?', helperText: 'Dice el sistema: ${qtyLabel(p.stock)}'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          if (current != null) TextButton(onPressed: () => Navigator.of(ctx).pop(''), child: const Text('Quitar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('Listo')),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    ref.read(storeProvider.notifier).setCounted(p.id, result.trim().isEmpty ? null : parseQty(result));
  }

  Future<void> _apply() async {
    final store = ref.read(storeProvider);
    final lines = [
      for (final e in store.countDraft.entries)
        if (store.productById(e.key) case final p? when p.trackStock)
          CountLine(productId: p.id, name: p.name, system: p.stock, counted: e.value, costCents: p.costCents),
    ];
    final preview = StockCount.of(id: '', lines: lines, at: DateTime.now());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Ajustar la existencia?'),
        content: Text(
          '${lines.length} ${lines.length == 1 ? 'producto queda' : 'productos quedan'} como los contaste.\n'
          '${preview.missingPieces > 0 ? 'Faltan ${qtyLabel(preview.missingPieces)} piezas (${money(preview.missingCostCents)} a costo).\n' : ''}'
          '${preview.extraPieces > 0 ? 'Sobran ${qtyLabel(preview.extraPieces)} piezas (${money(preview.extraCostCents)} a costo).\n' : ''}'
          'Lo que no contaste no cambia.',
          style: GText.sans(size: 14, weight: FontWeight.w400),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Seguir contando')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Ajustar',
              style: GText.sans(size: 14, weight: FontWeight.w800, color: GColors.marca),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final count = ref.read(storeProvider.notifier).applyCount();
    if (count == null || !mounted) return;
    await showGSheet<void>(context, (_) => CountResultSheet(count: count));
  }

  Future<void> _discard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar lo contado?'),
        content: const Text('Se pierde lo que llevas contado. La existencia no cambia.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok == true) ref.read(storeProvider.notifier).discardCount();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final draft = store.countDraft;
    final all = store.countableProducts;
    final q = _q.trim().toLowerCase();
    bool differs(Product p) => draft.containsKey(p.id) && draft[p.id] != p.stock;
    final list = all
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || (p.barcode?.contains(q) ?? false))
        .where(
          (p) => switch (_show) {
            _Show.todos => true,
            _Show.contados => draft.containsKey(p.id),
            _Show.diferencia => differs(p),
          },
        )
        .toList();
    final counted = all.where((p) => draft.containsKey(p.id)).length;
    final diffs = all.where(differs).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Contar inventario', style: GText.sans(size: 17, weight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Contar con la cámara',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ScanScreen(
                  mode: ScanMode.contar,
                  onCount: (p) {
                    if (p.trackStock) ref.read(storeProvider.notifier).countOne(p.id);
                  },
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Conteos anteriores',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => showGSheet<void>(context, (_) => const _PastCounts()),
          ),
          if (draft.isNotEmpty)
            IconButton(tooltip: 'Borrar lo contado', icon: const Icon(Icons.delete_outline), onPressed: _discard),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _search,
                focusNode: _focus,
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                onSubmitted: _submit,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Escanea o busca',
                  prefixIcon: Icon(Icons.search_rounded, size: 22),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final (i, (s, label)) in [
                    (_Show.todos, 'Todos (${all.length})'),
                    (_Show.contados, 'Contados ($counted)'),
                    (_Show.diferencia, 'Distintos ($diffs)'),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: GChip(label: label, selected: _show == s, onTap: () => setState(() => _show = s)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        all.isEmpty
                            ? 'No hay productos con existencia para contar.'
                            : 'Nada por aquí. Escanea un código o cambia el filtro.',
                        textAlign: TextAlign.center,
                        style: GText.muted(size: 14),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: GColors.linea),
                      itemBuilder: (_, i) {
                        final p = list[i];
                        final c = draft[p.id];
                        final diff = c == null ? null : c - p.stock;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: GText.sans(size: 14, weight: FontWeight.w700)),
                                    Text(
                                      [
                                        'Sistema: ${qtyLabel(p.stock)}',
                                        if (diff != null && diff != 0)
                                          diff < 0 ? 'faltan ${qtyLabel(-diff)}' : 'sobran ${qtyLabel(diff)}',
                                        if (diff == 0) 'cuadra',
                                      ].join(' · '),
                                      style: GText.sans(
                                        size: 12,
                                        color: diff == null || diff == 0
                                            ? GColors.tintaSuave
                                            : (diff < 0 ? GColors.rojo : GColors.cenoteOscuro),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => _type(p),
                                borderRadius: BorderRadius.circular(GShape.radiusSmall),
                                child: Container(
                                  width: 64,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: c == null ? GColors.hundido : GColors.superficie,
                                    border: Border.all(color: c == null ? GColors.linea : GColors.tinta),
                                    borderRadius: BorderRadius.circular(GShape.radiusSmall),
                                  ),
                                  child: Text(
                                    c == null ? '—' : qtyLabel(c),
                                    style: GText.amount(
                                      size: 17,
                                      color: c == null ? GColors.tintaTenue : GColors.tinta,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Contar una más',
                                onPressed: () => _countOne(p),
                                icon: const Icon(Icons.add_circle_outline_rounded),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (draft.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: GColors.superficie,
                  border: Border(top: BorderSide(color: GColors.linea)),
                ),
                child: GButton(
                  label: 'Ajustar $counted ${counted == 1 ? 'producto' : 'productos'}',
                  icon: Icons.fact_check_outlined,
                  expand: true,
                  onPressed: _apply,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lo que quedó del conteo: qué faltó y qué sobró. Se puede mandar por WhatsApp.
class CountResultSheet extends ConsumerWidget {
  const CountResultSheet({super.key, required this.count});

  final StockCount count;

  String _text(String business) {
    final b = StringBuffer()
      ..writeln('*$business*')
      ..writeln('Conteo de inventario ${dateTimeLabel(count.createdAt)}')
      ..writeln('');
    final off = count.lines.where((l) => l.diff != 0).toList()..sort((a, b) => a.diff.compareTo(b.diff));
    if (off.isEmpty) b.writeln('Todo cuadró (${count.lines.length} productos).');
    for (final l in off) {
      b.writeln('${l.diff < 0 ? 'Faltan' : 'Sobran'} ${qtyLabel(l.diff.abs())} · ${l.name}');
    }
    b.writeln('');
    if (count.missingCostCents > 0) b.writeln('Faltante a costo: ${money(count.missingCostCents)}');
    if (count.extraCostCents > 0) b.writeln('Sobrante a costo: ${money(count.extraCostCents)}');
    return b.toString().trimRight();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final off = count.lines.where((l) => l.diff != 0).toList()..sort((a, b) => a.diff.compareTo(b.diff));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader('Conteo ${dayLabel(count.createdAt)}', caption: '${count.lines.length} productos contados'),
        if (off.isEmpty)
          Text(
            'Todo cuadró. ¡Bien!',
            style: GText.sans(size: 15, weight: FontWeight.w700, color: GColors.cenote),
          ),
        if (count.missingCostCents > 0)
          Text(
            'Faltaron ${qtyLabel(count.missingPieces)} piezas: ${money(count.missingCostCents)} a costo',
            style: GText.sans(size: 14, weight: FontWeight.w700, color: GColors.rojo),
          ),
        if (count.extraCostCents > 0)
          Text(
            'Sobraron ${qtyLabel(count.extraPieces)} piezas: ${money(count.extraCostCents)} a costo',
            style: GText.sans(size: 14, weight: FontWeight.w700, color: GColors.cenoteOscuro),
          ),
        const SizedBox(height: 8),
        for (final l in off.take(60))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(child: Text(l.name, style: GText.sans(size: 13.5))),
                Text(
                  '${qtyLabel(l.system)} → ${qtyLabel(l.counted)}',
                  style: GText.figures(size: 12.5, color: l.diff < 0 ? GColors.rojo : GColors.cenoteOscuro),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        GButton(
          label: 'Mandar por WhatsApp',
          icon: Icons.send_outlined,
          kind: GButtonKind.outline,
          expand: true,
          onPressed: () => shareText(context, _text(ref.read(storeProvider).businessName)),
        ),
      ],
    );
  }
}

class _PastCounts extends ConsumerWidget {
  const _PastCounts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = [...ref.watch(storeProvider).stockCounts]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('Conteos anteriores'),
        if (counts.isEmpty) Text('Todavía no hay conteos.', style: GText.muted(size: 14)),
        for (final c in counts.take(30))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(dateTimeLabel(c.createdAt), style: GText.sans(size: 14, weight: FontWeight.w700)),
            subtitle: Text(
              [
                '${c.lines.length} productos',
                if (c.missingCostCents > 0) 'faltó ${money(c.missingCostCents)}',
                if (c.extraCostCents > 0) 'sobró ${money(c.extraCostCents)}',
                if (c.missingCostCents == 0 && c.extraCostCents == 0) 'cuadró',
                ?c.clerk,
              ].join(' · '),
              style: GText.muted(size: 12.5),
            ),
            onTap: () => showGSheet<void>(context, (_) => CountResultSheet(count: c)),
          ),
      ],
    );
  }
}
