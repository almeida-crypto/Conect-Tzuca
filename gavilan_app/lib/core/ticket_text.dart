import '../domain/models.dart';
import 'money.dart';

String two(int n) => n.toString().padLeft(2, '0');
String dateTimeLabel(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
String timeLabel(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// Texto del ticket para mandar por WhatsApp. (La versión en imagen PNG viene después.)
String ticketText({
  required String business,
  required Sale sale,
  String? customerName,
  int? newBalanceCents,
  bool watermark = false,
}) {
  final b = StringBuffer()
    ..writeln('*$business*')
    ..writeln('Folio A-${sale.folio.toString().padLeft(4, '0')} · ${dateTimeLabel(sale.createdAt)}')
    ..writeln('');
  for (final l in sale.lines) {
    b.writeln('${qtyLabel(l.qty)} x ${l.name}  ${money(l.totalCents)}');
  }
  b
    ..writeln('')
    ..writeln('*TOTAL ${money(sale.totalCents)}*');
  if (sale.kind == SaleKind.pagada) {
    b.writeln('Pagado con ${sale.method!.label.toLowerCase()}');
    if (sale.method == PayMethod.efectivo && sale.receivedCents != null) {
      b.writeln('Recibido ${money(sale.receivedCents!)} · Cambio ${money(sale.changeCents)}');
    }
  } else {
    b.writeln('A cuenta de ${customerName ?? 'cliente'}');
    if (newBalanceCents != null) b.writeln('Saldo pendiente: ${money(newBalanceCents)}');
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
