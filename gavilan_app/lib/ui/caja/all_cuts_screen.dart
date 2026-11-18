import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/ticket_text.dart';
import '../../domain/models.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/common.dart';
import 'caja_screen.dart';
import 'sales_screen.dart';

/// "Todas las cajas": el corte del día de todos los celulares del negocio juntos, para el dueño.
/// Cada celular lleva su caja; aquí se ve cuánto vendió cada una y cuánto debe haber en cada cajón.
class AllCutsScreen extends ConsumerStatefulWidget {
  const AllCutsScreen({super.key});

  @override
  ConsumerState<AllCutsScreen> createState() => _AllCutsScreenState();
}

class _AllCutsScreenState extends ConsumerState<AllCutsScreen> {
  late DateTime _day = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _dayLabel(DateTime d) {
    final today = _today();
    if (d == today) return 'Hoy';
    if (d == today.subtract(const Duration(days: 1))) return 'Ayer';
    const days = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    return '${days[d.weekday - 1]} ${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final sync = ref.watch(syncProvider);
    final cuts = store.cutsOn(_day);
    final total = cuts.fold(CashSummary.zero, (a, c) => a + c.summary);
    final diff = cuts.fold(0, (a, c) => a + c.differenceCents);
    final closed = cuts.any((c) => c.anyClosed);
    final people = store.salesByClerkIn([for (final c in cuts) ...c.sessions]);
    final isToday = _day == _today();

    return Scaffold(
      appBar: AppBar(backgroundColor: GColors.fondo, surfaceTintColor: Colors.transparent),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                ScreenTitle(
                  'Todas las cajas',
                  subtitle: 'El corte de todos los celulares del negocio',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Día anterior',
                        onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 1))),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Text(_dayLabel(_day), style: GText.sans(size: 14, weight: FontWeight.w800)),
                      IconButton(
                        tooltip: 'Día siguiente',
                        onPressed: isToday ? null : () => setState(() => _day = _day.add(const Duration(days: 1))),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
                if (cuts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      'Ese día ninguna caja se abrió.',
                      textAlign: TextAlign.center,
                      style: GText.muted(size: 14),
                    ),
                  )
                else ...[
                  StatCard(
                    label: 'Vendido en todas las cajas',
                    cents: total.totalSoldCents,
                    color: GColors.cenote,
                    icon: Icons.point_of_sale_rounded,
                    caption:
                        '${cuts.length == 1 ? '1 caja' : '${cuts.length} cajas'} · '
                        '${total.salesCount == 1 ? '1 venta' : '${total.salesCount} ventas'}',
                  ),
                  GCard(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Column(
                      children: [
                        _Row('Debe haber en efectivo', total.expectedCashCents, strong: true),
                        _Row('Tarjeta y transferencia', total.otherInCents),
                        _Row('Vendido fiado', total.creditSalesCents),
                        if (total.gastosCents > 0) _Row('Gastos', -total.gastosCents, color: GColors.rojo),
                        if (closed)
                          _Row(
                            diff == 0
                                ? 'Los cortes cuadraron'
                                : diff > 0
                                ? 'Sobró en los cortes'
                                : 'Faltó en los cortes',
                            diff.abs(),
                            color: diff < 0 ? GColors.rojo : GColors.cenote,
                          ),
                      ],
                    ),
                  ),
                  if (people.isNotEmpty) ByClerkCard(rows: people, margin: const EdgeInsets.fromLTRB(16, 10, 16, 0)),
                  const SectionTitle('Cada caja'),
                  for (final c in cuts) _DeviceCard(cut: c),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Text(
                    'Lo de cada celular llega cuando tiene internet.'
                    '${sync.lastSync == null ? '' : ' Último respaldo de este: ${timeLabel(sync.lastSync!)}.'}',
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

class _Row extends StatelessWidget {
  const _Row(this.label, this.cents, {this.color, this.strong = false});

  final String label;
  final int cents;
  final Color? color;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: GText.sans(size: 14, weight: strong ? FontWeight.w800 : FontWeight.w500)),
        ),
        Text(
          money(cents),
          style: strong
              ? GText.amount(size: 18, color: color ?? GColors.tinta)
              : GText.figures(size: 14, weight: FontWeight.w700, color: color ?? GColors.tinta),
        ),
      ],
    ),
  );
}

/// Una caja: de qué celular es, si sigue abierta, cuánto vendió y cuánto debe haber.
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.cut});

  final DeviceCut cut;

  @override
  Widget build(BuildContext context) {
    final s = cut.summary;
    final last = cut.sessions.first;
    final status = cut.open ? 'Abierta' : 'Cerró a las ${timeLabel(last.closedAt!)}';
    final diff = cut.differenceCents;
    return GCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${StoreState.registerLabel(cut.name, cut.device)}${cut.mine ? ' · este celular' : ''}',
                  style: GText.sans(size: 15.5, weight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: cut.open ? GColors.cenoteSuave : GColors.hundido,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  status,
                  style: GText.sans(
                    size: 12,
                    weight: FontWeight.w800,
                    color: cut.open ? GColors.cenote : GColors.tintaSuave,
                  ),
                ),
              ),
            ],
          ),
          if (cut.people.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Atendieron: ${cut.people.join(', ')}', style: GText.muted(size: 12.5)),
            ),
          const SizedBox(height: 6),
          _Row('Vendido', s.totalSoldCents),
          _Row('Debe haber en efectivo', s.expectedCashCents),
          if (cut.anyClosed && !cut.open)
            _Row(
              diff == 0
                  ? 'Cuadró'
                  : diff > 0
                  ? 'Sobró'
                  : 'Faltó',
              diff.abs(),
              color: diff < 0 ? GColors.rojo : GColors.cenote,
            ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => SalesScreen(sessionId: last.id))),
                icon: const Icon(Icons.receipt_long_rounded, size: 18, color: GColors.marca),
                label: Text(
                  'Ventas (${s.salesCount})',
                  style: GText.sans(size: 13.5, weight: FontWeight.w700, color: GColors.marca),
                ),
              ),
              const Spacer(),
              if (!last.isOpen)
                TextButton(
                  onPressed: () => showCutDetail(context, last),
                  child: Text(
                    'Ver corte',
                    style: GText.sans(size: 13.5, weight: FontWeight.w700, color: GColors.marca),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
