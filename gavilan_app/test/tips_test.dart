import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/data/remote_mapping.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/business.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/domain/reports.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';
import 'package:gavilan/ui/caja/tips_sheet.dart';

/// Propinas: van aparte de la venta, entran al cajón si son en efectivo y salen en el corte y en Reportes.
void main() {
  late ProviderContainer app;
  late StoreNotifier n;

  setUp(() {
    final store = seedStore(DateTime.now()).copyWith(
      businessType: BusinessType.restaurante,
      modules: {Module.restaurante},
      products: const [Product(id: 't', name: 'Tacos', priceCents: 10000)],
    );
    app = ProviderContainer(
      overrides: [initialDataProvider.overrideWithValue(LoadedData(store: store, plan: Plan.negocio))],
    );
    n = app.read(storeProvider.notifier);
    n.addTables(2);
    if (app.read(storeProvider).openSession == null) n.openCash(0);
  });
  tearDown(() => app.dispose());

  StoreState s() => app.read(storeProvider);

  String bill(int tables) {
    final o = n.openOrder(tableId: s().activeTables[tables].id);
    n.addOrderItem(o.id, s().productById('t')!);
    return o.id;
  }

  test('en efectivo: la venta no cambia, el cajón sí, y el corte la muestra aparte', () {
    final session = s().openSession!;
    final before = s().summaryFor(session);
    final sale = n.chargeOrder(
      bill(0),
      kind: SaleKind.pagada,
      method: PayMethod.efectivo,
      receivedCents: 12000,
      tipCents: 1500,
    );
    expect((sale.totalCents, sale.tipCents, sale.paidCents, sale.changeCents), (10000, 1500, 11500, 500));
    final after = s().summaryFor(session);
    expect(after.totalSoldCents - before.totalSoldCents, 10000);
    expect(after.cashSalesCents - before.cashSalesCents, 10000);
    expect(after.cashTipsCents, 1500);
    expect(after.expectedCashCents - before.expectedCashCents, 11500);
  });

  test('con tarjeta y en partes: la propina sale primero del efectivo', () {
    final session = s().openSession!;
    final before = s().summaryFor(session);
    final sale = n.chargeOrder(
      bill(1),
      kind: SaleKind.pagada,
      tipCents: 2000,
      payments: const [
        SalePayment(method: PayMethod.efectivo, amountCents: 1000),
        SalePayment(method: PayMethod.tarjeta, amountCents: 11000),
      ],
    );
    expect(sale.payments.fold(0, (a, p) => a + p.amountCents), 12000);
    final after = s().summaryFor(session);
    expect((after.cashTipsCents, after.otherTipsCents), (1000, 1000));
    expect(after.otherSalesCents - before.otherSalesCents, 10000);
    expect(after.cashSalesCents - before.cashSalesCents, 0);

    // En Reportes, las formas de pago solo cuentan la venta y la propina va aparte.
    final day = salesIn(s().sales, periodFor(PeriodKey.hoy));
    final methods = {
      for (final m in byMethod([sale])) m.label: m.cents,
    };
    expect(methods, {'Tarjeta': 10000});
    expect(tipsOf(day).cents, 2000);
    expect(salesCsv([sale], (_) => 'Caja').split('\r\n')[1], contains(',100.00,20.00,'));
  });

  test('lo fiado no lleva propina', () {
    final c = n.addCustomer('Don Pepe');
    final sale = n.chargeOrder(bill(0), kind: SaleKind.fiada, customerId: c.id, tipCents: 1000);
    expect(sale.tipCents, 0);
  });

  test('la propina viaja al servidor y regresa igual', () {
    final sale = n.chargeOrder(bill(0), kind: SaleKind.pagada, method: PayMethod.tarjeta, tipCents: 1234);
    final row = saleToRemote(sale).firstWhere((c) => c.table == 'sales').rows.single;
    expect(row['tip'], 12.34);
    expect(saleFromRemote({...row, 'status': 'paid'}).tipCents, 1234);
  });

  test('repartir: sale del cajón, no es gasto y se ve cuánto falta', () {
    final session = s().openSession!;
    n.chargeOrder(bill(0), kind: SaleKind.pagada, method: PayMethod.efectivo, tipCents: 3001);
    final before = s().summaryFor(session);
    expect(before.tipsPendingCents, 3001);
    final parts = splitEvenly(3001, 2);
    expect(parts, [1501, 1500]);
    n.addMovement(CashKind.propina, parts[0], 'Propina para Ana');
    final after = s().summaryFor(session);
    expect(after.tipsPaidCents, 1501);
    expect(after.tipsPendingCents, 1500);
    expect(after.gastosCents, before.gastosCents);
    expect(before.expectedCashCents - after.expectedCashCents, 1501);
  });

  test('una propina entregada viaja como "tip"; una app vieja la lee como gasto y el efectivo cuadra igual', () {
    n.addMovement(CashKind.propina, 1000, 'Propina para Ana');
    final m = s().movements.last;
    final row = movementToRemote(m);
    expect(row['kind'], 'tip');
    expect(movementFromRemote(row).kind, CashKind.propina);
    expect(movementFromRemote({...row, 'kind': 'out'}).kind, CashKind.gasto);
  });

  test('dónde se vende un producto: viaja al servidor y regresa igual', () {
    const p = Product(id: 'x', name: 'Pozole', priceCents: 9000, place: ProductPlace.mesas);
    final row = productToRemote(p, withStock: false);
    expect(row['sold_at'], 'tables');
    expect(productFromRemote(row).soldAt, 'tables');
    expect(
      productToRemote(const Product(id: 'y', name: 'Chicle', priceCents: 500), withStock: false)['sold_at'],
      isNull,
    );
    expect((p.atTables, p.atCounter), (true, false));
  });
}
