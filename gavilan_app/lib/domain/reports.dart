// Reportes del negocio: ventas por periodo, por día u hora, por forma de pago, por persona y por caja,
// ganancia por producto y descargas para Excel. Funciones puras: no saben de pantallas ni de la base.
import 'models.dart';
import 'profit.dart';

enum PeriodKey { hoy, ayer, semana, mes, mesPasado, rango }

/// Del día [from] (a medianoche) hasta antes de [to].
class ReportPeriod {
  const ReportPeriod(this.from, this.to, this.label);

  final DateTime from;
  final DateTime to;
  final String label;

  bool contains(DateTime d) => !d.isBefore(from) && d.isBefore(to);

  /// Días que abarca (1 = un solo día).
  int get days => DateTime(to.year, to.month, to.day).difference(DateTime(from.year, from.month, from.day)).inDays;

  /// El periodo anterior del mismo largo, para comparar.
  ReportPeriod get previous {
    final len = to.difference(from);
    return ReportPeriod(from.subtract(len), from, 'Periodo anterior');
  }
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

/// "18 nov".
String shortDayLabel(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "martes 18 nov".
String longDayLabel(DateTime d) => '${_weekdays[d.weekday - 1]} ${shortDayLabel(d)}';

ReportPeriod periodFor(PeriodKey key, {DateTime? now}) {
  final today = _day(now ?? DateTime.now());
  final tomorrow = DateTime(today.year, today.month, today.day + 1);
  return switch (key) {
    PeriodKey.hoy => ReportPeriod(today, tomorrow, 'Hoy'),
    PeriodKey.ayer => ReportPeriod(DateTime(today.year, today.month, today.day - 1), today, 'Ayer'),
    PeriodKey.semana => ReportPeriod(DateTime(today.year, today.month, today.day - 6), tomorrow, 'Últimos 7 días'),
    PeriodKey.mes => ReportPeriod(DateTime(today.year, today.month), tomorrow, 'Este mes'),
    PeriodKey.mesPasado => ReportPeriod(
      DateTime(today.year, today.month - 1),
      DateTime(today.year, today.month),
      'Mes pasado',
    ),
    PeriodKey.rango => ReportPeriod(DateTime(today.year, today.month, today.day - 6), tomorrow, 'Últimos 7 días'),
  };
}

/// Del día [a] al día [b], los dos incluidos (si vienen al revés, se voltean).
ReportPeriod rangePeriod(DateTime a, DateTime b) {
  var from = _day(a), last = _day(b);
  if (last.isBefore(from)) (from, last) = (last, from);
  final to = DateTime(last.year, last.month, last.day + 1);
  final label = from == last
      ? '${shortDayLabel(from)} ${from.year}'
      : '${shortDayLabel(from)} al ${shortDayLabel(last)} ${last.year}';
  return ReportPeriod(from, to, label);
}

/// Ventas que cuentan en el periodo: sin las canceladas (su dinero se regresó).
List<Sale> salesIn(Iterable<Sale> sales, ReportPeriod p) =>
    sales.where((s) => !s.cancelled && p.contains(s.createdAt)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

List<SaleReturn> returnsIn(Iterable<SaleReturn> returns, ReportPeriod p) =>
    returns.where((r) => p.contains(r.createdAt)).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

class Totals {
  const Totals(this.cents, this.count);

  final int cents;
  final int count;

  int get averageCents => count == 0 ? 0 : (cents / count).round();
}

Totals totalsOf(Iterable<Sale> sales) => Totals(sales.fold(0, (a, s) => a + s.totalCents), sales.length);

/// Cambio contra antes, en porcentaje; null si antes no hubo ventas.
double? changePct(int now, int before) => before <= 0 ? null : (now - before) / before * 100;

/// Una barra de la gráfica: un día o una hora.
class Bucket {
  const Bucket(this.label, this.detail, this.cents, this.count);

  final String label;
  final String detail;
  final int cents;
  final int count;
}

/// Ventas por día del periodo; los días sin ventas salen en cero.
List<Bucket> byDay(List<Sale> sales, ReportPeriod p) {
  final cents = <DateTime, int>{};
  final count = <DateTime, int>{};
  for (final s in sales) {
    final d = _day(s.createdAt);
    cents[d] = (cents[d] ?? 0) + s.totalCents;
    count[d] = (count[d] ?? 0) + 1;
  }
  return [
    for (var d = _day(p.from); d.isBefore(p.to); d = DateTime(d.year, d.month, d.day + 1))
      Bucket(p.days > 14 ? '${d.day}' : shortDayLabel(d), longDayLabel(d), cents[d] ?? 0, count[d] ?? 0),
  ];
}

/// Ventas por hora (de las 7 a las 21 como mínimo, más si hubo ventas fuera de ese horario).
List<Bucket> byHour(List<Sale> sales) {
  final cents = List.filled(24, 0);
  final count = List.filled(24, 0);
  for (final s in sales) {
    cents[s.createdAt.hour] += s.totalCents;
    count[s.createdAt.hour] += 1;
  }
  var first = 7, last = 21;
  for (var h = 0; h < 24; h++) {
    if (cents[h] > 0 || count[h] > 0) {
      if (h < first) first = h;
      if (h > last) last = h;
    }
  }
  return [for (var h = first; h <= last; h++) Bucket('$h', 'De $h:00 a ${h + 1}:00', cents[h], count[h])];
}

/// Un renglón de "cuánto de lo vendido fue de aquí": forma de pago, persona o caja.
class Share {
  const Share(this.label, this.cents, this.count, this.share);

  final String label;
  final int cents;
  final int count;

  /// Parte del total (0 a 1).
  final double share;
}

List<Share> _shares(Map<String, (int, int)> map) {
  final total = map.values.fold(0, (a, v) => a + v.$1);
  return [for (final e in map.entries) Share(e.key, e.value.$1, e.value.$2, total == 0 ? 0 : e.value.$1 / total)]
    ..sort((a, b) => b.cents.compareTo(a.cents));
}

/// Por forma de pago. Una venta pagada en partes reparte su total entre sus formas; lo fiado va aparte.
/// [exchangeCredit]: por venta nueva de un cambio, lo que pagó la mercancía que regresó (no fue dinero).
/// [storeCredit]: por venta, lo que pagó el saldo a favor de un apartado cancelado.
List<Share> byMethod(
  List<Sale> sales, {
  Map<String, int> exchangeCredit = const {},
  Map<String, int> storeCredit = const {},
}) {
  final map = <String, (int, int)>{};
  void add(String k, int cents) {
    final (c, n) = map[k] ?? (0, 0);
    map[k] = (c + cents, n + 1);
  }

  for (final s in sales) {
    if (s.kind == SaleKind.fiada) {
      add('Fiado', s.totalCents);
    } else {
      // La propina no es venta: se descuenta de lo pagado (primero del efectivo, como en el corte).
      var tip = s.tipCents;
      // En un cambio, lo que regresó cuenta aparte y se descuenta primero del efectivo.
      var credit = exchangeCredit[s.id] ?? 0;
      if (credit > 0) add('Cambio de mercancía', credit.clamp(0, s.totalCents));
      final fromCredit = (storeCredit[s.id] ?? 0).clamp(0, s.totalCents);
      if (fromCredit > 0) add('Saldo a favor', fromCredit);
      credit += fromCredit;
      final parts = [...s.paymentParts]..sort((a, b) => a.method == PayMethod.efectivo ? -1 : 1);
      for (final p in parts) {
        var off = tip.clamp(0, p.amountCents);
        tip -= off;
        if (p.method == PayMethod.efectivo && credit > 0) {
          final used = credit.clamp(0, p.amountCents - off);
          credit -= used;
          off += used;
        }
        if (p.amountCents - off > 0) add(p.method.label, p.amountCents - off);
      }
    }
  }
  map.removeWhere((_, v) => v.$1 <= 0);
  return _shares(map);
}

List<Share> byGroup(List<Sale> sales, String Function(Sale) keyOf) {
  final map = <String, (int, int)>{};
  for (final s in sales) {
    final k = keyOf(s);
    final (c, n) = map[k] ?? (0, 0);
    map[k] = (c + s.totalCents, n + 1);
  }
  return _shares(map);
}

/// Por quien atendió. Vacío si nadie usa PIN (todas las ventas sin nombre).
List<Share> byClerk(List<Sale> sales) =>
    sales.any((s) => s.clerk != null) ? byGroup(sales, (s) => s.clerk ?? 'Sin PIN') : const [];

/// Por caja (cada celular o computadora). [registerOf] dice el nombre de la caja del turno de la venta.
List<Share> byRegister(List<Sale> sales, String Function(Sale) registerOf) => byGroup(sales, registerOf);

/// Propinas del periodo: total, en cuántas cuentas y por quien cobró (si se usan PIN).
({int cents, int count, List<Share> byPerson}) tipsOf(List<Sale> sales) {
  final withTip = sales.where((s) => s.tipCents > 0).toList();
  final map = <String, (int, int)>{};
  for (final s in withTip) {
    final k = s.clerk ?? 'Sin PIN';
    final (c, n) = map[k] ?? (0, 0);
    map[k] = (c + s.tipCents, n + 1);
  }
  return (
    cents: withTip.fold(0, (a, s) => a + s.tipCents),
    count: withTip.length,
    byPerson: withTip.any((s) => s.clerk != null) ? _shares(map) : const [],
  );
}

/// Ganancia de lo vendido en el periodo, por producto.
ProfitReport profitIn(List<Sale> sales) => profitOf(sales);

// ---------- Descargas (Excel abre los CSV) ----------

final _number = RegExp(r'^-?\d+(\.\d+)?$');

String _cell(Object v) {
  var s = '$v';
  // Una celda que empieza con =, +, - o @ Excel la tomaría como fórmula (menos los números negativos).
  if (RegExp(r'^[=+\-@]').hasMatch(s) && !_number.hasMatch(s)) s = "'$s";
  return RegExp(r'[",\n\r]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
}

/// CSV con BOM para que Excel respete los acentos.
String toCsv(List<String> header, List<List<Object>> rows) =>
    '﻿${[header, ...rows].map((r) => r.map(_cell).join(',')).join('\r\n')}';

String _pesos(int cents) => (cents / 100).toStringAsFixed(2);
String _two(int n) => n.toString().padLeft(2, '0');

/// "2026-11-18 14:05": Excel lo reconoce como fecha y hora.
String csvDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

String salesCsv(List<Sale> sales, String Function(Sale) registerOf) => toCsv(
  ['Fecha', 'Folio', 'Total', 'Propina', 'Forma de pago', 'Atendió', 'Caja'],
  [
    for (final s in sales)
      [
        csvDate(s.createdAt),
        s.folio,
        _pesos(s.totalCents),
        _pesos(s.tipCents),
        s.kind == SaleKind.fiada
            ? 'Fiado'
            : s.paymentParts.length == 1
            ? s.paymentParts.single.method.label
            : s.paymentParts.map((p) => '${p.method.label} ${_pesos(p.amountCents)}').join(' + '),
        s.clerk ?? '',
        registerOf(s),
      ],
  ],
);

String _qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

String productsCsv(ProfitReport report) => toCsv(
  ['Producto', 'Cantidad', 'Vendido', 'Costo', 'Ganancia', 'Margen %'],
  [
    for (final p in report.products)
      [
        p.name,
        _qty(p.qty),
        _pesos(p.soldCents),
        p.knownCost ? _pesos(p.costCents) : '',
        p.knownCost ? _pesos(p.profitCents) : '',
        p.margin == null ? '' : (p.margin! * 100).round(),
      ],
  ],
);
