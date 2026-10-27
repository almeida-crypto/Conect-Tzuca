import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/core/money.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/state/store.dart';

void main() {
  late ProviderContainer container;
  StoreNotifier store() => container.read(storeProvider.notifier);
  StoreState state() => container.read(storeProvider);
  CashSummary summary() => state().summaryFor(state().openSession!);

  SaleLine line(String productId, double qty) {
    final p = state().productById(productId)!;
    return SaleLine(key: p.id, productId: p.id, name: p.name, unitCents: p.priceCents, qty: qty);
  }

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('los datos de ejemplo cuadran con el corte esperado', () {
    final s = summary();
    // Fondo 500 + efectivo (66+36+12) + abono 50 - gastos (80+100)
    expect(s.openingCents, 50000);
    expect(s.cashSalesCents, 11400);
    expect(s.cashAbonosCents, 5000);
    expect(s.gastosCents, 18000);
    expect(s.expectedCashCents, 50000 + 11400 + 5000 - 18000);
  });

  test('venta en efectivo suma a caja, guarda cambio y descuenta inventario', () {
    final before = summary().expectedCashCents;
    final stock = state().productById('p1')!.stock;
    final sale = store().checkout(
      lines: [line('p1', 2)],
      kind: SaleKind.pagada,
      method: PayMethod.efectivo,
      receivedCents: 5000,
    );
    expect(sale.totalCents, 3600);
    expect(sale.changeCents, 1400);
    expect(summary().expectedCashCents, before + 3600);
    expect(state().productById('p1')!.stock, stock - 2);
    expect(state().nextFolio, sale.folio + 1);
  });

  test('venta con tarjeta no suma al efectivo esperado', () {
    final before = summary();
    store().checkout(lines: [line('p6', 1)], kind: SaleKind.pagada, method: PayMethod.tarjeta);
    expect(summary().expectedCashCents, before.expectedCashCents);
    expect(summary().otherSalesCents, before.otherSalesCents + 1200);
  });

  test('venta fiada carga la deuda y no entra a caja; el abono en efectivo sí', () {
    final c = store().addCustomer('Don Chucho');
    final cashBefore = summary().expectedCashCents;
    store().checkout(lines: [line('p3', 1)], kind: SaleKind.fiada, customerId: c.id);
    expect(state().balanceOf(c.id), 4200);
    expect(summary().expectedCashCents, cashBefore);
    expect(summary().creditSalesCents, 4200);

    store().addAbono(c.id, 2000, PayMethod.efectivo);
    expect(state().balanceOf(c.id), 2200);
    expect(summary().expectedCashCents, cashBefore + 2000);
    expect(state().debtors.any((d) => d.customer.id == c.id), isTrue);
  });

  test('gastos restan y el cierre guarda lo esperado contra lo contado', () {
    final before = summary().expectedCashCents;
    store().addMovement(CashKind.gasto, 2500, 'Bolsas');
    expect(summary().expectedCashCents, before - 2500);

    final closed = store().closeCash(before - 2500 - 100);
    expect(closed!.differenceCents, -100);
    expect(state().openSession, isNull);

    store().openCash(30000);
    expect(state().openSession!.openingCents, 30000);
    expect(summary().expectedCashCents, 30000);
  });

  test('formato y lectura de dinero', () {
    expect(money(123456), '\$1,234.56');
    expect(money(5000, hideZeroCents: true), '\$50');
    expect(parseMoney('1,200.50'), 120050);
    expect(parseMoney('abc'), isNull);
  });
}
