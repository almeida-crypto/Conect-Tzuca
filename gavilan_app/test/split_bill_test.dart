import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/remote_mapping.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/domain/restaurant.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';
import 'package:gavilan/ui/cobrar/split_pay_sheet.dart';

/// Pagos en partes (mixtos o iguales) y cuenta del restaurante por platillos.
void main() {
  ProviderContainer demo() {
    final app = ProviderContainer(
      overrides: [
        initialDataProvider.overrideWithValue(LoadedData(store: seedStore(DateTime.now()), plan: Plan.negocio)),
      ],
    );
    addTearDown(app.dispose);
    return app;
  }

  SaleLine lineOf(Product p, double qty) =>
      SaleLine(key: p.id, productId: p.id, name: p.name, unitCents: p.priceCents, unitCostCents: p.costCents, qty: qty);

  test('partes iguales suman exacto', () {
    expect(equalParts(10000, 3), [3334, 3333, 3333]);
    expect(equalParts(9000, 3), [3000, 3000, 3000]);
    expect(equalParts(1, 2), [1, 0]);
  });

  test('pago mixto: en el corte, cada parte cuenta según cómo se pagó', () {
    final app = demo();
    final n = app.read(storeProvider.notifier);
    StoreState s() => app.read(storeProvider);
    final coca = s().products.firstWhere((p) => p.name.startsWith('Coca'));
    final before = s().summaryFor(s().openSession!);

    final sale = n.checkout(
      lines: [lineOf(coca, 5)], // 5 x $18 = $90
      kind: SaleKind.pagada,
      receivedCents: 10000,
      payments: const [
        SalePayment(method: PayMethod.efectivo, amountCents: 6000),
        SalePayment(method: PayMethod.tarjeta, amountCents: 3000),
      ],
    );
    expect(sale.split, isTrue);
    expect(sale.method, isNull);
    expect(sale.cashCents, 6000);
    expect(sale.changeCents, 4000); // pagó $100 por los $60 de efectivo
    expect(paymentsLabel(sale.payments), 'Efectivo y tarjeta');

    final after = s().summaryFor(s().openSession!);
    expect(after.cashSalesCents - before.cashSalesCents, 6000);
    expect(after.otherSalesCents - before.otherSalesCents, 3000);
    expect(after.expectedCashCents - before.expectedCashCents, 6000);

    // Un solo pago es lo mismo que pagar normal.
    final single = n.checkout(
      lines: [lineOf(coca, 1)],
      kind: SaleKind.pagada,
      payments: const [SalePayment(method: PayMethod.transferencia, amountCents: 1800)],
    );
    expect(single.split, isFalse);
    expect(single.method, PayMethod.transferencia);

    // Si no cuadran con el total, el último pago absorbe la diferencia.
    final odd = n.checkout(
      lines: [lineOf(coca, 2)], // $36
      kind: SaleKind.pagada,
      payments: const [
        SalePayment(method: PayMethod.efectivo, amountCents: 2000),
        SalePayment(method: PayMethod.tarjeta, amountCents: 2000),
      ],
    );
    expect(odd.payments.map((p) => p.amountCents), [2000, 1600]);
  });

  test('devolver parte de una venta pagada en partes regresa primero el efectivo', () {
    expect(
      reducePayments(const [
        SalePayment(method: PayMethod.tarjeta, amountCents: 5000),
        SalePayment(method: PayMethod.efectivo, amountCents: 3000),
      ], 4000).map((p) => (p.method, p.amountCents)),
      [(PayMethod.tarjeta, 4000)],
    );

    final app = demo();
    final n = app.read(storeProvider.notifier);
    StoreState s() => app.read(storeProvider);
    final coca = s().products.firstWhere((p) => p.name.startsWith('Coca'));
    final sale = n.checkout(
      lines: [lineOf(coca, 4)], // $72
      kind: SaleKind.pagada,
      payments: const [
        SalePayment(method: PayMethod.efectivo, amountCents: 2000),
        SalePayment(method: PayMethod.tarjeta, amountCents: 5200),
      ],
    );
    final kept = n.returnItems(sale.id, {0: 2}, reason: 'No las quiso')!; // regresa $36
    expect(kept.totalCents, 3600);
    expect(kept.paymentParts.map((p) => (p.method, p.amountCents)), [(PayMethod.tarjeta, 3600)]);
    expect(kept.split, isFalse);
    expect(kept.method, PayMethod.tarjeta);
  });

  test('los pagos se guardan al reabrir, suben a la nube y se bajan', () async {
    final db = GavilanDb(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftRepository(db);
    final loaded = await repo.load();
    final app = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(loaded)],
    );
    addTearDown(app.dispose);
    final n = app.read(storeProvider.notifier);
    n.startBusiness('La Esperanza');
    n.saveProduct(const Product(id: 'p', name: 'Torta', priceCents: 6000));
    n.openCash(0);
    final sale = n.checkout(
      lines: const [SaleLine(key: 'p', productId: 'p', name: 'Torta', unitCents: 6000, qty: 2)],
      kind: SaleKind.pagada,
      payments: const [
        SalePayment(method: PayMethod.efectivo, amountCents: 4000),
        SalePayment(method: PayMethod.efectivo, amountCents: 4000),
        SalePayment(method: PayMethod.transferencia, amountCents: 4000),
      ],
    );
    await n.flush();

    final again = (await repo.load())!.store.sales.single;
    expect(again.payments.map((p) => (p.method, p.amountCents)), [
      (PayMethod.efectivo, 4000),
      (PayMethod.efectivo, 4000),
      (PayMethod.transferencia, 4000),
    ]);

    final remote = saleToRemote(sale);
    expect(remote.first.rows.single['pay_method'], isNull);
    final pays = remote.firstWhere((c) => c.table == 'sale_payments').rows;
    expect(pays.map((r) => (r['method'], r['amount'])), [('cash', 40), ('cash', 40), ('transfer', 40)]);
    expect(pays.first['id'], salePaymentId(sale.id, 0));

    // Otro celular la baja.
    final db2 = GavilanDb(NativeDatabase.memory());
    addTearDown(db2.close);
    final repo2 = DriftRepository(db2);
    await repo2.replaceAll(StoreState.blank.copyWith(businessName: 'La Esperanza', businessId: 'b'), Plan.semilla);
    await repo2.applyRemote('sales', [remote.first.rows.single]);
    await repo2.applyRemote('sale_payments', pays);
    final down = (await repo2.load())!.store.sales.single;
    expect(down.split, isTrue);
    expect(down.payments.map((p) => p.method), [PayMethod.efectivo, PayMethod.efectivo, PayMethod.transferencia]);
    expect(down.cashCents, 8000);
  });

  group('cuenta de la mesa por platillos', () {
    late ProviderContainer app;
    late StoreNotifier n;
    StoreState s() => app.read(storeProvider);

    setUp(() {
      app = demo();
      n = app.read(storeProvider.notifier);
      n.addTables(1);
    });

    test('cada quien paga lo suyo; la mesa se libera cuando se paga todo', () {
      final table = s().activeTables.first;
      final order = n.openOrder(tableId: table.id);
      final coca = s().products.firstWhere((p) => p.name.startsWith('Coca'));
      final pan = s().products.firstWhere((p) => p.name.startsWith('Pan'));
      n.addOrderItem(order.id, coca);
      n.addOrderItem(order.id, coca);
      n.addOrderItem(order.id, coca); // 3 cocas
      n.addOrderItem(order.id, pan);
      n.sendToKitchen(order.id);
      final cocaItem = s().itemsOfOrder(order.id).firstWhere((i) => i.productId == coca.id);
      final panItem = s().itemsOfOrder(order.id).firstWhere((i) => i.productId == pan.id);
      final total = s().totalOfOrder(order.id);

      // Ana paga 1 coca y el pan.
      final ana = n.chargeOrderItems(
        order.id,
        {cocaItem.id: 1, panItem.id: 1},
        kind: SaleKind.pagada,
        method: PayMethod.efectivo,
      )!;
      expect(ana.totalCents, coca.priceCents + pan.priceCents);
      expect(s().orderById(order.id)!.isOpen, isTrue);
      expect(s().totalOfOrder(order.id), total - ana.totalCents);
      expect(s().partlyPaid(order.id), isTrue);
      expect(s().itemsOfOrder(order.id).firstWhere((i) => i.id == cocaItem.id).paidQty, 1);

      // No se cobra dos veces lo mismo: pedir 5 cocas cobra solo las 2 que faltan.
      final beto = n.chargeOrderItems(
        order.id,
        {cocaItem.id: 5, panItem.id: 1},
        kind: SaleKind.pagada,
        method: PayMethod.tarjeta,
      )!;
      expect(beto.lines.single.qty, 2);
      expect(s().orderById(order.id)!.isOpen, isFalse);
      expect(ana.totalCents + beto.totalCents, total);
      expect(n.chargeOrderItems(order.id, {cocaItem.id: 1}, kind: SaleKind.pagada), isNull);
    });

    test('lo pagado no se puede quitar y al cancelar la cuenta se queda', () {
      final table = s().activeTables.first;
      final order = n.openOrder(tableId: table.id);
      final coca = s().products.firstWhere((p) => p.name.startsWith('Coca'));
      n.addOrderItem(order.id, coca);
      n.addOrderItem(order.id, coca);
      final item = s().itemsOfOrder(order.id).single;
      n.chargeOrderItems(order.id, {item.id: 1}, kind: SaleKind.pagada, method: PayMethod.efectivo);

      n.setItemQty(item.id, 0); // ya hay una pagada: no se deja
      expect(s().itemsOfOrder(order.id).single.qty, 2);

      // El resto con "Cobrar" normal: solo lo que falta.
      final rest = n.chargeOrder(order.id, kind: SaleKind.pagada, method: PayMethod.efectivo);
      expect(rest.lines.single.qty, 1);

      final order2 = n.openOrder(tableId: table.id);
      n.addOrderItem(order2.id, coca);
      n.addOrderItem(order2.id, coca);
      final item2 = s().itemsOfOrder(order2.id).single;
      n.chargeOrderItems(order2.id, {item2.id: 1}, kind: SaleKind.pagada, method: PayMethod.efectivo);
      n.cancelOrder(order2.id); // se fue el otro sin pagar
      final closed = s().orderById(order2.id)!;
      expect(closed.status, OrderStatus.cerrada);
      expect(s().itemsOfOrder(order2.id).single.qty, 1);
      expect(s().itemsOfOrder(order2.id).single.cancelled, isFalse);
    });

    test('lo pagado por platillo viaja a la nube', () {
      final item = OrderItem(
        id: 'i',
        orderId: 'o',
        name: 'Taco',
        qty: 3,
        unitCents: 2000,
        createdAt: DateTime(2026),
        paidQty: 2,
      );
      final row = orderItemToRemote(item);
      expect(row['paid_qty'], 2);
      expect(orderItemFromRemote({...row, 'business_id': 'b'}).paidQty, 2);
      expect(item.dueCents, 2000);
    });
  });
}
