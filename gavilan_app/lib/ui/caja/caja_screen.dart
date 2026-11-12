import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/ticket_text.dart';
import '../../domain/models.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import 'cash_dialogs.dart';
import 'profit_card.dart';

/// Corte de caja: lo que debe haber en el cajón, calculado de las ventas, abonos y gastos del turno.
class CajaScreen extends ConsumerStatefulWidget {
  const CajaScreen({super.key, required this.onGoToCobrar});

  final VoidCallback onGoToCobrar;

  @override
  ConsumerState<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends ConsumerState<CajaScreen> {
  final _counted = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _counted.dispose();
    super.dispose();
  }

  Future<void> _close(CashSummary summary) async {
    final counted = parseMoney(_counted.text);
    if (counted == null) {
      setState(() => _error = 'Escribe cuánto efectivo contaste');
      return;
    }
    final diff = counted - summary.expectedCashCents;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar la caja?'),
        content: Text(
          diff == 0
              ? 'Cuadra al peso: ${money(counted)} en el cajón.'
              : diff > 0
              ? 'Te sobran ${money(diff)}. Se guardará así en el corte.'
              : 'Te faltan ${money(-diff)}. Se guardará así en el corte.',
          style: GText.sans(size: 14, weight: FontWeight.w400),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Revisar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Cerrar caja')),
        ],
      ),
    );
    if (confirm != true) return;
    ref.read(storeProvider.notifier).closeCash(counted);
    _counted.clear();
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final session = store.openSession;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (session == null) ..._closedView(store) else ..._openView(store, session),
        if (store.closedSessions.isNotEmpty) ...[
          const SectionTitle('Cortes anteriores'),
          GCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (final (i, s) in store.closedSessions.take(10).indexed) ...[
                  if (i > 0) const Divider(height: 1, color: GColors.linea),
                  _PastCut(session: s, onTap: () => showCutDetail(context, s)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _openView(StoreState store, CashSession session) {
    final s = store.summaryFor(session);
    final gastos = store.movements.where((m) => m.sessionId == session.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final counted = parseMoney(_counted.text);
    final diff = counted == null ? null : counted - s.expectedCashCents;

    return [
      const ScreenTitle('Corte de hoy'),
      StatCard(
        label: 'Debe haber en caja',
        cents: s.expectedCashCents,
        color: GColors.cenote,
        icon: Icons.account_balance_wallet_rounded,
        caption:
            'Abierta a las ${timeLabel(session.openedAt)} · ${s.salesCount} ${s.salesCount == 1 ? 'venta' : 'ventas'}',
      ),
      GCard(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          children: [
            _Ledger('Fondo inicial', s.openingCents),
            _Ledger('Ventas en efectivo', s.cashSalesCents),
            _Ledger('Abonos de fiados', s.cashAbonosCents),
            if (s.lotSalesCents > 0) _Ledger('Pacas y lotes', s.lotSalesCents),
            if (s.cashLayawayCents > 0) _Ledger('Apartados', s.cashLayawayCents),
            if (s.entradasCents > 0) _Ledger('Entradas', s.entradasCents),
            _Ledger('Gastos', -s.gastosCents, color: s.gastosCents > 0 ? GColors.rojo : null),
            _Ledger('Debe haber en caja', s.expectedCashCents, total: true),
          ],
        ),
      ),
      GCard(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          children: [
            _Ledger(
              'Tarjeta y transferencia',
              s.otherSalesCents + s.otherAbonosCents + s.otherLayawayCents,
              muted: true,
            ),
            _Ledger('Vendido fiado (no entra a caja)', s.creditSalesCents, muted: true),
            _Ledger('Total vendido hoy', s.totalSoldCents, muted: true),
          ],
        ),
      ),
      if (ref.watch(permissionsProvider).seeProfit) ProfitCard(report: store.profitFor(session)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: GButton(
                label: 'Gasto',
                icon: Icons.remove_rounded,
                kind: GButtonKind.outline,
                expand: true,
                onPressed: () => showMovementSheet(context, CashKind.gasto),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GButton(
                label: 'Entrada',
                icon: Icons.add_rounded,
                kind: GButtonKind.outline,
                expand: true,
                onPressed: () => showMovementSheet(context, CashKind.entrada),
              ),
            ),
          ],
        ),
      ),
      if (gastos.isNotEmpty)
        GCard(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              for (final m in gastos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: m.kind == CashKind.gasto ? GColors.rojoSuave : GColors.cenoteSuave,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          m.kind == CashKind.gasto ? Icons.south_east_rounded : Icons.north_east_rounded,
                          size: 17,
                          color: m.kind == CashKind.gasto ? GColors.rojo : GColors.cenote,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.concept, style: GText.sans(size: 14, weight: FontWeight.w600)),
                            Text(timeLabel(m.createdAt), style: GText.muted()),
                          ],
                        ),
                      ),
                      Text(
                        '${m.kind == CashKind.gasto ? '-' : '+'}${money(m.amountCents)}',
                        style: GText.figures(
                          size: 14,
                          weight: FontWeight.w700,
                          color: m.kind == CashKind.gasto ? GColors.rojo : GColors.cenote,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      GCard(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Efectivo que contaste', style: GText.sans(size: 14, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _counted,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _error = null),
              style: GText.amount(size: 26),
              decoration: InputDecoration(prefixText: '\$ ', hintText: '0.00', errorText: _error),
            ),
            const SizedBox(height: 8),
            // Si cuadra o no, aparece con un desvanecido al escribir.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: diff == null
                  ? const SizedBox(height: 8, key: ValueKey('nada'))
                  : Container(
                      key: ValueKey(diff.sign),
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: diff < 0 ? GColors.rojoSuave : GColors.cenoteSuave,
                        borderRadius: BorderRadius.circular(GShape.radiusSmall),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            diff == 0
                                ? Icons.check_circle_rounded
                                : (diff > 0 ? Icons.add_circle_rounded : Icons.error_rounded),
                            size: 18,
                            color: diff < 0 ? GColors.rojo : GColors.cenote,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            diff == 0
                                ? 'Cuadra al peso'
                                : diff > 0
                                ? 'Te sobran ${money(diff)}'
                                : 'Te faltan ${money(-diff)}',
                            style: GText.sans(
                              size: 14.5,
                              weight: FontWeight.w800,
                              color: diff < 0 ? GColors.rojo : GColors.cenote,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: GButton(
          label: 'Cerrar caja',
          icon: Icons.lock_outline_rounded,
          kind: GButtonKind.dark,
          expand: true,
          big: true,
          onPressed: () => _close(s),
        ),
      ),
    ];
  }

  List<Widget> _closedView(StoreState store) {
    final last = store.closedSessions.isEmpty ? null : store.closedSessions.first;
    return [
      const ScreenTitle('Caja cerrada', subtitle: 'Abre la caja para empezar a cobrar'),
      if (last != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _CutCard(session: last, summary: store.summaryFor(last), onDetail: () => showCutDetail(context, last)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: GButton(
          icon: Icons.lock_open_rounded,
          label: 'Abrir caja',
          expand: true,
          big: true,
          onPressed: () async {
            final opened = await showOpenCashDialog(context, ref);
            if (opened) widget.onGoToCobrar();
          },
        ),
      ),
    ];
  }
}

/// Renglón de la cuenta: concepto a la izquierda, monto a la derecha.
class _Ledger extends StatelessWidget {
  const _Ledger(this.label, this.cents, {this.total = false, this.muted = false, this.color});

  final String label;
  final int cents;
  final bool total;
  final bool muted;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: total ? 12 : 7, bottom: total ? 2 : 7),
      margin: EdgeInsets.only(top: total ? 4 : 0),
      decoration: total
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: GColors.linea, width: 1.5)),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GText.sans(
                size: total ? 15 : 14,
                weight: total ? FontWeight.w800 : FontWeight.w500,
                color: muted ? GColors.tintaSuave : GColors.tinta,
              ),
            ),
          ),
          Text(
            money(cents),
            style: total
                ? GText.amount(size: 19, color: color ?? GColors.tinta)
                : GText.figures(
                    size: 14,
                    weight: FontWeight.w700,
                    color: color ?? (muted ? GColors.tintaSuave : GColors.tinta),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CutCard extends StatelessWidget {
  const _CutCard({required this.session, required this.summary, required this.onDetail});

  final CashSession session;
  final CashSummary summary;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final diff = session.differenceCents ?? 0;
    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Último corte · ${dateTimeLabel(session.closedAt!)}',
            style: GText.sans(size: 14, weight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          _Ledger('Debía haber', session.expectedCents ?? 0),
          _Ledger('Se contó', session.countedCents ?? 0),
          _Ledger(
            diff == 0 ? 'Cuadró' : (diff > 0 ? 'Sobró' : 'Faltó'),
            diff.abs(),
            color: diff < 0 ? GColors.rojo : GColors.cenote,
          ),
          _Ledger('Total vendido', summary.totalSoldCents, muted: true),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onDetail,
              child: Text(
                'Ver el corte completo',
                style: GText.sans(size: 13.5, weight: FontWeight.w700, color: GColors.marca),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PastCut extends StatelessWidget {
  const _PastCut({required this.session, required this.onTap});

  final CashSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final diff = session.differenceCents ?? 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(dateTimeLabel(session.closedAt!), style: GText.figures(size: 13, weight: FontWeight.w500)),
            ),
            Text(money(session.countedCents ?? 0), style: GText.figures(size: 13, weight: FontWeight.w700)),
            const SizedBox(width: 12),
            SizedBox(
              width: 92,
              child: Text(
                diff == 0 ? 'cuadró' : (diff > 0 ? '+${money(diff)}' : '-${money(-diff)}'),
                textAlign: TextAlign.right,
                style: GText.figures(
                  size: 13,
                  weight: FontWeight.w700,
                  color: diff < 0 ? GColors.rojo : GColors.cenote,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20, color: GColors.tintaTenue),
          ],
        ),
      ),
    );
  }
}

/// Un corte cerrado completo: cuadre de caja y, para el dueño, la ganancia de cada producto vendido.
Future<void> showCutDetail(BuildContext context, CashSession session) {
  return showGSheet(
    context,
    (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final store = ref.watch(storeProvider);
        final summary = store.summaryFor(session);
        final diff = session.differenceCents ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              'Corte de caja',
              caption: '${dateTimeLabel(session.openedAt)} a ${timeLabel(session.closedAt ?? DateTime.now())}',
            ),
            _Ledger('Fondo inicial', summary.openingCents),
            _Ledger('Ventas en efectivo', summary.cashSalesCents),
            _Ledger('Debía haber', session.expectedCents ?? summary.expectedCashCents),
            _Ledger('Se contó', session.countedCents ?? 0),
            _Ledger(
              diff == 0 ? 'Cuadró' : (diff > 0 ? 'Sobró' : 'Faltó'),
              diff.abs(),
              color: diff < 0 ? GColors.rojo : GColors.cenote,
            ),
            _Ledger('Total vendido', summary.totalSoldCents, total: true),
            if (ref.watch(permissionsProvider).seeProfit)
              ProfitCard(report: store.profitFor(session), margin: const EdgeInsets.only(top: 14)),
          ],
        );
      },
    ),
  );
}
