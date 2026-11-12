import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/app.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/remote_mapping.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';
import 'package:gavilan/ui/caja/sales_screen.dart';
import 'package:gavilan/ui/cobrar/ticket_screen.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cancelar una venta: inventario, caja, fiado, sincronización y pantalla.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

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

  test('venta en efectivo: regresa al inventario y deja de contar en la caja y la ganancia', () {
    final app = demo();
    final n = app.read(storeProvider.notifier);
    StoreState s() => app.read(storeProvider);
    final coca = s().products.firstWhere((p) => p.name.startsWith('Coca'));
    final cashBefore = s().summaryFor(s().openSession!).expectedCashCents;
    final profitBefore = s().profitFor(s().openSession!).profitCents;

    final sale = n.checkout(lines: [lineOf(coca, 2)], kind: SaleKind.pagada, method: PayMethod.efectivo);
    expect(s().productById(coca.id)!.stock, coca.stock - 2);
    expect(s().summaryFor(s().openSession!).expectedCashCents, cashBefore + coca.priceCents * 2);

    final cancelled = n.cancelSale(sale.id, reason: 'Se cobró mal');
    expect(cancelled!.cancelled, isTrue);
    expect(cancelled.cancelReason, 'Se cobró mal');
    expect(s().productById(coca.id)!.stock, coca.stock);
    expect(s().summaryFor(s().openSession!).expectedCashCents, cashBefore);
    expect(s().profitFor(s().openSession!).profitCents, profitBefore);
    expect(n.cancelSale(sale.id, reason: 'otra vez'), isNull); // no se cancela dos veces
  });

  test('venta fiada: se le quita la deuda al cliente sin contar como abono', () {
    final app = demo();
    final n = app.read(storeProvider.notifier);
    StoreState s() => app.read(storeProvider);
    final pan = s().products.firstWhere((p) => p.name.startsWith('Pan'));
    final cliente = n.addCustomer('Doña Rosa');
    final sale = n.checkout(lines: [lineOf(pan, 5)], kind: SaleKind.fiada, customerId: cliente.id);
    expect(s().balanceOf(cliente.id), pan.priceCents * 5);
    final abonosBefore = s().summaryFor(s().openSession!).cashAbonosCents;

    n.cancelSale(sale.id, reason: 'El cliente se arrepintió');
    expect(s().balanceOf(cliente.id), 0);
    expect(s().credit.last.type, CreditType.cancelacion);
    expect(s().summaryFor(s().openSession!).cashAbonosCents, abonosBefore);
    expect(s().summaryFor(s().openSession!).creditSalesCents, 0);
  });

  test('una venta de un turno ya cerrado no se cancela', () {
    final app = demo();
    final n = app.read(storeProvider.notifier);
    final pan = app.read(storeProvider).products.firstWhere((p) => p.name.startsWith('Pan'));
    final sale = n.checkout(lines: [lineOf(pan, 1)], kind: SaleKind.pagada, method: PayMethod.efectivo);
    n.closeCash(0);
    expect(n.cancelSale(sale.id, reason: 'tarde'), isNull);
  });

  test('la cancelación viaja a Supabase y regresa igual', () {
    final sale = Sale(
      id: 's1',
      folio: 7,
      createdAt: DateTime.utc(2026, 11, 12, 10),
      lines: const [SaleLine(key: 'k', name: 'Pan', unitCents: 800, qty: 1)],
      kind: SaleKind.fiada,
      sessionId: 'c1',
      customerId: 'cliente',
    ).cancel(DateTime.utc(2026, 11, 12, 11), 'Se cobró mal');
    final row = saleToRemote(sale).first.rows.single;
    expect(row['status'], 'cancelled');
    expect(row['notes'], 'Se cobró mal');

    final back = saleFromRemote({...row, 'updated_at': '2026-11-12T11:00:00Z'});
    expect(back.kind, SaleKind.fiada); // sin forma de pago y con cliente: era fiada
    expect(back.cancelReason, 'Se cobró mal');
    expect(back.cancelledAt, isNotNull);

    final reversal = CreditEntry(
      id: 'r1',
      customerId: 'cliente',
      type: CreditType.cancelacion,
      amountCents: 800,
      createdAt: DateTime.utc(2026, 11, 12, 11),
    );
    expect(creditToRemote(reversal)['type'], 'reversal');
    expect(creditFromRemote(creditToRemote(reversal)).type, CreditType.cancelacion);
  });

  test('la venta cancelada se conserva al reabrir', () async {
    final db = GavilanDb(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftRepository(db);
    Future<ProviderContainer> open() async => ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(await repo.load())],
    );
    var app = await open();
    final n = app.read(storeProvider.notifier)..loadDemo();
    final p1 = app.read(storeProvider).productById('p1')!;
    final sale = n.checkout(lines: [lineOf(p1, 1)], kind: SaleKind.pagada, method: PayMethod.efectivo);
    n.cancelSale(sale.id, reason: 'Producto en mal estado');
    await n.flush();
    app.dispose();

    app = await open();
    addTearDown(app.dispose);
    final again = app.read(storeProvider).sales.firstWhere((s) => s.id == sale.id);
    expect(again.cancelled, isTrue);
    expect(again.cancelReason, 'Producto en mal estado');
    expect(app.read(storeProvider).productById('p1')!.stock, p1.stock);
  });

  testWidgets('desde Caja: ventas del turno, abrir el ticket y cancelarlo', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialDataProvider.overrideWithValue(LoadedData(store: seedStore(DateTime.now()), plan: Plan.semilla)),
        ],
        child: const GavilanApp(showSplash: false),
      ),
    );
    await tester.pump();
    final app = ProviderScope.containerOf(tester.element(find.byType(GavilanApp)));
    final pan = app.read(storeProvider).products.firstWhere((p) => p.name.startsWith('Pan'));
    final sale = app
        .read(storeProvider.notifier)
        .checkout(lines: [lineOf(pan, 3)], kind: SaleKind.pagada, method: PayMethod.efectivo);

    await tester.tap(find.text('Caja').last);
    await tester.pumpAndSettle();
    final button = find.textContaining('Ventas del turno');
    await tester.scrollUntilVisible(button, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(SalesScreen), findsOneWidget);

    final row = find.ancestor(of: find.text('3 ${pan.name}').first, matching: find.byType(InkWell)).first;
    tester.widget<InkWell>(row).onTap!();
    await tester.pumpAndSettle();
    expect(find.byType(TicketScreen), findsOneWidget);

    // TextButton: se llama directo (en pruebas, el efecto de toque de Flutter 3.47 falla al cargar).
    final cancel = find.ancestor(of: find.text('Cancelar esta venta'), matching: find.byType(TextButton));
    await tester.ensureVisible(cancel);
    tester.widget<TextButton>(cancel).onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('¿Cancelar la venta ${sale.folioLabel}?'), findsOneWidget);
    final yes = find.ancestor(of: find.text('Sí, cancelar'), matching: find.byType(TextButton));
    tester.widget<TextButton>(yes).onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('CANCELADA'), findsWidgets);
    expect(find.text('Cancelar esta venta'), findsNothing);
    expect(app.read(storeProvider).sales.firstWhere((s) => s.id == sale.id).cancelReason, 'Se cobró mal');
  });
}
