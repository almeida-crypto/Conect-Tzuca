import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/ticket_text.dart';
import '../../domain/models.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../cobrar/ticket_screen.dart';
import '../widgets/common.dart';

/// Las ventas de un turno, la más reciente arriba. Tocar una abre su ticket (para volver a mandarlo,
/// imprimirlo o cancelarla).
class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final session = store.sessions.where((s) => s.id == sessionId).firstOrNull;
    final sales = session == null ? const <Sale>[] : store.salesOf(session);
    final valid = sales.where((s) => !s.cancelled);
    final total = valid.fold(0, (a, s) => a + s.totalCents);
    final cancelled = sales.length - valid.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ventas del turno', style: GText.sans(size: 17, weight: FontWeight.w800)),
            Text(
              '${valid.length} ${valid.length == 1 ? 'venta' : 'ventas'} · ${money(total)}'
              '${cancelled > 0 ? ' · $cancelled ${cancelled == 1 ? 'cancelada' : 'canceladas'}' : ''}',
              style: GText.muted(size: 12),
            ),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: sales.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Todavía no hay ventas en este turno.',
                    textAlign: TextAlign.center,
                    style: GText.muted(size: 14),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    GCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final (i, s) in sales.indexed) ...[
                            if (i > 0) const Divider(height: 1, color: GColors.linea),
                            _SaleRow(
                              sale: s,
                              customer: s.customerId == null ? null : store.customerById(s.customerId!)?.name,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.sale, this.customer});

  final Sale sale;
  final String? customer;

  @override
  Widget build(BuildContext context) {
    final s = sale;
    final items = s.lines.map((l) => '${qtyLabel(l.qty)} ${l.name}').join(', ');
    final how = s.kind == SaleKind.fiada ? 'Fiado${customer == null ? '' : ' · $customer'}' : s.method?.label ?? '';
    final muted = s.cancelled;
    return InkWell(
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => TicketScreen(saleId: s.id, fromHistory: true))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(timeLabel(s.createdAt), style: GText.figures(size: 13, weight: FontWeight.w700)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    items,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GText.sans(
                      size: 14,
                      weight: FontWeight.w600,
                      color: muted ? GColors.tintaTenue : GColors.tinta,
                    ).copyWith(decoration: muted ? TextDecoration.lineThrough : null),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    muted ? 'Cancelada · ${s.cancelReason ?? ''}' : '${s.folioLabel} · $how',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GText.sans(
                      size: 12,
                      weight: FontWeight.w500,
                      color: muted ? GColors.rojo : GColors.tintaSuave,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              money(s.totalCents),
              style: GText.figures(
                size: 14.5,
                weight: FontWeight.w800,
                color: muted ? GColors.tintaTenue : GColors.tinta,
              ).copyWith(decoration: muted ? TextDecoration.lineThrough : null),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: GColors.tintaTenue),
          ],
        ),
      ),
    );
  }
}
