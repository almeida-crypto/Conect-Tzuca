import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/ui/scan/scan_session.dart';

void main() {
  const coca = Product(id: 'coca', name: 'Coca', priceCents: 1800, barcode: '7501055300075');
  const agua = Product(id: 'agua', name: 'Agua', priceCents: 1200, barcode: '7501086801046');
  final catalog = {coca.barcode!: coca, agua.barcode!: agua};
  final t0 = DateTime(2026, 10, 31, 10);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  late List<Product> cart;
  late ScanSession session;

  setUp(() {
    cart = [];
    session = ScanSession(lookup: (c) => catalog[c], onFound: cart.add);
  });

  test('un código conocido se suma a la cuenta', () {
    final r = session.handle('7501055300075', at(0));
    expect(r, isA<ScanFound>());
    expect((r as ScanFound).product.name, 'Coca');
    expect(r.added, isTrue);
    expect(cart, [coca]);
  });

  test('el mismo código frente a la cámara se cuenta una sola vez', () {
    for (var ms = 0; ms < 3000; ms += 100) {
      session.handle('7501055300075', at(ms));
    }
    expect(cart, hasLength(1));
  });

  test('si se retira y se vuelve a acercar, cuenta otra vez', () {
    session.handle('7501055300075', at(0));
    session.handle('7501055300075', at(1500));
    expect(cart, hasLength(2));
  });

  test('alternar dos productos cuenta cada uno', () {
    session.handle('7501055300075', at(0));
    session.handle('7501086801046', at(300));
    session.handle('7501055300075', at(600));
    expect(cart, [coca, agua, coca]);
  });

  test('un código desconocido no toca la cuenta', () {
    final r = session.handle('0000', at(0));
    expect(r, isA<ScanUnknown>());
    expect(r.code, '0000');
    expect(cart, isEmpty);
  });

  test('quita espacios del código leído', () {
    expect(session.handle(' 7501055300075\n', at(0)), isA<ScanFound>());
  });

  test('en modo precio no se agrega nada', () {
    final priceOnly = ScanSession(lookup: (c) => catalog[c]);
    final r = priceOnly.handle('7501086801046', at(0));
    expect((r as ScanFound).added, isFalse);
    expect(r.product.priceCents, 1200);
  });

  test('después de reiniciar, el mismo código cuenta de inmediato', () {
    session.handle('7501055300075', at(0));
    session.reset();
    session.handle('7501055300075', at(100));
    expect(cart, hasLength(2));
  });
}
