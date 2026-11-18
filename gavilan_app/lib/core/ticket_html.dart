import '../domain/models.dart';
import '../domain/restaurant.dart';
import 'money.dart';
import 'ticket_text.dart';

/// Ticket en HTML para imprimir desde el navegador. Cabe en rollos de 58 y 80 mm y también se ve
/// bien en una hoja carta.
String ticketHtml({
  required String business,
  required Sale sale,
  String? customerName,
  int? newBalanceCents,
  bool watermark = false,
  String? place,
}) {
  final paid = sale.kind == SaleKind.pagada;
  final rows = StringBuffer();
  void row(String a, String b, {bool strong = false}) =>
      rows.writeln('<tr${strong ? ' class="strong"' : ''}><td>${_esc(a)}</td><td class="r">${_esc(b)}</td></tr>');

  for (final l in sale.lines) {
    row('${qtyLabel(l.qty)} x ${l.name}', money(l.totalCents));
  }
  rows.writeln('<tr class="sep"><td colspan="2"></td></tr>');
  if (sale.discountCents > 0) {
    row('Subtotal', money(sale.subtotalCents));
    row('Descuento', '-${money(sale.discountCents)}');
  }
  row('TOTAL', money(sale.totalCents), strong: true);
  rows.writeln('<tr class="sep"><td colspan="2"></td></tr>');
  if (paid && sale.split) {
    for (final p in sale.payments) {
      row(p.method.label, money(p.amountCents));
    }
    if (sale.receivedCents != null && sale.cashCents > 0) {
      row('Recibió (efectivo)', money(sale.receivedCents!));
      row('Cambio', money(sale.changeCents));
    }
  } else if (paid) {
    row('Pago', sale.method!.label);
    if (sale.method == PayMethod.efectivo) {
      row('Recibió', money(sale.receivedCents ?? sale.totalCents));
      row('Cambio', money(sale.changeCents));
    }
  } else {
    row('Cliente', customerName ?? '');
    row('Saldo pendiente', money(newBalanceCents ?? 0));
  }

  return '''<!doctype html>
<html lang="es"><head><meta charset="utf-8"><title>Ticket ${_esc(sale.folioLabel)}</title>
<style>
  @page { margin: 3mm; }
  * { box-sizing: border-box; }
  body { margin: 0; font: 12px/1.35 "Courier New", ui-monospace, monospace; color: #000; }
  .t { width: 100%; max-width: 72mm; margin: 0 auto; }
  h1 { font-size: 14px; text-align: center; letter-spacing: 1px; margin: 0 0 2px; text-transform: uppercase; }
  .sub { text-align: center; font-size: 11px; margin-bottom: 8px; }
  table { width: 100%; border-collapse: collapse; }
  td { padding: 1px 0; vertical-align: top; }
  td.r { text-align: right; white-space: nowrap; padding-left: 8px; }
  tr.strong td { font-weight: 700; font-size: 14px; }
  tr.sep td { border-top: 1px dashed #000; padding: 3px 0 0; }
  .sello { text-align: center; font: 700 16px/1 Arial, sans-serif; letter-spacing: 2px; border: 2px solid #000;
           padding: 4px 0; margin: 10px auto 0; width: 60%; }
  .pie { text-align: center; font-size: 10px; margin-top: 8px; }
</style></head>
<body><div class="t">
<h1>${_esc(business)}</h1>
<div class="sub">Folio ${_esc(sale.folioLabel)} · ${_esc(dateTimeLabel(sale.createdAt))}${place == null ? '' : '<br>${_esc(place)}'}${sale.clerk == null ? '' : '<br>Te atendió: ${_esc(sale.clerk!)}'}</div>
<table>
$rows</table>
<div class="sello">${sale.cancelled ? 'CANCELADA' : (paid ? 'PAGADO' : 'FIADO')}</div>
${sale.cancelled ? '<div class="pie">${_esc(sale.cancelReason ?? '')}</div>' : ''}
<div class="pie">¡Gracias por su compra!</div>
${watermark ? '<div class="pie">Hecho con Gavilán</div>' : ''}
</div></body></html>''';
}

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// Comanda para la cocina: la mesa en grande, la hora y los platillos con sus extras e indicaciones.
/// Sin precios (a la cocina no le sirven).
String comandaHtml({required String business, required String place, required List<OrderItem> items, DateTime? at}) {
  final rows = StringBuffer();
  for (final i in items) {
    rows.writeln('<div class="it"><span class="q">${_esc(qtyLabel(i.qty))}</span> ${_esc(i.name)}</div>');
    for (final e in i.extras) {
      rows.writeln('<div class="ex">+ ${_esc(e.name)}</div>');
    }
    if (i.notes != null && i.notes!.trim().isNotEmpty) {
      rows.writeln('<div class="nt">** ${_esc(i.notes!)} **</div>');
    }
  }
  final when = at ?? items.map((i) => i.sentAt ?? i.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
  return '''<!doctype html>
<html lang="es"><head><meta charset="utf-8"><title>Comanda ${_esc(place)}</title>
<style>
  @page { margin: 3mm; }
  * { box-sizing: border-box; }
  body { margin: 0; font: 14px/1.35 "Courier New", ui-monospace, monospace; color: #000; }
  .t { width: 100%; max-width: 72mm; margin: 0 auto; }
  .neg { text-align: center; font-size: 11px; }
  h1 { font: 700 26px/1.1 Arial, sans-serif; text-align: center; margin: 4px 0 2px; text-transform: uppercase; }
  .hora { text-align: center; font-size: 13px; margin-bottom: 8px; border-bottom: 2px dashed #000; padding-bottom: 6px; }
  .it { font-size: 17px; font-weight: 700; margin-top: 8px; }
  .q { display: inline-block; min-width: 28px; }
  .ex { font-size: 14px; margin-left: 28px; }
  .nt { font-size: 15px; font-weight: 700; margin-left: 28px; text-transform: uppercase; }
  .pie { border-top: 2px dashed #000; margin-top: 10px; padding-top: 4px; text-align: center; font-size: 11px; }
</style></head>
<body><div class="t">
<div class="neg">${_esc(business)}</div>
<h1>${_esc(place)}</h1>
<div class="hora">Comanda · ${_esc(timeLabel(when))}</div>
$rows<div class="pie">${items.length == 1 ? '1 platillo' : '${items.length} platillos'}</div>
</div></body></html>''';
}
