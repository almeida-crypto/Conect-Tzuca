import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/remote_mapping.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';

/// Cancelar ventas de cortes ya cerrados y el nombre de cada caja.
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

  test('una venta de un corte cerrado: su corte no cambia y la devolución sale de la caja de hoy', () {
    final app = demo();
    final n = app.read(storeProvider.notifier);
    StoreState s() => app.read(storeProvider);
    final coca = s().products.firstWhere((p) => p.name.startsWith('Coca'));

    final sale = n.checkout(
      lines: [lineOf(coca, 3)],
      kind: SaleKind.pagada,
      payments: const [
        SalePayment(method: PayMethod.efectivo, amountCents: 3000),
        SalePayment(method: PayMethod.tarjeta, amountCents: 2400),
      ],
    );
    final yesterday = s().openSession!;
    final expected = s().summaryFor(yesterday).expectedCashCents;
    n.closeCash(expected);
    final closedCut = s().summaryFor(s().sessions.firstWhere((x) => x.id == yesterday.id));
    final profitBefore = s().profitFor(yesterday).profitCents;
    final stockBefore = s().productById(coca.id)!.stock;

    // Sin caja abierta no se puede: la devolución tiene que salir de algún cajón.
    expect(n.cancelSale(sale.id, reason: 'Se arrepintió'), isNull);

    n.openCash(50000);
    final today = s().openSession!;
    final cancelled = n.cancelSale(sale.id, reason: 'Se arrepintió')!;
    expect(cancelled.cancelled, isTrue);
    expect(cancelled.cancelledInSession, today.id);
    expect(cancelled.countsInItsCut, isTrue);
    expect(cancelled.cancelReason, startsWith('Se arrepintió (cancelada el'));

    // El corte cerrado sigue igual (venta, efectivo y ganancia).
    final after = s().summaryFor(s().sessions.firstWhere((x) => x.id == yesterday.id));
    expect(after.expectedCashCents, closedCut.expectedCashCents);
    expect(after.salesCount, closedCut.salesCount);
    expect(s().profitFor(yesterday).profitCents, profitBefore);

    // Hoy: sale como gasto solo lo que se pagó en efectivo; la mercancía regresa.
    final todayCut = s().summaryFor(today);
    expect(todayCut.gastosCents, 3000);
    expect(todayCut.expectedCashCents, 50000 - 3000);
    expect(s().movements.last.concept, 'Devolución de la venta ${sale.folioLabel}');
    expect(s().productById(coca.id)!.stock, stockBefore + 3);
    expect(n.cancelSale(sale.id, reason: 'otra vez'), isNull);
  });

  test('una venta fiada de otro día: solo se le quita la deuda', () {
    final app = demo();
    final n = app.read(storeProvider.notifier);
    StoreState s() => app.read(storeProvider);
    final pan = s().products.firstWhere((p) => p.name.startsWith('Pan'));
    final rosa = n.addCustomer('Doña Rosa');
    final sale = n.checkout(lines: [lineOf(pan, 4)], kind: SaleKind.fiada, customerId: rosa.id);
    n.closeCash(s().summaryFor(s().openSession!).expectedCashCents);
    n.openCash(0);
    final today = s().openSession!;

    n.cancelSale(sale.id, reason: 'Se cobró mal');
    expect(s().balanceOf(rosa.id), 0);
    expect(s().credit.last.sessionId, today.id);
    expect(s().summaryFor(today).gastosCents, 0);
  });

  test('la cancelación tardía viaja a la nube', () {
    final sale = Sale(
      id: 's',
      folio: 1,
      createdAt: DateTime(2026, 11, 17),
      lines: const [SaleLine(key: 'p', productId: 'p', name: 'Pan', unitCents: 800, qty: 1)],
      kind: SaleKind.pagada,
      sessionId: 'ayer',
      method: PayMethod.efectivo,
    ).cancel(DateTime(2026, 11, 18), 'Se cobró mal', inSession: 'hoy');
    final row = saleToRemote(sale).first.rows.single;
    expect(row['cancelled_session_id'], 'hoy');
    expect(saleFromRemote({...row, 'updated_at': '2026-11-18T10:00:00Z'}).cancelledInSession, 'hoy');
  });

  test('cada caja con su nombre: se guarda, lo toma el turno y se ve en todas las cajas', () async {
    final db = GavilanDb(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftRepository(db, deviceCode: 'K7');
    var app = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(await repo.load())],
    );
    final n = app.read(storeProvider.notifier);
    n.startBusiness('La Esperanza');
    expect(StoreState.registerLabel(app.read(storeProvider).registerName, 'K7'), 'Caja K7');

    n.openCash(0);
    n.renameRegister('  Mostrador ');
    expect(app.read(storeProvider).registerName, 'Mostrador');
    expect(app.read(storeProvider).openSession!.name, 'Mostrador'); // la caja abierta también
    expect(sessionToRemote(app.read(storeProvider).openSession!)['register_name'], 'Mostrador');
    expect(app.read(storeProvider).cutsOn(DateTime.now()).single.name, 'Mostrador');
    await n.flush();
    app.dispose();

    app = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(await repo.load())],
    );
    addTearDown(app.dispose);
    expect(app.read(storeProvider).registerName, 'Mostrador');
    expect(app.read(storeProvider).openSession!.name, 'Mostrador');

    app.read(storeProvider.notifier).renameRegister('');
    expect(app.read(storeProvider).registerName, isNull);
  });
}
