import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../clerks/lock_screen.dart';
import '../inventario/product_search.dart';
import '../inventario/variant_picker.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import 'ticket_screen.dart';

/// Abre el cambio de una venta pagada. Necesita la caja abierta: la venta nueva entra a esta caja.
Future<void> openExchange(BuildContext context, WidgetRef ref, Sale sale) async {
  if (ref.read(storeProvider).openSession == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Abre tu caja para hacer el cambio: la diferencia entra a la caja.')));
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ExchangeScreen(saleId: sale.id)));
}

/// Cambio de talla, de color o de producto: lo que regresa paga parte de lo que se lleva y solo se cobra (o se
/// devuelve) la diferencia. Lo que regresa vuelve al inventario y lo nuevo sale.
class ExchangeScreen extends ConsumerStatefulWidget {
  const ExchangeScreen({super.key, required this.saleId});

  final String saleId;

  @override
  ConsumerState<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends ConsumerState<ExchangeScreen> {
  /// Cuánto regresa de cada renglón de la venta (por posición).
  final _back = <int, double>{};

  /// Lo que se lleva: producto y cuántos.
  final _take = <(Product, double)>[];
  PayMethod _method = PayMethod.efectivo;

  Sale get _sale => ref.read(storeProvider).sales.firstWhere((s) => s.id == widget.saleId);

  @override
  void initState() {
    super.initState();
    // Lo más común: compró una sola pieza y la cambia.
    final sale = _sale;
    final left = _leftOf(sale);
    if (sale.lines.length == 1 && left[0] == 1) _back[0] = 1;
  }

  Map<int, double> _leftOf(Sale sale) {
    final returned = ref.read(storeProvider).returnedOf(sale.id);
    return {for (final (i, l) in sale.lines.indexed) i: (l.qty - (returned[l.key] ?? 0)).clamp(0, l.qty).toDouble()};
  }

  void _add(Product p) => setState(() {
    final i = _take.indexWhere((t) => t.$1.id == p.id);
    if (i >= 0) {
      _take[i] = (p, _take[i].$2 + 1);
    } else {
      _take.add((p, 1));
    }
  });

  Future<void> _otherSize(Product model) async {
    final v = await pickVariant(context, model, onlyAvailable: true, title: 'Talla que se lleva');
    if (v != null && mounted) _add(v);
  }

  Future<void> _otherProduct() async {
    final p = await pickProduct(context, title: '¿Qué se lleva?', sizeTitle: 'Talla que se lleva');
    if (p != null && mounted) _add(p);
  }

  Future<void> _confirm(int value, int newTotal) async {
    final diff = newTotal - value;
    // Devolver dinero es del dueño o un encargado (o con su PIN).
    if (diff < 0 &&
            !await allowOrAskPin(context, ref, allowed: (can) => can.cancelSales, action: 'Devolver la diferencia') ||
        !mounted) {
      return;
    }
    final lines = [
      for (final (i, (p, q)) in _take.indexed)
        SaleLine(
          key: '${p.id}#$i',
          productId: p.id,
          name: p.name,
          unitCents: p.priceCents,
          unitCostCents: p.costCents,
          qty: q,
        ),
    ];
    final done = ref.read(storeProvider.notifier).exchange(widget.saleId, Map.of(_back), lines, method: _method);
    final messenger = ScaffoldMessenger.of(context);
    if (done == null) {
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo hacer el cambio')));
      return;
    }
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => TicketScreen(saleId: done.sale.id, fromHistory: true)));
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (diff) {
          > 0 => 'Cambio hecho. Cobra ${money(diff)}',
          < 0 => 'Cambio hecho. Devuélvele ${money(-diff)}',
          _ => 'Cambio hecho, quedó parejo',
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final sale = store.sales.firstWhere((s) => s.id == widget.saleId);
    final left = _leftOf(sale);
    final factor = sale.subtotalCents == 0 ? 1.0 : sale.totalCents / sale.subtotalCents;
    var value = 0;
    for (final (i, l) in sale.lines.indexed) {
      value += ((_back[i] ?? 0) * l.unitCents * factor).round();
    }
    final newTotal = _take.fold(0, (a, t) => a + (t.$1.priceCents * t.$2).round());
    final diff = newTotal - value;
    final ready = value > 0 && _take.isNotEmpty;
    final canRefund = ref.watch(permissionsProvider).cancelSales || store.usesPins;
    // Modelos de lo que regresa: para ofrecer "otra talla" del mismo.
    final models = <Product>[
      for (final (i, l) in sale.lines.indexed)
        if ((_back[i] ?? 0) > 0 && l.productId != null)
          if (store.productById(l.productId!)?.parentId case final parent?)
            if (store.productById(parent) case final m? when store.isModel(m)) m,
    ];
    final uniqueModels = {for (final m in models) m.id: m}.values.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Cambio · venta ${sale.folioLabel}', style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text('Lo que regresa', style: GText.label()),
            const SizedBox(height: 4),
            for (final (i, l) in sale.lines.indexed)
              if (left[i]! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: GColors.linea)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.name, style: GText.sans(size: 14, weight: FontWeight.w700)),
                            Text('Compró ${qtyLabel(l.qty)} · ${money(l.unitCents)} c/u', style: GText.muted(size: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Regresa uno menos',
                        onPressed: (_back[i] ?? 0) > 0
                            ? () => setState(() => _back[i] = ((_back[i] ?? 0) - 1).clamp(0, left[i]!).toDouble())
                            : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          qtyLabel(_back[i] ?? 0),
                          textAlign: TextAlign.center,
                          style: GText.amount(
                            size: 17,
                            color: (_back[i] ?? 0) > 0 ? GColors.marca : GColors.tintaTenue,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Regresa uno más',
                        onPressed: (_back[i] ?? 0) < left[i]!
                            ? () => setState(() => _back[i] = ((_back[i] ?? 0) + 1).clamp(0, left[i]!).toDouble())
                            : null,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 18),
            Text('Lo que se lleva', style: GText.label()),
            const SizedBox(height: 4),
            for (final (i, (p, q)) in _take.indexed)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: GColors.linea)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: GText.sans(size: 14, weight: FontWeight.w700)),
                          Text(
                            ['${money(p.priceCents)} c/u', if (p.trackStock) 'hay ${qtyLabel(p.stock)}'].join(' · '),
                            style: GText.muted(size: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Uno menos',
                      onPressed: () => setState(() {
                        if (q > 1) {
                          _take[i] = (p, q - 1);
                        } else {
                          _take.removeAt(i);
                        }
                      }),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(qtyLabel(q), textAlign: TextAlign.center, style: GText.amount(size: 17)),
                    ),
                    IconButton(
                      tooltip: 'Uno más',
                      onPressed: () => setState(() => _take[i] = (p, q + 1)),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final m in uniqueModels)
                  ActionChip(
                    avatar: const Icon(Icons.straighten_rounded, size: 16),
                    label: Text('Otra talla de ${m.name}'),
                    onPressed: () => _otherSize(m),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(uniqueModels.isEmpty ? 'Agregar producto' : 'Otro producto'),
                  onPressed: _otherProduct,
                ),
              ],
            ),
            const SizedBox(height: 18),
            GCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Line('Regresa', '-${money(value)}'),
                  _Line('Se lleva', money(newTotal)),
                  const Divider(color: GColors.linea),
                  if (!ready)
                    Text(value == 0 ? 'Marca lo que regresa' : 'Agrega lo que se lleva', style: GText.muted(size: 13.5))
                  else if (diff > 0) ...[
                    _Line('Paga la diferencia', money(diff), strong: true, color: GColors.cenote),
                    const SizedBox(height: 10),
                    PayMethodChips(selected: _method, onPick: (m) => setState(() => _method = m)),
                  ] else if (diff < 0) ...[
                    _Line('Se le devuelven', money(-diff), strong: true, color: GColors.marca),
                    const SizedBox(height: 4),
                    Text(
                      canRefund
                          ? 'Sale del efectivo de la caja.'
                          : 'Devolver dinero lo autoriza el dueño. O que escoja algo de igual o más precio.',
                      style: GText.muted(size: 12.5),
                    ),
                  ] else
                    _Line('Queda parejo', money(0), strong: true),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lo que regresa vuelve al inventario y lo que se lleva sale. Queda una venta nueva con su ticket.',
              style: GText.muted(size: 12.5),
            ),
            const SizedBox(height: 14),
            GButton(
              label: 'Hacer el cambio',
              icon: Icons.swap_horiz_rounded,
              kind: GButtonKind.money,
              expand: true,
              big: true,
              onPressed: ready ? () => _confirm(value, newTotal) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.amount, {this.strong = false, this.color});

  final String label;
  final String amount;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: GText.sans(size: 14.5, weight: strong ? FontWeight.w800 : FontWeight.w500)),
        ),
        Text(
          amount,
          style: GText.amount(size: strong ? 20 : 16, color: color ?? GColors.tinta),
        ),
      ],
    ),
  );
}
