/// El dinero se guarda en centavos (int) para evitar errores de redondeo.
String money(int cents, {bool hideZeroCents = false}) {
  final negative = cents < 0;
  final abs = cents.abs();
  final pesos = abs ~/ 100;
  final cts = abs % 100;
  final digits = pesos.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final centsPart = (hideZeroCents && cts == 0) ? '' : '.${cts.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}\$$buf$centsPart';
}

/// Convierte lo que escribe el usuario ("45", "45.5", "1,200.00") a centavos.
int? parseMoney(String input) {
  final clean = input.replaceAll(',', '').replaceAll('\$', '').trim();
  if (clean.isEmpty) return null;
  final value = double.tryParse(clean);
  if (value == null || value < 0) return null;
  return (value * 100).round();
}

String qtyLabel(double qty) => qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(2);

String daysAgo(DateTime date, DateTime now) {
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (days <= 0) return 'hoy';
  if (days == 1) return 'ayer';
  return 'hace $days días';
}
