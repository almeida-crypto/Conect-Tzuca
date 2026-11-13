import 'package:flutter/services.dart';

/// Límites para que no entren números irreales, ya sea por un dedo de más o a propósito.
/// Son amplios para cualquier negocio de la región, pero cortan cifras que romperían la caja.
abstract final class Limits {
  /// $999,999.99: precio, costo, pago, gasto o fondo de caja.
  static const maxMoneyCents = 99999999;
  static const maxMoneyDigits = 6;

  /// 99,999: existencias, mínimos y mercancía que llega (piezas o kilos).
  static const maxQty = 99999.0;
  static const maxQtyDigits = 5;

  /// Cuántas piezas de un mismo producto caben en una cuenta.
  static const maxCartQty = 9999.0;

  static const maxNameLength = 60;
  static const maxPersonLength = 50;
  static const maxBarcodeLength = 32;
  static const maxNoteLength = 120;
}

/// Solo deja escribir dinero razonable: cifras, un punto, hasta 2 decimales y 6 cifras antes del punto.
/// Las comas de miles se aceptan al escribir ("1,200") pero no cuentan como cifras.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter();

  static final _allowed = RegExp(r'^\$?[\d,]*\.?\d{0,2}$');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.trim();
    if (text.isEmpty) return newValue;
    if (!_allowed.hasMatch(text)) return oldValue;
    final whole = text.replaceAll(RegExp(r'[\$,]'), '').split('.').first;
    if (whole.length > Limits.maxMoneyDigits) return oldValue;
    return newValue;
  }
}

/// Cantidades: cifras, un punto, hasta 3 decimales (kilos) y 5 cifras antes del punto.
class QtyInputFormatter extends TextInputFormatter {
  const QtyInputFormatter({this.allowNegative = false});

  /// En la tabla del catálogo una existencia puede quedar negativa (se vendió sin capturar la compra).
  final bool allowNegative;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.trim();
    if (text.isEmpty || (allowNegative && text == '-')) return newValue;
    final pattern = allowNegative ? RegExp(r'^-?\d*\.?\d{0,3}$') : RegExp(r'^\d*\.?\d{0,3}$');
    if (!pattern.hasMatch(text)) return oldValue;
    final whole = text.replaceAll('-', '').split('.').first;
    if (whole.length > Limits.maxQtyDigits) return oldValue;
    return newValue;
  }
}

/// Convierte lo escrito a cantidad. Null si no es un número, es negativo o pasa de [Limits.maxQty].
double? parseQty(String input, {bool allowNegative = false}) {
  final value = double.tryParse(input.trim());
  if (value == null || value.isNaN || value.isInfinite) return null;
  if (!allowNegative && value < 0) return null;
  if (value.abs() > Limits.maxQty) return null;
  return value;
}

/// Mensaje para un monto que se pasa del límite (o null si está bien o vacío).
String? moneyTooBig(String input) {
  final clean = input.replaceAll(RegExp(r'[\$,\s]'), '');
  final value = double.tryParse(clean);
  if (value == null) return null;
  return value * 100 > Limits.maxMoneyCents ? 'Máximo \$999,999.99' : null;
}

/// Nombres y textos: corta en [max] letras al escribir o pegar.
LengthLimitingTextInputFormatter maxChars(int max) => LengthLimitingTextInputFormatter(max);
