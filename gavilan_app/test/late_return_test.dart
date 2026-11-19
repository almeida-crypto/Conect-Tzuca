import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';

/// Devolver una parte de una venta de un corte ya cerrado.
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

  test('pagada en efectivo: el corte de ese día no cambia; hoy sale el efectivo y regresa la mercancía', () {
    final app = demo();
    final n = app.read(storeProvider.notifier);
    StoreState s() => app.read(storeProvider);
    final coca = s().products.firstWhere((p) => p.name.startsWith('Coca'));
    final pan = s().products.firstWhere((p) => p.name.startsWith('Pan'));
    final sale = n.checkout(
      lines: [lineOf(coca, 3), lineOf(pan, 2)],
      kind: SaleKind.pagada,
      method: PayMethod.efectivo,
    );
    final yesterday = s().openSession!;
    n.closeCash(s().summaryFor(yesterday).expectedCashCents);
    final closedCut = s().summaryFor(s().sessions.firstWhere((x) => x.id == yesterday.id));
    final stockCoca = s().productById(coca.id)!.stock;

    // Sin caja abierta no se puede.
    expect(n.returnFromPastSale(sale.id, {0: 1}, reason: 'Mal estado'), isNull);

    n.openCash(50000);
    final today = s().openSession!;
    final ret = n.returnFromPastSale(sale.id, {0: 1}, reason: 'Mal estado')!;
    expect(ret.amountCents, coca.priceCents);
    expect(ret.cashCents, coca.priceCents);
    expect(ret.sessionId, today.id);
    expect(ret.summary, '1 ${coca.name}');

    // La venta sigue igual y su corte también.
    expect(s().sales.firstWhere((x) => x.id == sale.id).cancelled, isFalse);
    final after = s().summaryFor(s().sessions.firstWhere((x) => x.id == yesterday.id));
    expect(after.expectedCashCents, closedCut.expectedCashCents);
    expect(after.salesCount, closedCut.salesCount);

    // Hoy: el efectivo sale como gasto; la mercancía regresa.
    expect(s().summaryFor(today).gastosCents, coca.priceCents);
    expect(s().movements.last.concept, 'Devolución de la venta ${sale.folioLabel}: 1 ${coca.name}');
    expect(s().productById(coca.id)!.stock, stockCoca + 1);

    // No se devuelve más de lo que compró: de 3 cocas ya regresó 1, quedan 2.
    final second = n.returnFromPastSale(sale.id, {0: 5}, reason: 'Mal estado')!;
    expect(second.lines.single.qty, 2);
    expect(s().returnedOf(sale.id)[coca.id], 3);
    expect(n.returnFromPastSale(sale.id, {0: 1}, reason: 'otra'), isNull); // ya no quedan cocas

    // Si al final cancela la venta, solo se devuelve lo que quedaba (el pan).
    final gastosBefore = s().summaryFor(today).gastosCents;
    final stockPan = s().productById(pan.id)!.stock;
    n.cancelSale(sale.id, reason: 'Se arrepintió');
    expect(s().summaryFor(today).gastosCents - gastosBefore, pan.priceCents * 2);
    if (pan.trackStock) expect(s().productById(pan.id)!.stock, stockPan + 2);
    expect(s().productById(coca.id)!.stock, stockCoca + 3);
  });

  test('regresar todo de una vez es cancelar la venta', () {
    final app = demo();
    final n = app.read(storeProvider.notifier);
    StoreState s() => app.read(storeProvider);
    final coca = s().products.firstWhere((p) => p.name.startsWith('Coca'));
    final sale = n.checkout(lines: [lineOf(coca, 2)], kind: SaleKind.pagada, method: PayMethod.efectivo);
    n.closeCash(s().summaryFor(s().openSession!).expectedCashCents);
    n.openCash(0);
    expect(n.returnFromPastSale(sale.id, {0: 2}, reason: 'Mal estado'), isNull);
    expect(s().sales.firstWhere((x) => x.id == sale.id).cancelled, isTrue);
    expect(s().saleReturns, isEmpty);
  });

  test('con descuento y pagada en partes: vale lo que se cobró y primero sale del efectivo', () {
    final app = demo();
    final n = app.read(storeProvider.notifier);
    StoreState s() => app.read(storeProvider);
    const a = Product(id: 'a', name: 'Blusa', priceCents: 10000);
    const b = Product(id: 'b', name: 'Falda', priceCents: 10000);
    n.saveProduct(a);
    n.saveProduct(b);
    // $200 con $20 de descuento = $180: $50 en efectivo y $130 con tarjeta.
    final sale = n.checkout(
      lines: [lineOf(a, 1), lineOf(b, 1)],
      kind: SaleKind.pagada,
      discountCents: 2000,
      payments: const [
        SalePayment(method: PayMethod.efectivo, amountCents: 5000),
        SalePayment(method: PayMethod.tarjeta, amountCents: 13000),
      ],
    );
    n.closeCash(s().summaryFor(s().openSession!).expectedCashCents);
    n.openCash(0);
    final ret = n.returnFromPastSale(sale.id, {1: 1}, reason: 'Talla')!;
    expect(ret.amountCents, 9000); // la falda, con su parte del descuento
    expect(ret.cashCents, 5000); // todo el efectivo; los otros $40, por la tarjeta
    expect(s().summaryFor(s().openSession!).gastosCents, 5000);
  });

  test('fiada: se le quita de la deuda y no sale efectivo', () {
    final app = demo();
    final n = app.read(storeProvider.notifier);
    StoreState s() => app.read(storeProvider);
    final pan = s().products.firstWhere((p) => p.name.startsWith('Pan'));
    final rosa = n.addCustomer('Doña Rosa');
    final sale = n.checkout(lines: [lineOf(pan, 4)], kind: SaleKind.fiada, customerId: rosa.id);
    n.closeCash(s().summaryFor(s().openSession!).expectedCashCents);
    n.openCash(0);
    final before = s().balanceOf(rosa.id);
    final ret = n.returnFromPastSale(sale.id, {0: 1}, reason: 'Mal estado')!;
    expect(ret.cashCents, 0);
    expect(s().balanceOf(rosa.id), before - pan.priceCents);
    expect(s().summaryFor(s().openSession!).gastosCents, 0);
    // Cancelar después: solo se quita lo que faltaba.
    n.cancelSale(sale.id, reason: 'Se arrepintió');
    expect(s().balanceOf(rosa.id), before - pan.priceCents * 4);
  });

  test('la devolución se guarda en el teléfono', () async {
    final db = GavilanDb(NativeDatabase.memory());
    final repo = DriftRepository(db);
    Future<ProviderContainer> open() async => ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(await repo.load())],
    );
    var app = await open();
    final n = app.read(storeProvider.notifier);
    StoreState s() => app.read(storeProvider);
    n.startBusiness('La Esperanza');
    n.saveProduct(const Product(id: 'p', name: 'Coca', priceCents: 1800, stock: 10, trackStock: true));
    n.openCash(0);
    final sale = n.checkout(
      lines: [lineOf(s().productById('p')!, 3)],
      kind: SaleKind.pagada,
      method: PayMethod.efectivo,
    );
    n.closeCash(s().summaryFor(s().openSession!).expectedCashCents);
    n.openCash(0);
    final ret = n.returnFromPastSale(sale.id, {0: 1}, reason: 'Mal estado')!;
    await n.flush();
    app.dispose();

    app = await open();
    final back = app.read(storeProvider).returnsOf(sale.id).single;
    expect(back.id, ret.id);
    expect(back.lines.single.qty, 1);
    expect(back.amountCents, 1800);
    expect(app.read(storeProvider).productById('p')!.stock, 8);
    app.dispose();
    await db.close();
  });
}
