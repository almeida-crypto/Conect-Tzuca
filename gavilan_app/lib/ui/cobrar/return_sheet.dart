import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

/// Lo que el cliente regresa: cuánto de cada renglón (por posición) y por qué.
typedef ReturnRequest = ({Map<int, double> back, String reason});

/// Hoja para devolver parte de una venta: se elige cuánto regresa de cada producto.
Future<ReturnRequest?> showReturnSheet(BuildContext context, Sale sale) =>
    showGSheet<ReturnRequest>(context, (_) => _ReturnSheet(sale: sale));

class _ReturnSheet extends StatefulWidget {
  const _ReturnSheet({required this.sale});

  final Sale sale;

  @override
  State<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends State<_ReturnSheet> {
  final _back = <int, double>{};
  static const _reasons = ['Producto en mal estado', 'Se equivocó de producto', 'Ya no lo quiso'];
  String _reason = _reasons.first;

  /// Piezas enteras de una en una; lo que va por kilo (con decimales) se regresa completo o nada.
  double _step(SaleLine l) => l.qty == l.qty.roundToDouble() ? 1 : l.qty;

  void _change(int i, SaleLine l, double delta) =>
      setState(() => _back[i] = ((_back[i] ?? 0) + delta).clamp(0, l.qty).toDouble());

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final factor = sale.subtotalCents == 0 ? 1.0 : sale.totalCents / sale.subtotalCents;
    var refund = 0;
    for (final (i, l) in sale.lines.indexed) {
      refund += ((_back[i] ?? 0) * l.unitCents * factor).round();
    }
    final any = _back.values.any((v) => v > 0);
    final howBack = sale.kind == SaleKind.fiada
        ? 'Se le quitan ${money(refund)} de la deuda.'
        : sale.method == PayMethod.efectivo
        ? 'Devuélvele ${money(refund)} en efectivo.'
        : 'Devuélvele ${money(refund)} por ${sale.method?.label.toLowerCase() ?? 'el mismo medio'}.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader('Devolver productos', caption: 'Venta ${sale.folioLabel}'),
        Text(
          'Marca lo que regresa el cliente. Lo demás se queda como una venta nueva con su propio folio.',
          style: GText.sans(size: 13, weight: FontWeight.w400, color: GColors.tintaSuave),
        ),
        const SizedBox(height: 10),
        for (final (i, l) in sale.lines.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
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
                      Text('Compró ${qtyLabel(l.qty)} · ${money(l.unitCents)} c/u', style: GText.muted(size: 12.5)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Regresa uno menos',
                  onPressed: (_back[i] ?? 0) > 0 ? () => _change(i, l, -_step(l)) : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    qtyLabel(_back[i] ?? 0),
                    textAlign: TextAlign.center,
                    style: GText.amount(size: 17, color: (_back[i] ?? 0) > 0 ? GColors.rojo : GColors.tintaTenue),
                  ),
                ),
                IconButton(
                  tooltip: 'Regresa uno más',
                  onPressed: (_back[i] ?? 0) < l.qty ? () => _change(i, l, _step(l)) : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text('¿Por qué?', style: GText.sans(size: 13, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in _reasons) GChip(label: r, selected: _reason == r, onTap: () => setState(() => _reason = r)),
          ],
        ),
        if (any) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GColors.rojoSuave,
              borderRadius: BorderRadius.circular(GShape.radiusSmall),
            ),
            child: Text(
              '$howBack Lo devuelto regresa al inventario.',
              style: GText.sans(size: 13.5, weight: FontWeight.w600, color: GColors.rojo),
            ),
          ),
        ],
        const SizedBox(height: 14),
        GButton(
          label: any ? 'Devolver ${money(refund)}' : 'Marca lo que regresa',
          icon: Icons.undo_rounded,
          kind: GButtonKind.dark,
          expand: true,
          onPressed: any ? () => Navigator.of(context).pop((back: Map.of(_back), reason: _reason)) : null,
        ),
      ],
    );
  }
}
