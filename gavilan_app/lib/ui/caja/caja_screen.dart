import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/ticket_text.dart';
import '../../domain/models.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import 'cash_dialogs.dart';

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
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Cortes anteriores', style: GText.sans(size: 15, weight: FontWeight.w800)),
          ),
          for (final s in store.closedSessions.take(10)) _PastCut(session: s),
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
      ScreenTitle('Corte de hoy', subtitle: 'Abierta a las ${timeLabel(session.openedAt)} · ${s.salesCount} ventas'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(
          children: [
            _Ledger('Fondo inicial', s.openingCents),
            _Ledger('Ventas en efectivo', s.cashSalesCents),
            _Ledger('Abonos de fiados', s.cashAbonosCents),
            if (s.entradasCents > 0) _Ledger('Entradas', s.entradasCents),
            _Ledger('Gastos', -s.gastosCents, color: s.gastosCents > 0 ? GColors.rojo : null),
            _Ledger('Debe haber en caja', s.expectedCashCents, total: true),
            const SizedBox(height: 10),
            _Ledger('Tarjeta y transferencia', s.otherSalesCents + s.otherAbonosCents, muted: true),
            _Ledger('Vendido fiado (no entra a caja)', s.creditSalesCents, muted: true),
            _Ledger('Total vendido hoy', s.totalSoldCents, muted: true),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: GButton(
                label: 'Gasto',
                icon: Icons.remove,
                kind: GButtonKind.outline,
                expand: true,
                onPressed: () => showMovementSheet(context, CashKind.gasto),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GButton(
                label: 'Entrada',
                icon: Icons.add,
                kind: GButtonKind.outline,
                expand: true,
                onPressed: () => showMovementSheet(context, CashKind.entrada),
              ),
            ),
          ],
        ),
      ),
      if (gastos.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              for (final m in gastos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text(timeLabel(m.createdAt), style: GText.mono(size: 11, color: GColors.tintaSuave)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(m.concept, style: GText.sans(size: 13, weight: FontWeight.w400)),
                      ),
                      Text(
                        '${m.kind == CashKind.gasto ? '-' : '+'}${money(m.amountCents)}',
                        style: GText.mono(size: 12, color: m.kind == CashKind.gasto ? GColors.rojo : GColors.monte),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Efectivo que contaste', style: GText.sans(size: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _counted,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _error = null),
              style: GText.amount(size: 26),
              decoration: InputDecoration(prefixText: '\$ ', hintText: '0.00', errorText: _error),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 22,
              child: diff == null
                  ? null
                  : Text(
                      diff == 0
                          ? 'Cuadra al peso'
                          : diff > 0
                          ? 'Te sobran ${money(diff)}'
                          : 'Te faltan ${money(-diff)}',
                      style: GText.sans(
                        size: 15,
                        weight: FontWeight.w800,
                        color: diff < 0 ? GColors.rojo : GColors.monte,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            GButton(label: 'Cerrar caja', expand: true, big: true, onPressed: () => _close(s)),
          ],
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
          child: _CutCard(session: last, summary: store.summaryFor(last)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: GButton(
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

/// Renglón tipo libreta: concepto ........ monto.
class _Ledger extends StatelessWidget {
  const _Ledger(this.label, this.cents, {this.total = false, this.muted = false, this.color});

  final String label;
  final int cents;
  final bool total;
  final bool muted;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = GText.mono(
      size: total ? 13.5 : 12,
      weight: total ? FontWeight.w700 : FontWeight.w400,
      color: muted ? GColors.tintaSuave : GColors.tinta,
    );
    return Container(
      padding: EdgeInsets.only(top: total ? 9 : 5, bottom: 5),
      margin: EdgeInsets.only(top: total ? 6 : 0),
      decoration: total
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: GColors.tinta, width: 1.5)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: style),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: CustomPaint(painter: _DotsPainter(), size: const Size(double.infinity, 2)),
            ),
          ),
          const SizedBox(width: 6),
          Text(money(cents), style: style.copyWith(color: color ?? style.color)),
        ],
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x66221C17);
    for (var x = 0.0; x < size.width; x += 4) {
      canvas.drawCircle(Offset(x, size.height / 2), 0.8, p);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => false;
}

class _CutCard extends StatelessWidget {
  const _CutCard({required this.session, required this.summary});

  final CashSession session;
  final CashSummary summary;

  @override
  Widget build(BuildContext context) {
    final diff = session.differenceCents ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GColors.papelClaro,
        border: Border.all(color: GColors.linea),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Último corte · ${dateTimeLabel(session.closedAt!)}',
            style: GText.sans(size: 13, weight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _Ledger('Debía haber', session.expectedCents ?? 0),
          _Ledger('Se contó', session.countedCents ?? 0),
          _Ledger(
            diff == 0 ? 'Cuadró' : (diff > 0 ? 'Sobró' : 'Faltó'),
            diff.abs(),
            color: diff < 0 ? GColors.rojo : GColors.monte,
          ),
          _Ledger('Total vendido', summary.totalSoldCents, muted: true),
        ],
      ),
    );
  }
}

class _PastCut extends StatelessWidget {
  const _PastCut({required this.session});

  final CashSession session;

  @override
  Widget build(BuildContext context) {
    final diff = session.differenceCents ?? 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GColors.linea)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(dateTimeLabel(session.closedAt!), style: GText.mono(size: 12))),
          Text(money(session.countedCents ?? 0), style: GText.mono(size: 12)),
          const SizedBox(width: 12),
          SizedBox(
            width: 92,
            child: Text(
              diff == 0 ? 'cuadró' : (diff > 0 ? '+${money(diff)}' : '-${money(-diff)}'),
              textAlign: TextAlign.right,
              style: GText.mono(size: 12, color: diff < 0 ? GColors.rojo : GColors.monte),
            ),
          ),
        ],
      ),
    );
  }
}
