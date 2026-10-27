import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/share.dart';
import '../../core/ticket_text.dart';
import '../../domain/models.dart';
import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';

/// Ticket de la venta con sello PAGADO o FIADO.
class TicketScreen extends ConsumerWidget {
  const TicketScreen({super.key, required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final plan = ref.watch(planProvider);
    final sale = store.sales.firstWhere((s) => s.id == saleId);
    final customer = sale.customerId == null ? null : store.customerById(sale.customerId!);
    final balance = customer == null ? null : store.balanceOf(customer.id);
    final paid = sale.kind == SaleKind.pagada;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.papel,
        surfaceTintColor: Colors.transparent,
        title: Text(paid ? 'Venta cobrada' : 'Venta fiada', style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  decoration: BoxDecoration(
                    color: GColors.papelClaro,
                    border: Border.all(color: GColors.linea),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            store.businessName.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: GText.sans(size: 15, weight: FontWeight.w800).copyWith(letterSpacing: 1.6),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Folio A-${sale.folio.toString().padLeft(4, '0')} · ${dateTimeLabel(sale.createdAt)}',
                            textAlign: TextAlign.center,
                            style: GText.mono(size: 11, color: GColors.tintaSuave),
                          ),
                          const SizedBox(height: 10),
                          for (final l in sale.lines) _row('${qtyLabel(l.qty)} x ${l.name}', money(l.totalCents)),
                          const _Dashed(),
                          _row('TOTAL', money(sale.totalCents), bold: true),
                          const _Dashed(),
                          if (paid) ...[
                            _row('Pago', sale.method!.label),
                            if (sale.method == PayMethod.efectivo) ...[
                              _row('Recibió', money(sale.receivedCents ?? sale.totalCents)),
                              _row('Cambio', money(sale.changeCents)),
                            ],
                          ] else ...[
                            _row('Cliente', customer?.name ?? ''),
                            _row('Saldo pendiente', money(balance ?? 0)),
                          ],
                          if (plan.limits.watermark) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Hecho con Gavilán',
                              textAlign: TextAlign.center,
                              style: GText.mono(size: 10.5, color: GColors.tintaTenue),
                            ),
                          ],
                          const SizedBox(height: 26),
                        ],
                      ),
                      Positioned(right: 0, bottom: 44, child: _Stamp(paid: paid)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GButton(
                      label: 'Mandar por WhatsApp',
                      icon: Icons.send_outlined,
                      kind: GButtonKind.money,
                      expand: true,
                      onPressed: () => shareText(
                        context,
                        ticketText(
                          business: store.businessName,
                          sale: sale,
                          customerName: customer?.name,
                          newBalanceCents: balance,
                          watermark: plan.limits.watermark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GButton(
                      label: 'Nueva venta',
                      kind: GButtonKind.outline,
                      expand: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            a,
            style: GText.mono(size: bold ? 14 : 11.5, weight: bold ? FontWeight.w700 : FontWeight.w400),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          b,
          style: GText.mono(size: bold ? 14 : 11.5, weight: bold ? FontWeight.w700 : FontWeight.w400),
        ),
      ],
    ),
  );
}

class _Dashed extends StatelessWidget {
  const _Dashed();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        '- ' * 60,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: GText.mono(size: 10, color: GColors.tintaTenue),
      ),
    );
  }
}

/// Sello que "cae" sobre el ticket.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.paid});

  final bool paid;

  @override
  Widget build(BuildContext context) {
    final color = paid ? GColors.monte : GColors.rojo;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.rotate(
          angle: -0.157,
          child: Transform.scale(scale: 2.2 - 1.2 * v, child: child),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          paid ? 'PAGADO' : 'FIADO',
          style: GText.sans(size: 24, weight: FontWeight.w800, color: color).copyWith(letterSpacing: 2),
        ),
      ),
    );
  }
}
