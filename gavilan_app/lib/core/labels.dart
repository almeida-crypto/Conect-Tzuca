import 'dart:math';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/models.dart';
import 'money.dart';

/// Tamaño de las etiquetas.
enum LabelFormat {
  /// Hoja carta con 30 etiquetas de 66.7×25.4 mm (3 columnas, 10 renglones), como las de papelería.
  /// Los márgenes van unas décimas más chicos que la hoja de papelería para que las 3 columnas quepan.
  carta('Hoja carta', '30 por hoja, de papelería'),

  /// Rollo de etiquetas de 50×25 mm para impresora térmica: una por página.
  rollo('Rollo 50×25 mm', 'Impresora de etiquetas');

  const LabelFormat(this.label, this.caption);
  final String label;
  final String caption;
}

/// Cifra de control de un EAN-13 a partir de sus primeras 12 cifras.
int ean13CheckDigit(String twelve) {
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(twelve[i]) * (i.isEven ? 1 : 3);
  }
  return (10 - sum % 10) % 10;
}

/// Un EAN-13 válido (13 cifras con su cifra de control correcta).
bool isEan13(String code) =>
    RegExp(r'^\d{13}$').hasMatch(code) && ean13CheckDigit(code.substring(0, 12)) == int.parse(code[12]);

/// Código para un producto que no trae: EAN-13 que empieza con "20", el rango que los fabricantes dejan
/// para uso interno de cada tienda (nunca choca con un producto de marca). No repite ninguno de [taken].
String newInternalCode(Set<String> taken, {Random? random}) {
  final rng = random ?? Random.secure();
  while (true) {
    final body = '20${List.generate(10, (_) => rng.nextInt(10)).join()}';
    final code = '$body${ean13CheckDigit(body)}';
    if (!taken.contains(code)) return code;
  }
}

/// Barras que corresponden al código: EAN-13, EAN-8 o UPC-A si lo es; si no, Code 128 (acepta letras).
pw.Barcode barcodeFor(String code) {
  if (isEan13(code)) return pw.Barcode.ean13();
  if (RegExp(r'^\d{8}$').hasMatch(code)) return pw.Barcode.ean8();
  if (RegExp(r'^\d{12}$').hasMatch(code) && ean13CheckDigit('0$code'.substring(0, 12)) == int.parse(code[11])) {
    return pw.Barcode.upcA();
  }
  return pw.Barcode.code128();
}

/// La letra del PDF solo trae letras latinas (con acentos y ñ): lo demás (emojis) se quita.
String _latin(String s) => String.fromCharCodes(s.runes.where((r) => r < 0x100)).trim();

const _mm = PdfPageFormat.mm;

/// PDF con las etiquetas: [items] es cada producto con cuántas etiquetas lleva. Todos deben tener código.
Future<Uint8List> labelsPdf({required List<(Product, int)> items, required LabelFormat format, bool showPrice = true}) {
  final labels = [
    for (final (p, n) in items)
      for (var i = 0; i < n; i++) p,
  ];
  final doc = pw.Document(title: 'Etiquetas', author: 'Gavilán');
  switch (format) {
    case LabelFormat.carta:
      const perPage = 30;
      for (var start = 0; start < labels.length; start += perPage) {
        final page = labels.sublist(start, min(start + perPage, labels.length));
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.letter.copyWith(
              marginLeft: 4.6 * _mm,
              marginRight: 4.6 * _mm,
              marginTop: 12.7 * _mm,
              marginBottom: 0,
            ),
            build: (_) => pw.Wrap(
              spacing: 3.1 * _mm,
              children: [
                for (final p in page)
                  pw.SizedBox(width: 66.7 * _mm, height: 25.4 * _mm, child: _label(p, showPrice, big: true)),
              ],
            ),
          ),
        );
      }
    case LabelFormat.rollo:
      for (final p in labels) {
        doc.addPage(
          pw.Page(
            pageFormat: const PdfPageFormat(50 * _mm, 25 * _mm, marginAll: 1.5 * _mm),
            build: (_) => _label(p, showPrice, big: false),
          ),
        );
      }
  }
  return doc.save();
}

pw.Widget _label(Product p, bool showPrice, {required bool big}) {
  final code = p.barcode!;
  return pw.Padding(
    padding: pw.EdgeInsets.symmetric(horizontal: (big ? 3 : 0.5) * _mm, vertical: (big ? 1.6 : 0.3) * _mm),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                _latin(p.name),
                maxLines: 2,
                style: pw.TextStyle(fontSize: big ? 7.5 : 7, fontWeight: pw.FontWeight.bold, lineSpacing: -1),
              ),
            ),
            if (showPrice) ...[
              pw.SizedBox(width: 2 * _mm),
              pw.Text(
                money(p.priceCents),
                style: pw.TextStyle(fontSize: big ? 11 : 10, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ],
        ),
        pw.SizedBox(height: 0.8 * _mm),
        pw.Expanded(
          child: pw.BarcodeWidget(
            barcode: barcodeFor(code),
            data: code,
            drawText: true,
            textStyle: const pw.TextStyle(fontSize: 7),
          ),
        ),
      ],
    ),
  );
}
