import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/core/limits.dart';
import 'package:gavilan/core/money.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/state/app_state.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';

/// Que no entren números irreales.
void main() {
  String type(TextInputFormatter f, String old, String next) =>
      f.formatEditUpdate(TextEditingValue(text: old), TextEditingValue(text: next)).text;

  test('dinero: hasta \$999,999.99', () {
    expect(parseMoney('999999.99'), 99999999);
    expect(parseMoney('1000000'), isNull);
    expect(parseMoney('92233720368547758.07'), isNull); // lo que entró en el celular del amigo
    expect(parseMoney('1e300'), isNull);
    expect(parseMoney('-5'), isNull);
    expect(moneyTooBig('2000000'), 'Máximo \$999,999.99');
    expect(moneyTooBig('18'), isNull);
  });

  test('al escribir dinero no pasa de 6 cifras ni de 2 decimales', () {
    const f = MoneyInputFormatter();
    expect(type(f, '99999', '999999'), '999999');
    expect(type(f, '999999', '9999999'), '999999');
    expect(type(f, '18.5', '18.50'), '18.50');
    expect(type(f, '18.50', '18.505'), '18.50');
    expect(type(f, '18', '18a'), '18');
    expect(type(f, '1,20', '1,200'), '1,200');
  });

  test('cantidades: hasta 99,999 con 3 decimales', () {
    const f = QtyInputFormatter();
    expect(type(f, '9999', '99999'), '99999');
    expect(type(f, '99999', '999999'), '99999');
    expect(type(f, '1.25', '1.250'), '1.250');
    expect(type(f, '1.250', '1.2505'), '1.250');
    expect(type(f, '', '-'), '');
    expect(parseQty('99999'), 99999);
    expect(parseQty('100000'), isNull);
    expect(parseQty('-3'), isNull);
    expect(parseQty('-3', allowNegative: true), -3);
  });

  test('en la cuenta un producto no pasa de 9,999 piezas', () {
    final app = ProviderContainer(
      overrides: [
        initialDataProvider.overrideWithValue(LoadedData(store: seedStore(DateTime.now()), plan: Plan.negocio)),
      ],
    );
    addTearDown(app.dispose);
    final coca = app.read(storeProvider).products.first;
    final cart = app.read(cartProvider.notifier)..addProduct(coca);
    cart.setQty(coca.id, 1e15);
    expect(app.read(cartProvider).single.qty, Limits.maxCartQty);
    expect(app.read(cartProvider).single, isA<SaleLine>());
  });
}
