import '../domain/models.dart';
import 'money.dart';

String two(int n) => n.toString().padLeft(2, '0');
String dateTimeLabel(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
String timeLabel(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String dayLabel(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

/// Texto del ticket para mandar por WhatsApp. (La versión en imagen PNG viene después.)
String ticketText({
  required String business,
  required Sale sale,
  String? customerName,
  int? newBalanceCents,
  bool watermark = false,
  String? place,
  List<SaleReturn> returns = const [],
  ({String folio, int cents})? exchange,
}) {
  final b = StringBuffer()
    ..writeln('*$business*')
    ..writeln('Folio ${sale.folioLabel} · ${dateTimeLabel(sale.createdAt)}');
  if (place != null) b.writeln(place);
  if (sale.clerk != null) b.writeln('Te atendió: ${sale.clerk}');
  b.writeln('');
  for (final l in sale.lines) {
    b.writeln('${qtyLabel(l.qty)} x ${l.name}  ${money(l.totalCents)}');
  }
  b.writeln('');
  if (sale.discountCents > 0) {
    b.writeln('Subtotal ${money(sale.subtotalCents)} · Descuento -${money(sale.discountCents)}');
  }
  b.writeln('*TOTAL ${money(sale.totalCents)}*');
  if (sale.tipCents > 0) b.writeln('Propina ${money(sale.tipCents)} · Total pagado ${money(sale.paidCents)}');
  if (sale.kind == SaleKind.pagada && exchange != null) {
    // Cambio: lo que regresó pagó parte; solo se pagó la diferencia.
    final diff = sale.totalCents - exchange.cents;
    b.writeln('Regresó (venta ${exchange.folio}) -${money(exchange.cents)}');
    if (diff > 0) {
      b.writeln(
        'Pagó la diferencia ${money(diff)} con ${(sale.split ? sale.payments.last.method : sale.method ?? PayMethod.efectivo).label.toLowerCase()}',
      );
    } else if (diff < 0) {
      b.writeln('Se le devolvió ${money(-diff)}');
    }
  } else if (sale.kind == SaleKind.pagada && sale.split) {
    b.writeln('Pagado: ${[for (final p in sale.payments) '${p.method.label} ${money(p.amountCents)}'].join(' · ')}');
    if (sale.receivedCents != null && sale.cashCents > 0) {
      b.writeln('Recibido en efectivo ${money(sale.receivedCents!)} · Cambio ${money(sale.changeCents)}');
    }
  } else if (sale.kind == SaleKind.pagada) {
    b.writeln('Pagado con ${sale.method!.label.toLowerCase()}');
    if (sale.method == PayMethod.efectivo && sale.receivedCents != null) {
      b.writeln('Recibido ${money(sale.receivedCents!)} · Cambio ${money(sale.changeCents)}');
    }
  } else {
    b.writeln('A cuenta de ${customerName ?? 'cliente'}');
    if (newBalanceCents != null) b.writeln('Saldo pendiente: ${money(newBalanceCents)}');
  }
  if (returns.isNotEmpty) b.writeln('');
  for (final r in returns) {
    b.writeln(
      '${r.isExchange ? 'Cambio' : 'Devolución'} ${dayLabel(r.createdAt)}: ${r.summary}  -${money(r.amountCents)}',
    );
  }
  if (sale.cancelled) {
    b
      ..writeln('')
      ..writeln('*VENTA CANCELADA* (${sale.cancelReason ?? ''})');
  }
  if (watermark) {
    b
      ..writeln('')
      ..writeln('Hecho con Gavilán');
  }
  return b.toString().trimRight();
}

/// Recordatorio amable de deuda.
String reminderText({required String business, required String name, required int balanceCents}) =>
    'Hola, $name. Le saluda $business. Le compartimos su saldo pendiente: ${money(balanceCents)}. '
    'Cuando guste puede pasar a abonar. ¡Gracias por su preferencia!';
