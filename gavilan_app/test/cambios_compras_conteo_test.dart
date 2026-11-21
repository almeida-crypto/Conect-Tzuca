import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/core/ticket_text.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/domain/purchases.dart';
import 'package:gavilan/domain/reports.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';

/// Cambio de talla, compras a proveedores y conteo de inventario.
void main() {
  late ProviderContainer app;
  StoreNotifier store() => app.read(storeProvider.notifier);
  StoreState state() => app.read(storeProvider);
  CashSummary summary() => state().summaryFor(state().openSession!);

  setUp(
    () => app = ProviderContainer(
      overrides: [
        initialDataProvider.overrideWithValue(LoadedData(store: seedStore(DateTime.now()), plan: Plan.negocio)),
      ],
    ),
  );
  tearDown(() => app.dispose());

  const runner = Product(id: 'runner', name: 'Tenis Runner', priceCents: 89900, costCents: 50000);

  Product size(String s) => state().variantsOf('runner').firstWhere((v) => v.size == s);

  SaleLine line(Product p, [double qty = 1]) =>
      SaleLine(key: p.id, productId: p.id, name: p.name, unitCents: p.priceCents, unitCostCents: p.costCents, qty: qty);

  Sale sell(List<SaleLine> lines, {PayMethod method = PayMethod.efectivo}) =>
      store().checkout(lines: lines, kind: SaleKind.pagada, method: method);

  setUp(() {
    store().saveModel(runner, [(size: '26', color: null, qty: 3), (size: '27', color: null, qty: 2)]);
    store().saveProduct(
      const Product(id: 'calcetas', name: 'Calcetas', priceCents: 5000, costCents: 2000, trackStock: true, stock: 10),
    );
  });

  group('Cambio de talla', () {
    test('cambia el 26 por el 27: el inventario se mueve y la caja queda igual', () {
      final sale = sell([line(size('26'))]);
      final before = summary();
      final done = store().exchange(sale.id, {0: 1}, [line(size('27'))])!;

      expect(size('26').stock, 3); // regresó
      expect(size('27').stock, 1); // salió
      expect(done.ret.isExchange, isTrue);
      expect(done.ret.exchangeSaleId, done.sale.id);
      expect((done.ret.amountCents, done.sale.totalCents), (89900, 89900));
      final after = summary();
      expect(after.expectedCashCents, before.expectedCashCents);
      expect(after.totalSoldCents, before.totalSoldCents);
      expect(after.exchangeCents, 89900);
      expect(state().exchangesInto(done.sale.id).single.saleId, sale.id);
    });

    test('se lleva algo más caro y paga la diferencia con tarjeta: el efectivo no cambia', () {
      final sale = sell([line(state().productById('calcetas')!)]);
      final before = summary();
      final done = store().exchange(sale.id, {0: 1}, [line(size('26'))], method: PayMethod.tarjeta)!;
      expect(done.sale.payments.map((p) => (p.method, p.amountCents)), [
        (PayMethod.efectivo, 5000),
        (PayMethod.tarjeta, 84900),
      ]);
      final after = summary();
      expect(after.expectedCashCents, before.expectedCashCents);
      expect(after.otherInCents, before.otherInCents + 84900);
      expect(after.totalSoldCents, before.totalSoldCents + 84900);
      // En los reportes la mercancía que regresó cuenta aparte, no como efectivo.
      final methods = {
        for (final m in byMethod([done.sale], exchangeCredit: {done.sale.id: done.ret.amountCents})) m.label: m.cents,
      };
      expect(methods, {'Cambio de mercancía': 5000, 'Tarjeta': 84900});
    });

    test('el ticket del cambio dice lo que regresó y la diferencia', () {
      final sale = sell([line(state().productById('calcetas')!)]);
      final done = store().exchange(sale.id, {0: 1}, [line(size('26'))], method: PayMethod.transferencia)!;
      final text = ticketText(
        business: 'Zapatería',
        sale: done.sale,
        exchange: (folio: sale.folioLabel, cents: done.ret.amountCents),
      );
      expect(text, contains('Regresó (venta ${sale.folioLabel}) -\$50.00'));
      expect(text, contains('Pagó la diferencia \$849.00 con transferencia'));
      expect(text, isNot(contains('Efectivo')));
    });

    test('se lleva algo más barato: se le devuelve la diferencia del efectivo de la caja', () {
      final sale = sell([line(size('26'))]);
      final before = summary();
      store().exchange(sale.id, {0: 1}, [line(state().productById('calcetas')!, 2)]);
      expect(summary().expectedCashCents, before.expectedCashCents - (89900 - 10000));
    });

    test('no se cambia más de lo que compró, y la venta con cambio ya no se cancela hoy', () {
      final sale = sell([line(size('26'), 2)]);
      expect(store().exchange(sale.id, {0: 1}, [line(size('27'))]), isNotNull);
      expect(store().exchange(sale.id, {0: 1}, [line(size('27'))]), isNotNull);
      expect(store().exchange(sale.id, {0: 1}, [line(size('27'))]), isNull); // ya no queda nada que regresar
      expect(state().hadExchangeToday(state().sales.firstWhere((s) => s.id == sale.id)), isTrue);
      expect(store().cancelSale(sale.id, reason: 'x'), isNull);
      expect(store().returnItems(sale.id, {0: 1}, reason: 'x'), isNull);
    });

    test('lo fiado no se cambia aquí', () {
      final sale = store().checkout(lines: [line(size('26'))], kind: SaleKind.fiada, customerId: 'c1');
      expect(store().exchange(sale.id, {0: 1}, [line(size('27'))]), isNull);
    });
  });

  group('Compras a proveedores', () {
    test('llega mercancía: entra al inventario, el costo se actualiza y queda lo que se debe', () {
      final s = store().addSupplier('Distribuidora del Sureste', phone: '9991112233');
      final before = summary();
      final p = store().addPurchase(
        supplierId: s.id,
        lines: [
          PurchaseLine(productId: size('26').id, name: size('26').name, qty: 6, unitCostCents: 55000),
          const PurchaseLine(productId: 'calcetas', name: 'Calcetas', qty: 12, unitCostCents: 1800),
        ],
        paidCents: 100000,
      );
      expect(p.totalCents, 6 * 55000 + 12 * 1800);
      expect(size('26').stock, 9);
      expect(state().productById('calcetas')!.stock, 22);
      // El costo nuevo: el de la talla, el del modelo y el de las demás tallas.
      expect(
        (size('26').costCents, size('27').costCents, state().productById('runner')!.costCents),
        (55000, 55000, 55000),
      );
      expect(state().productById('calcetas')!.costCents, 1800);
      expect(state().debtToSupplier(s.id), p.totalCents - 100000);
      expect(state().paidOfPurchase(p.id), 100000);
      expect(summary().supplierCashCents, 100000);
      expect(summary().expectedCashCents, before.expectedCashCents - 100000);

      // Un pago por transferencia baja la deuda sin tocar la caja.
      store().paySupplier(s.id, 50000, PayMethod.transferencia);
      expect(state().debtToSupplier(s.id), p.totalCents - 150000);
      expect(summary().expectedCashCents, before.expectedCashCents - 100000);
      expect(state().supplierDebt, p.totalCents - 150000);
    });

    test('sin guardar el costo, el producto se queda con el suyo', () {
      store().addPurchase(
        lines: [const PurchaseLine(productId: 'calcetas', name: 'Calcetas', qty: 5, unitCostCents: 2500)],
        updateCost: false,
        paidCents: 12500,
      );
      expect(state().productById('calcetas')!.costCents, 2000);
      expect(state().productById('calcetas')!.stock, 15);
    });
  });

  group('Conteo de inventario', () {
    test('lo contado queda como existencia y se sabe cuánto faltó a costo; lo no contado no cambia', () {
      store().countOne(size('26').id);
      store().countOne(size('26').id); // 2 de 3: falta uno
      store().setCounted('calcetas', 12); // sobran 2
      expect(state().countDraft, {size('26').id: 2, 'calcetas': 12});

      final count = store().applyCount()!;
      expect(size('26').stock, 2);
      expect(state().productById('calcetas')!.stock, 12);
      expect(size('27').stock, 2); // no se contó
      expect((count.missingPieces, count.extraPieces), (1.0, 2.0));
      expect((count.missingCostCents, count.extraCostCents), (50000, 4000));
      expect(state().countDraft, isEmpty);
      expect(state().stockCounts.single.id, count.id);
    });

    test('se puede quitar algo del conteo o empezar de nuevo', () {
      store().setCounted('calcetas', 3);
      store().setCounted('calcetas', null);
      expect(state().countDraft, isEmpty);
      store().setCounted('calcetas', 3);
      store().discardCount();
      expect(store().applyCount(), isNull);
      expect(state().productById('calcetas')!.stock, 10);
    });

    test('se cuentan las tallas, no los modelos ni lo que no lleva existencia', () {
      final names = state().countableProducts.map((p) => p.name);
      expect(names, containsAll(['Tenis Runner · 26', 'Tenis Runner · 27', 'Calcetas']));
      expect(names, isNot(contains('Tenis Runner')));
      expect(state().countableProducts.every((p) => p.trackStock), isTrue);
    });
  });

  test('cambio, compras, pagos, conteo y borrador se guardan en el teléfono', () async {
    final db = GavilanDb(NativeDatabase.memory());
    final repo = DriftRepository(db);
    Future<ProviderContainer> open() async {
      final loaded = await repo.load();
      return ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(loaded)],
      );
    }

    var phone = await open();
    var n = phone.read(storeProvider.notifier);
    n.startBusiness('Zapatería Lupita');
    n.openCash(50000);
    n.saveModel(runner, [(size: '26', color: null, qty: 3), (size: '27', color: null, qty: 2)]);
    final v = phone.read(storeProvider).variantsOf('runner');
    final sale = n.checkout(
      lines: [SaleLine(key: 'a', productId: v[0].id, name: v[0].name, unitCents: 89900, qty: 1)],
      kind: SaleKind.pagada,
      method: PayMethod.efectivo,
    );
    final done = n.exchange(
      sale.id,
      {0: 1},
      [SaleLine(key: 'b', productId: v[1].id, name: v[1].name, unitCents: 89900, qty: 1)],
    )!;
    final s = n.addSupplier('Calzado León');
    n.addPurchase(
      supplierId: s.id,
      lines: [PurchaseLine(productId: v[1].id, name: v[1].name, qty: 4, unitCostCents: 52000)],
      paidCents: 0,
    );
    n.paySupplier(s.id, 100000, PayMethod.efectivo);
    n.setCounted(v[0].id, 3);
    n.applyCount();
    n.setCounted(v[1].id, 4); // a medio conteo
    await n.flush();
    final expected = phone.read(storeProvider).summaryFor(phone.read(storeProvider).openSession!).expectedCashCents;
    phone.dispose();

    phone = await open();
    final st = phone.read(storeProvider);
    expect(st.exchangesInto(done.sale.id).single.saleId, sale.id);
    expect(st.debtToSupplier(s.id), 4 * 52000 - 100000);
    expect(st.stockCounts.single.lines.single.counted, 3);
    expect(st.countDraft, {v[1].id: 4.0});
    expect(st.summaryFor(st.openSession!).expectedCashCents, expected);
    phone.dispose();
    await db.close();
  });
}
