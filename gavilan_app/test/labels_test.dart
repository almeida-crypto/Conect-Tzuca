import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/core/labels.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';
import 'package:pdf/widgets.dart' as pw;

/// Etiquetas con código de barras.
void main() {
  test('cifra de control del EAN-13', () {
    expect(ean13CheckDigit('750105530007'), 5); // Coca-Cola 600 ml
    expect(isEan13('7501055300075'), isTrue);
    expect(isEan13('7501055300076'), isFalse);
    expect(isEan13('75010553'), isFalse);
  });

  test('el código interno empieza con 20, es un EAN-13 válido y no repite', () {
    final rng = Random(1);
    final first = newInternalCode({}, random: Random(1));
    final again = newInternalCode({first}, random: rng);
    expect(first, startsWith('20'));
    expect(isEan13(first), isTrue);
    expect(again, isNot(first));
    expect(isEan13(again), isTrue);
  });

  test('cada código con sus barras: EAN-13, EAN-8, UPC-A o Code 128', () {
    expect(barcodeFor('7501055300075').name, pw.Barcode.ean13().name);
    expect(barcodeFor('96385074').name, pw.Barcode.ean8().name);
    expect(barcodeFor('036000291452').name, pw.Barcode.upcA().name);
    expect(barcodeFor('PACA-12').name, pw.Barcode.code128().name);
  });

  test('a los productos sin código se les crea uno y se guarda', () {
    final app = ProviderContainer(
      overrides: [
        initialDataProvider.overrideWithValue(LoadedData(store: seedStore(DateTime.now()), plan: Plan.negocio)),
      ],
    );
    addTearDown(app.dispose);
    final n = app.read(storeProvider.notifier);
    n.saveProduct(const Product(id: 'x', name: 'Blusa de paca', priceCents: 8000));
    n.saveProduct(const Product(id: 'y', name: 'Falda', priceCents: 9000));
    final coca = app.read(storeProvider).products.firstWhere((p) => (p.barcode ?? '').isNotEmpty);
    n.giveCodes(['x', 'y', coca.id]);
    final s = app.read(storeProvider);
    final x = s.productById('x')!.barcode!, y = s.productById('y')!.barcode!;
    expect(isEan13(x) && x.startsWith('20'), isTrue);
    expect(isEan13(y) && y.startsWith('20'), isTrue);
    expect(x, isNot(y));
    expect(s.productById(coca.id)!.barcode, coca.barcode); // el que ya traía no cambia
  });

  test('el PDF sale en hoja carta y en rollo, con acentos y sin romperse con emojis', () async {
    const p = Product(id: 'a', name: 'Piñata de cumpleaños 🎉 grande', priceCents: 15000, barcode: '7501055300075');
    const q = Product(id: 'b', name: 'Paca', priceCents: 2000, barcode: 'PACA-12');
    for (final f in LabelFormat.values) {
      final pdf = await labelsPdf(items: [(p, 31), (q, 2)], format: f);
      expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
    }
  });
}
