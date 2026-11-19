import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/save/save_file.dart';
import '../../core/ticket_text.dart';
import '../../domain/business.dart';
import '../../domain/models.dart';
import '../../domain/plan.dart';
import '../../domain/profit.dart';
import '../../domain/reports.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import 'profit_card.dart';

/// Abre los reportes, o explica que vienen en un plan de pago.
void openReports(BuildContext context, WidgetRef ref) {
  if (!ref.read(planProvider).limits.reports) {
    showUpgradeSheet(
      context,
      reason:
          'Reportes: ventas y ganancia de cualquier día o mes, por producto, por persona y por caja, '
          'con descarga para Excel. En el celular y en la computadora, aunque no haya internet.',
      needed: Plan.emprendedor,
    );
    return;
  }
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReportsScreen()));
}

/// Botón "Reportes" para la Caja (con candado si el plan no los incluye).
class ReportsButton extends ConsumerWidget {
  const ReportsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(planProvider).limits.reports;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GButton(
        label: unlocked ? 'Reportes del negocio' : 'Reportes del negocio · Emprendedor',
        icon: unlocked ? Icons.insights_rounded : Icons.lock_rounded,
        kind: GButtonKind.outline,
        expand: true,
        onPressed: () => openReports(context, ref),
      ),
    );
  }
}

/// Reportes del dueño: lo que antes estaba en el panel web, ahora dentro de la app.
/// Se calcula con lo guardado en el aparato (todas las cajas que ya se respaldaron), así que funciona sin internet.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  PeriodKey _key = PeriodKey.hoy;
  ReportPeriod _period = periodFor(PeriodKey.hoy);
  bool _allProducts = false;

  static const _chips = [
    (PeriodKey.hoy, 'Hoy'),
    (PeriodKey.ayer, 'Ayer'),
    (PeriodKey.semana, '7 días'),
    (PeriodKey.mes, 'Este mes'),
    (PeriodKey.mesPasado, 'Mes pasado'),
  ];

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _period.from,
        end: _period.to.subtract(const Duration(days: 1)).isAfter(now)
            ? now
            : _period.to.subtract(const Duration(days: 1)),
      ),
      helpText: 'Elige del día al día',
      saveText: 'Ver',
    );
    if (picked == null) return;
    setState(() {
      _key = PeriodKey.rango;
      _period = rangePeriod(picked.start, picked.end);
    });
  }

  Future<void> _download(String name, String csv) async {
    final bytes = Uint8List.fromList(utf8.encode(csv));
    try {
      await saveFile(bytes, name: name, mimeType: 'text/csv');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo guardar el archivo')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final restaurant = store.businessType == BusinessType.restaurante;
    final sessions = {for (final s in store.sessions) s.id: s};
    String registerOf(Sale s) {
      final session = sessions[s.sessionId];
      return StoreState.registerLabel(session?.name, session?.device ?? s.device);
    }

    final sales = salesIn(store.sales, _period);
    final before = salesIn(store.sales, _period.previous);
    final t = totalsOf(sales);
    final change = changePct(t.cents, totalsOf(before).cents);
    final profit = profitIn(sales);
    final buckets = _period.days <= 1 ? byHour(sales) : byDay(sales, _period);
    final methods = byMethod(sales);
    final clerks = byClerk(sales);
    final registers = byRegister(sales, registerOf);
    final returns = returnsIn(store.saleReturns, _period);
    final tips = tipsOf(sales);
    final folios = {for (final s in store.sales) s.id: s.folio};
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final stamp = '${_period.from.year}-${_two(_period.from.month)}-${_two(_period.from.day)}';

    Widget pair(Widget a, Widget b) => wide
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: a),
                Expanded(child: b),
              ],
            ),
          )
        : Column(children: [a, b]);

    final profitCard = StatCard(
      label: 'Ganancia',
      cents: profit.profitCents,
      color: profit.profitCents < 0 ? GColors.rojo : GColors.marca,
      icon: Icons.savings_rounded,
      margin: EdgeInsets.fromLTRB(wide ? 8 : 16, 4, wide ? 8 : 16, 4),
      caption: profit.soldWithCostCents == 0
          ? (t.count == 0 ? 'Sin ventas en este periodo' : 'Captura el costo de tus productos para verla')
          : profit.coverage < 0.98
          ? 'De lo que tiene costo (${(profit.coverage * 100).round()}% de lo vendido)'
          : 'Margen ${((profit.margin ?? 0) * 100).round()}%',
    );

    return Scaffold(
      appBar: AppBar(backgroundColor: GColors.fondo, surfaceTintColor: Colors.transparent),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 1100 : 760),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                ScreenTitle('Reportes', subtitle: '${_period.label} · todas las cajas'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final (k, label) in _chips)
                        ChoiceChip(
                          label: Text(label),
                          selected: _key == k,
                          onSelected: (_) => setState(() {
                            _key = k;
                            _period = periodFor(k);
                          }),
                        ),
                      ChoiceChip(
                        avatar: const Icon(Icons.date_range_rounded, size: 18),
                        label: Text(_key == PeriodKey.rango ? _period.label : 'Elegir fechas'),
                        selected: _key == PeriodKey.rango,
                        onSelected: (_) => _pickRange(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                pair(
                  StatCard(
                    label: 'Vendido',
                    cents: t.cents,
                    color: GColors.cenote,
                    icon: Icons.point_of_sale_rounded,
                    margin: EdgeInsets.fromLTRB(wide ? 8 : 16, 4, wide ? 8 : 16, 4),
                    caption: t.count == 0
                        ? 'Sin ventas en este periodo'
                        : '${t.count == 1 ? '1 venta' : '${t.count} ventas'} · promedio ${money(t.averageCents)}'
                              '${change == null ? '' : ' · ${change >= 0 ? '+' : '−'}${change.abs().round()}% contra antes'}',
                  ),
                  profitCard,
                ),
                _Card(
                  title: _period.days <= 1 ? 'Ventas por hora' : 'Ventas por día',
                  child: SalesBars(buckets: buckets),
                ),
                pair(
                  _Card(
                    title: 'Formas de pago',
                    inRow: wide,
                    child: methods.isEmpty ? const _Empty() : _Shares(rows: methods, color: GColors.cenote),
                  ),
                  _Card(
                    title: clerks.isEmpty ? 'Por caja' : 'Por persona',
                    inRow: wide,
                    child: (clerks.isEmpty ? registers : clerks).isEmpty
                        ? const _Empty()
                        : _Shares(rows: clerks.isEmpty ? registers : clerks, color: GColors.marca, ventas: true),
                  ),
                ),
                if (clerks.isNotEmpty && registers.length > 1)
                  _Card(
                    title: 'Por caja',
                    child: _Shares(rows: registers, color: GColors.cafe, ventas: true),
                  ),
                _Card(
                  title: restaurant ? 'Ganancia por platillo' : 'Ganancia por producto',
                  trailing: profit.products.length > 8
                      ? TextButton(
                          onPressed: () => setState(() => _allProducts = !_allProducts),
                          child: Text(_allProducts ? 'Ver menos' : 'Ver todos (${profit.products.length})'),
                        )
                      : null,
                  child: profit.isEmpty
                      ? const _Empty()
                      : Column(
                          children: [
                            for (final p in _allProducts ? profit.products : profit.products.take(8)) _ProductLine(p),
                          ],
                        ),
                ),
                if (tips.cents > 0)
                  _Card(
                    title: 'Propinas · ${money(tips.cents)}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'En ${tips.count == 1 ? '1 cuenta' : '${tips.count} cuentas'}. Son del equipo: no cuentan '
                          'como venta ni como ganancia.',
                          style: GText.muted(size: 12.5),
                        ),
                        if (tips.byPerson.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _Shares(rows: tips.byPerson, color: GColors.cenote, ventas: true),
                        ],
                      ],
                    ),
                  ),
                if (returns.isNotEmpty)
                  _Card(
                    title: 'Devoluciones · ${money(returns.fold(0, (a, r) => a + r.amountCents))}',
                    child: Column(
                      children: [
                        for (final r in returns)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.summary,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GText.sans(size: 14, weight: FontWeight.w700),
                                      ),
                                      Text(
                                        '${shortDayLabel(r.createdAt)} ${timeLabel(r.createdAt)}'
                                        '${folios[r.saleId] == null ? '' : ' · venta ${folios[r.saleId]}'}'
                                        '${r.reason == null || r.reason!.isEmpty ? '' : ' · ${r.reason}'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GText.muted(size: 12.5),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '−${money(r.amountCents)}',
                                  style: GText.figures(size: 14, weight: FontWeight.w700, color: GColors.rojo),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SectionTitle('Descargar para Excel'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SoftButton(
                        label: 'Ventas',
                        icon: Icons.download_rounded,
                        onTap: () => _download('ventas-$stamp.csv', salesCsv(sales, registerOf)),
                      ),
                      SoftButton(
                        label: restaurant ? 'Ganancia por platillo' : 'Ganancia por producto',
                        icon: Icons.download_rounded,
                        color: GColors.marca,
                        onTap: () => _download('ganancia-$stamp.csv', productsCsv(profit)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    'Con las ventas de todas las cajas que ya se respaldaron. Funciona aunque no haya internet; '
                    'lo de otras cajas llega cuando se conectan.',
                    style: GText.muted(size: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.trailing, this.inRow = false});

  final String title;
  final Widget child;
  final Widget? trailing;

  /// Va al lado de otra tarjeta (pantalla ancha): el margen lo pone la fila.
  final bool inRow;

  @override
  Widget build(BuildContext context) => GCard(
    margin: EdgeInsets.fromLTRB(inRow ? 8 : 16, 8, inRow ? 8 : 16, 4),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: GText.sans(size: 15, weight: FontWeight.w800)),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text('Nada en este periodo', style: GText.muted(size: 13.5)),
  );
}

/// Renglones con barra: cuánto de lo vendido fue de cada forma de pago, persona o caja.
class _Shares extends StatelessWidget {
  const _Shares({required this.rows, required this.color, this.ventas = false});

  final List<Share> rows;
  final Color color;

  /// Mostrar cuántas ventas (persona o caja) en lugar del porcentaje.
  final bool ventas;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GText.sans(size: 14, weight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    ventas ? (r.count == 1 ? '1 venta' : '${r.count} ventas') : '${(r.share * 100).round()}%',
                    style: GText.muted(size: 12.5),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: Text(
                      money(r.cents),
                      textAlign: TextAlign.right,
                      style: GText.figures(size: 14, weight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: r.share,
                  minHeight: 6,
                  backgroundColor: GColors.hundido,
                  color: color,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _ProductLine extends StatelessWidget {
  const _ProductLine(this.p);

  final ProductProfit p;

  @override
  Widget build(BuildContext context) {
    final m = p.margin;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                  '${qtyLabel(p.qty)} ${p.qty == 1 ? 'vendido' : 'vendidos'} · ${money(p.soldCents)}',
                  style: GText.figures(size: 12, color: GColors.tintaSuave),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (!p.knownCost)
            Text('sin costo', style: GText.muted(size: 12.5))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${p.profitCents < 0 ? '−' : '+'}${money(p.profitCents.abs())}',
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

/// Gráfica de barras de una sola serie (ventas por día u hora). Cada barra dice su monto al tocarla o
/// al pasar el ratón; abajo, solo algunas etiquetas para que no se encimen.
class SalesBars extends StatelessWidget {
  const SalesBars({super.key, required this.buckets});

  final List<Bucket> buckets;

  @override
  Widget build(BuildContext context) {
    final top = buckets.fold<int>(0, (m, b) => b.cents > m ? b.cents : m);
    if (top == 0) return const _Empty();
    var best = buckets.first;
    for (final b in buckets) {
      if (b.cents > best.cents) best = b;
    }
    return LayoutBuilder(
      builder: (context, box) {
        // Una etiqueta cada tantas barras, según el ancho.
        final every = (buckets.length * 34 / box.maxWidth).ceil().clamp(1, 31);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Lo más alto: ${money(best.cents)} (${best.detail})', style: GText.muted(size: 12.5)),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final b in buckets)
                    Expanded(
                      child: Tooltip(
                        message: '${b.detail}\n${money(b.cents)} · ${b.count == 1 ? '1 venta' : '${b.count} ventas'}',
                        triggerMode: TooltipTriggerMode.tap,
                        waitDuration: Duration.zero,
                        child: Container(
                          color: Colors.transparent,
                          alignment: Alignment.bottomCenter,
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: FractionallySizedBox(
                            heightFactor: b.cents == 0 ? 0.012 : (b.cents / top).clamp(0.03, 1.0),
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 28),
                              decoration: BoxDecoration(
                                color: b.cents == 0 ? GColors.linea : GColors.cenote,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(height: 1, color: GColors.linea),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final (i, b) in buckets.indexed)
                  Expanded(
                    child: Text(
                      i % every == 0 ? b.label : '',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      style: GText.sans(size: 11, color: GColors.tintaTenue),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
