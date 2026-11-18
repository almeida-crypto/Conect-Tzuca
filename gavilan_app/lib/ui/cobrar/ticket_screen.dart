import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/print/print.dart';
import '../../core/share.dart';
import '../../core/ticket_html.dart';
import '../../core/ticket_text.dart';
import '../../domain/models.dart';
import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../clerks/lock_screen.dart';
import 'return_sheet.dart';

/// Ticket de la venta con sello PAGADO, FIADO o CANCELADA.
class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({super.key, required this.saleId, this.fromHistory = false});

  final String saleId;

  /// Se abrió desde la lista de ventas (no recién cobrada): el botón dice "Volver".
  final bool fromHistory;

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> {
  /// Lo que queda dentro de esta llave es lo que se manda como imagen.
  final _ticketKey = GlobalKey();

  Future<bool> _authorized(String action) =>
      allowOrAskPin(context, ref, allowed: (can) => can.cancelSales, action: action);

  Future<void> _returnItems(Sale sale) async {
    if (!await _authorized('Devolver productos') || !mounted) return;
    final request = await showReturnSheet(context, sale);
    if (request == null || !mounted) return;
    final newSale = ref.read(storeProvider.notifier).returnItems(sale.id, request.back, reason: request.reason);
    final messenger = ScaffoldMessenger.of(context);
    if (newSale != null) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute<void>(builder: (_) => TicketScreen(saleId: newSale.id, fromHistory: true)));
      messenger.showSnackBar(SnackBar(content: Text('Devolución hecha. Esta es la venta nueva ${newSale.folioLabel}')));
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('Regresó todo: la venta quedó cancelada')));
    }
  }

  Future<void> _confirmCancel(Sale sale, String? customerName) async {
    if (!await _authorized('Cancelar la venta ${sale.folioLabel}') || !mounted) return;
    final reason = await showCancelSaleDialog(context, sale, customerName: customerName);
    if (reason == null || !mounted) return;
    final done = ref.read(storeProvider.notifier).cancelSale(sale.id, reason: reason);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(done == null ? 'No se pudo cancelar: el turno ya se cerró' : 'Venta cancelada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final plan = ref.watch(planProvider);
    final sale = store.sales.firstWhere((s) => s.id == widget.saleId);
    final customer = sale.customerId == null ? null : store.customerById(sale.customerId!);
    final balance = customer == null ? null : store.balanceOf(customer.id);
    final paid = sale.kind == SaleKind.pagada;
    final open = store.openSession;
    // Se cancela una venta de un turno abierto (también de otro celular); devolver una parte solo en el
    // turno de este celular, porque la venta nueva entra a esta caja.
    final canCancel =
        !sale.cancelled &&
        store.sessionIsOpen(sale.sessionId) &&
        (ref.watch(permissionsProvider).cancelSales || store.usesPins);
    final canReturn = canCancel && open != null && sale.sessionId == open.id;
    final order = sale.orderId == null ? null : store.orderById(sale.orderId!);
    final place = order == null ? null : store.orderTitle(order);
    final text = ticketText(
      place: place,
      business: store.businessName,
      sale: sale,
      customerName: customer?.name,
      newBalanceCents: balance,
      watermark: plan.limits.watermark,
    );

    void printTicket() => printHtml(
      ticketHtml(
        place: place,
        business: store.businessName,
        sale: sale,
        customerName: customer?.name,
        newBalanceCents: balance,
        watermark: plan.limits.watermark,
      ),
    );
    void newSale() => Navigator.of(context).maybePop();

    // Con teclado: Enter o Esc para la siguiente venta, P (o Ctrl+P) para imprimir.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): newSale,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): newSale,
        const SingleActivator(LogicalKeyboardKey.escape): newSale,
        if (canPrintTicket) ...{
          const SingleActivator(LogicalKeyboardKey.keyP): printTicket,
          const SingleActivator(LogicalKeyboardKey.keyP, control: true): printTicket,
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: GColors.fondo,
            surfaceTintColor: Colors.transparent,
            title: Text(
              sale.cancelled ? 'Venta cancelada' : (paid ? 'Venta cobrada' : 'Venta fiada'),
              style: GText.sans(size: 17, weight: FontWeight.w800),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: RepaintBoundary(
                      key: _ticketKey,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        decoration: BoxDecoration(
                          color: GColors.superficie,
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
                                  'Folio ${sale.folioLabel} · ${dateTimeLabel(sale.createdAt)}',
                                  textAlign: TextAlign.center,
                                  style: GText.mono(size: 11, color: GColors.tintaSuave),
                                ),
                                if (place != null)
                                  Text(
                                    place,
                                    textAlign: TextAlign.center,
                                    style: GText.mono(size: 12, weight: FontWeight.w700),
                                  ),
                                if (sale.clerk != null)
                                  Text(
                                    'Te atendió: ${sale.clerk}',
                                    textAlign: TextAlign.center,
                                    style: GText.mono(size: 11, color: GColors.tintaSuave),
                                  ),
                                const SizedBox(height: 10),
                                for (final l in sale.lines) _row('${qtyLabel(l.qty)} x ${l.name}', money(l.totalCents)),
                                const _Dashed(),
                                if (sale.discountCents > 0) ...[
                                  _row('Subtotal', money(sale.subtotalCents)),
                                  _row('Descuento', '-${money(sale.discountCents)}'),
                                ],
                                _row('TOTAL', money(sale.totalCents), bold: true),
                                const _Dashed(),
                                if (paid && sale.split) ...[
                                  // Pagada en partes: cada pago con su método.
                                  for (final p in sale.payments) _row(p.method.label, money(p.amountCents)),
                                  if (sale.receivedCents != null && sale.cashCents > 0) ...[
                                    _row('Recibió (efectivo)', money(sale.receivedCents!)),
                                    _row('Cambio', money(sale.changeCents)),
                                  ],
                                ] else if (paid) ...[
                                  _row('Pago', sale.method!.label),
                                  if (sale.method == PayMethod.efectivo) ...[
                                    _row('Recibió', money(sale.receivedCents ?? sale.totalCents)),
                                    _row('Cambio', money(sale.changeCents)),
                                  ],
                                ] else ...[
                                  _row('Cliente', customer?.name ?? ''),
                                  _row('Saldo pendiente', money(balance ?? 0)),
                                ],
                                if (sale.cancelled) ...[
                                  const _Dashed(),
                                  _row('CANCELADA', timeLabel(sale.cancelledAt!), bold: true),
                                  Text(sale.cancelReason ?? '', style: GText.mono(size: 11.5)),
                                ],
                                if (plan.limits.watermark) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Hecho con Gavilán',
                                    textAlign: TextAlign.center,
                                    style: GText.mono(size: 10.5, color: GColors.tintaTenue),
                                  ),
                                ],
                                // Espacio libre al pie para el sello, que así no tapa montos.
                                const SizedBox(height: 70),
                              ],
                            ),
                            Positioned(
                              right: 4,
                              bottom: 10,
                              child: _Stamp(paid: paid, cancelled: sale.cancelled),
                            ),
                          ],
                        ),
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
                        // Lo de todos los días primero: la siguiente venta.
                        GButton(
                          label: widget.fromHistory ? 'Volver' : 'Nueva venta',
                          icon: widget.fromHistory ? Icons.arrow_back_rounded : Icons.add_shopping_cart_rounded,
                          kind: GButtonKind.money,
                          expand: true,
                          big: true,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(height: 12),
                        // Mandar o imprimir el ticket: tres botones iguales.
                        Row(
                          children: [
                            Expanded(
                              child: _TicketAction(
                                icon: Icons.send_outlined,
                                label: 'WhatsApp',
                                onTap: () => shareAsImage(
                                  context,
                                  _ticketKey,
                                  fileName: 'ticket-${sale.folioLabel}.png',
                                  fallbackText: text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TicketAction(
                                icon: Icons.notes_rounded,
                                label: 'Como texto',
                                onTap: () => shareText(context, text),
                              ),
                            ),
                            if (canPrintTicket) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _TicketAction(icon: Icons.print_outlined, label: 'Imprimir', onTap: printTicket),
                              ),
                            ],
                          ],
                        ),
                        // Corregir la venta, al final y aparte.
                        if (canCancel) ...[
                          const SizedBox(height: 18),
                          Container(
                            decoration: GShape.card(),
                            clipBehavior: Clip.antiAlias,
                            child: Material(
                              type: MaterialType.transparency,
                              child: Column(
                                children: [
                                  if (canReturn && (sale.lines.length > 1 || sale.lines.any((l) => l.qty > 1))) ...[
                                    _FixRow(
                                      icon: Icons.assignment_return_outlined,
                                      label: 'Devolver algunos productos',
                                      color: GColors.tinta,
                                      onTap: () => _returnItems(sale),
                                    ),
                                    const Divider(height: 1, indent: 50, color: GColors.linea),
                                  ],
                                  _FixRow(
                                    icon: Icons.undo_rounded,
                                    label: 'Cancelar esta venta',
                                    color: GColors.rojo,
                                    onTap: () => _confirmCancel(sale, customer?.name),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (canPrintTicket)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              widget.fromHistory ? 'Enter: volver · P: imprimir' : 'Enter: nueva venta · P: imprimir',
                              textAlign: TextAlign.center,
                              style: GText.muted(size: 12),
                            ),
                          ),
                      ],
                    ),
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
  const _Stamp({required this.paid, this.cancelled = false});

  final bool paid;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final color = cancelled ? GColors.tintaSuave : (paid ? GColors.cenote : GColors.rojo);
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
          cancelled ? 'CANCELADA' : (paid ? 'PAGADO' : 'FIADO'),
          style: GText.sans(size: 24, weight: FontWeight.w800, color: color).copyWith(letterSpacing: 2),
        ),
      ),
    );
  }
}

/// Pregunta por qué se cancela la venta y explica qué va a pasar. Devuelve el motivo, o null si no se cancela.
Future<String?> showCancelSaleDialog(BuildContext context, Sale sale, {String? customerName}) {
  const reasons = ['Se cobró mal', 'El cliente se arrepintió', 'Producto en mal estado', 'Otro'];
  var picked = reasons.first;
  final total = money(sale.totalCents);
  final effect = switch ((sale.kind, sale.method)) {
    (SaleKind.fiada, _) => 'Se le quitan $total de la deuda${customerName == null ? '' : ' a $customerName'}.',
    _ when sale.split =>
      'Devuélvele lo que pagó: ${[for (final p in sale.payments) '${money(p.amountCents)} en ${p.method.label.toLowerCase()}'].join(', ')}.',
    (_, PayMethod.efectivo) => 'Devuélvele $total al cliente: ya no cuentan en la caja.',
    (_, final m) => 'Devuélvele $total por ${m?.label.toLowerCase() ?? 'el mismo medio'}. La app solo lo anota.',
  };
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('¿Cancelar la venta ${sale.folioLabel}?', style: GText.sans(size: 18, weight: FontWeight.w800)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¿Por qué?', style: GText.sans(size: 13, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in reasons)
                    GChip(label: r, selected: picked == r, onTap: () => setState(() => picked = r)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GColors.rojoSuave,
                  borderRadius: BorderRadius.circular(GShape.radiusSmall),
                ),
                child: Text(
                  '$effect Lo vendido regresa al inventario.',
                  style: GText.sans(size: 13.5, weight: FontWeight.w600, color: GColors.rojo),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('No, dejarla')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(picked),
            child: Text(
              'Sí, cancelar',
              style: GText.sans(size: 14, weight: FontWeight.w800, color: GColors.rojo),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Botón para mandar o imprimir el ticket: los tres iguales, con su icono arriba.
class _TicketAction extends StatelessWidget {
  const _TicketAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.96,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: GColors.superficie,
            borderRadius: BorderRadius.circular(GShape.radius),
            border: Border.all(color: GColors.linea, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: GColors.cenote),
              const SizedBox(height: 5),
              Text(label, style: GText.sans(size: 13, weight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renglón para corregir la venta (devolver o cancelar).
class _FixRow extends StatelessWidget {
  const _FixRow({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color == GColors.tinta ? GColors.tintaSuave : color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GText.sans(size: 14.5, weight: FontWeight.w700, color: color),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: GColors.tintaTenue),
          ],
        ),
      ),
    );
  }
}
