import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/profit.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/common.dart';

/// Ganancia del turno, producto por producto: cuánto se vendió, a qué precio, qué costó y cuánto quedó.
/// Sirve para ver si a un producto le conviene su precio.
class ProfitCard extends StatefulWidget {
  const ProfitCard({super.key, required this.report, this.margin = const EdgeInsets.fromLTRB(16, 10, 16, 0)});

  final ProfitReport report;
  final EdgeInsetsGeometry margin;

  @override
  State<ProfitCard> createState() => _ProfitCardState();
}

class _ProfitCardState extends State<ProfitCard> {
  static const _firstRows = 6;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final withCost = r.withCost;
    final withoutCost = r.withoutCost;
    final shown = _all ? withCost : withCost.take(_firstRows).toList();
    final hidden = withCost.length - shown.length;
    final margin = r.margin;

    return GCard(
      margin: widget.margin,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GANANCIA DEL TURNO', style: GText.label()),
                    const SizedBox(height: 2),
                    Text(
                      money(r.profitCents),
                      style: GText.amount(size: 26, color: r.profitCents < 0 ? GColors.rojo : GColors.tinta),
                    ),
                  ],
                ),
              ),
              if (margin != null) MarginPill(margin),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            r.isEmpty
                ? 'Aún no hay ventas en este turno.'
                : 'Vendido ${money(r.soldWithCostCents)} − costo ${money(r.costCents)}'
                      '${r.coverage < 0.999 ? ' · solo lo que tiene costo' : ''}',
            style: GText.muted(size: 12.5),
          ),
          if (shown.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final (i, p) in shown.indexed) ...[
              if (i > 0) const Divider(height: 1, color: GColors.linea),
              _ProductRow(p),
            ],
          ],
          if (hidden > 0 || (_all && withCost.length > _firstRows))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _all = !_all),
                child: Text(
                  _all ? 'Ver menos' : 'Ver los ${withCost.length} productos',
                  style: GText.sans(size: 13.5, weight: FontWeight.w700, color: GColors.marca),
                ),
              ),
            ),
          if (withoutCost.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: GColors.fondo, borderRadius: BorderRadius.circular(GShape.radiusSmall)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: GColors.tintaSuave),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${withoutCost.length == 1 ? '1 producto vendido no tiene' : '${withoutCost.length} productos vendidos no tienen'} '
                      'costo de compra (${money(withoutCost.fold(0, (a, p) => a + p.soldCents))} vendido): '
                      '${withoutCost.take(4).map((p) => p.name).join(', ')}${withoutCost.length > 4 ? '…' : ''}. '
                      'Captúralo en Inventario para ver su ganancia.',
                      style: GText.sans(size: 12.5, weight: FontWeight.w500, color: GColors.tintaSuave),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow(this.p);

  final ProductProfit p;

  @override
  Widget build(BuildContext context) {
    final m = p.margin;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GText.sans(size: 14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${qtyLabel(p.qty)} ${p.qty == 1 ? 'vendido' : 'vendidos'} · venta ${money(p.unitPriceCents)} · costo ${money(p.unitCostCents)}',
                  style: GText.figures(size: 12, color: GColors.tintaSuave),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${p.profitCents < 0 ? '-' : '+'}${money(p.profitCents.abs())}',
                style: GText.figures(
                  size: 14.5,
                  weight: FontWeight.w800,
                  color: p.profitCents < 0 ? GColors.rojo : GColors.tinta,
                ),
              ),
              if (m != null) ...[const SizedBox(height: 3), MarginPill(m, small: true)],
            ],
          ),
        ],
      ),
    );
  }
}

/// Pastilla con el margen: "25%" en cenote, ámbar si es poco, rojo si se pierde.
class MarginPill extends StatelessWidget {
  const MarginPill(this.margin, {super.key, this.small = false});

  final double margin;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final color = marginColor(margin);
    return Tooltip(
      message: 'Margen: de cada peso que paga el cliente, te quedan ${(margin * 100).round()} centavos',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 7 : 10, vertical: small ? 1 : 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
        child: Text(
          small ? '${(margin * 100).round()}%' : 'margen ${(margin * 100).round()}%',
          style: GText.sans(size: small ? 11.5 : 13, weight: FontWeight.w800, color: color),
        ),
      ),
    );
  }
}
