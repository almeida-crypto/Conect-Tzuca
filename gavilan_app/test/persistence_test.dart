import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/state/app_state.dart';
import 'package:gavilan/state/store.dart';

/// Simula "cerrar y volver a abrir la app" sobre la misma base SQLite.
void main() {
  late GavilanDb db;
  late DriftRepository repo;

  setUp(() {
    db = GavilanDb(NativeDatabase.memory());
    repo = DriftRepository(db);
  });
  tearDown(() => db.close());

  Future<ProviderContainer> open() async {
    final loaded = await repo.load();
    return ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(loaded)],
    );
  }

  test('primer arranque: no hay negocio guardado', () async {
    expect(await repo.load(), isNull);
    final app = await open();
    expect(app.read(storeProvider).hasBusiness, isFalse);
    app.dispose();
  });

  test('alta de negocio vacío se conserva al reabrir', () async {
    var app = await open();
    app.read(storeProvider.notifier).startBusiness('  Tienda La Esperanza ');
    await app.read(storeProvider.notifier).flush();
    app.dispose();

    app = await open();
    final s = app.read(storeProvider);
    expect(s.businessName, 'Tienda La Esperanza');
    expect(s.products, isEmpty);
    expect(s.openSession, isNull);
    app.dispose();
  });

  test('ventas, fiados, caja, inventario, folio y plan sobreviven al reabrir', () async {
    var app = await open();
    final n = app.read(storeProvider.notifier);
    n.loadDemo();
    final p1 = app.read(storeProvider).productById('p1')!;
    final before = app.read(storeProvider);
    final expectedBefore = before.summaryFor(before.openSession!).expectedCashCents;

    final sale = n.checkout(
      lines: [SaleLine(key: p1.id, productId: p1.id, name: p1.name, unitCents: p1.priceCents, qty: 3)],
      kind: SaleKind.pagada,
      method: PayMethod.efectivo,
      receivedCents: 10000,
    );
    final c = n.addCustomer('Don Chucho', phone: '9970000000');
    n.checkout(
      lines: [const SaleLine(key: 'q', name: 'Varios', unitCents: 2550, qty: 1)],
      kind: SaleKind.fiada,
      customerId: c.id,
    );
    n.addAbono(c.id, 1000, PayMethod.efectivo);
    n.addMovement(CashKind.gasto, 3000, 'Bolsas');
    n.saveProduct(app.read(storeProvider).productById('p1')!.copyWith(name: 'Coca-Cola 600 ml', priceCents: 1900));
    n.addStock('p2', 10);
    app.read(planProvider.notifier).set(Plan.emprendedor);
    await n.flush();
    final snapshot = app.read(storeProvider);
    app.dispose();

    app = await open();
    final s = app.read(storeProvider);
    expect(app.read(planProvider), Plan.emprendedor);
    expect(s.businessName, snapshot.businessName);
    expect(s.nextFolio, snapshot.nextFolio);
    expect(s.sales.length, snapshot.sales.length);
    final reloaded = s.sales.firstWhere((x) => x.id == sale.id);
    expect(reloaded.totalCents, 5400);
    expect(reloaded.changeCents, 4600);
    expect(reloaded.lines.single.qty, 3);
    expect(s.balanceOf(c.id), 1550);
    expect(s.customerById(c.id)!.phone, '9970000000');
    expect(s.productById('p1')!.name, 'Coca-Cola 600 ml');
    expect(s.productById('p1')!.stock, p1.stock - 3);
    expect(s.productById('p2')!.stock, snapshot.productById('p2')!.stock);
    final summary = s.summaryFor(s.openSession!);
    expect(summary.expectedCashCents, expectedBefore + 5400 + 1000 - 3000);
    expect(summary.creditSalesCents, 2550);
    expect(s.closedSessions.length, snapshot.closedSessions.length);
    app.dispose();
  });

  test('cerrar caja y borrar todo se guardan', () async {
    var app = await open();
    final n = app.read(storeProvider.notifier);
    n.loadDemo();
    n.closeCash(12345);
    await n.flush();
    app.dispose();

    app = await open();
    expect(app.read(storeProvider).openSession, isNull);
    expect(app.read(storeProvider).closedSessions.first.countedCents, 12345);
    app.read(storeProvider.notifier).resetAll();
    await app.read(storeProvider.notifier).flush();
    app.dispose();

    expect(await repo.load(), isNull);
  });
}
