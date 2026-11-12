import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/app.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/domain/profit.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ganancia: margen de un producto, resumen del turno y el corte en pantalla.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  SaleLine line(String name, {required int price, required int cost, double qty = 1, String? id}) =>
      SaleLine(key: id ?? name, productId: id ?? name, name: name, unitCents: price, unitCostCents: cost, qty: qty);

  Sale sale(List<SaleLine> lines) => Sale(
    id: 's${lines.hashCode}',
    folio: 1,
    createdAt: DateTime(2026, 11, 12),
    lines: lines,
    kind: SaleKind.pagada,
    sessionId: 'c1',
    method: PayMethod.efectivo,
  );

  test('margen sobre el precio', () {
    expect(marginPct(priceCents: 1800, costCents: 1350), 0.25);
    expect(marginPct(priceCents: 1000, costCents: 1200), -0.2);
    expect(marginPct(priceCents: 1800, costCents: 0), isNull); // sin costo no se sabe
  });

  test('el turno junta cada producto y separa lo que no tiene costo', () {
    final report = profitOf([
      sale([line('Coca', price: 1800, cost: 1350, qty: 2), line('Pan', price: 800, cost: 0)]),
      sale([line('Coca', price: 1800, cost: 1350), line('Jabón', price: 1500, cost: 1600)]),
      sale([const SaleLine(key: 'q', name: 'Venta rápida', unitCents: 5000, qty: 1)]),
    ]);
    final coca = report.withCost.first;
    expect(coca.name, 'Coca');
    expect(coca.qty, 3);
    expect(coca.soldCents, 5400);
    expect(coca.costCents, 4050);
    expect(coca.profitCents, 1350);
    expect(coca.margin, 0.25);

    final jabon = report.withCost.last;
    expect(jabon.profitCents, -100); // se vende abajo del costo
    expect(report.withoutCost.map((p) => p.name), containsAll(['Pan', 'Ventas rápidas por monto']));

    expect(report.soldWithCostCents, 5400 + 1500);
    expect(report.profitCents, 1350 - 100);
    expect(report.coverage, closeTo(6900 / (6900 + 800 + 5000), 1e-9));
  });

  test('cobrar una mesa guarda el costo para que su ganancia cuente', () {
    final app = ProviderContainer(
      overrides: [
        initialDataProvider.overrideWithValue(LoadedData(store: seedStore(DateTime.now()), plan: Plan.negocio)),
      ],
    );
    addTearDown(app.dispose);
    final store = app.read(storeProvider.notifier);
    store.addTables(1);
    final state = app.read(storeProvider);
    final coca = state.products.firstWhere((p) => p.name.startsWith('Coca'));
    final order = store.openOrder(tableId: state.activeTables.first.id);
    store.addOrderItem(order.id, coca);
    final sold = store.chargeOrder(order.id, kind: SaleKind.pagada, receivedCents: coca.priceCents);
    expect(sold.lines.single.unitCostCents, coca.costCents);
    expect(coca.costCents, greaterThan(0));
  });

  testWidgets('el corte muestra la ganancia de cada producto vendido', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
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
    final coca = app.read(storeProvider).products.firstWhere((p) => p.name.startsWith('Coca'));
    app
        .read(storeProvider.notifier)
        .checkout(
          lines: [
            SaleLine(
              key: coca.id,
              productId: coca.id,
              name: coca.name,
              unitCents: coca.priceCents,
              unitCostCents: coca.costCents,
              qty: 2,
            ),
          ],
          kind: SaleKind.pagada,
          method: PayMethod.efectivo,
          receivedCents: coca.priceCents * 2,
        );

    await tester.tap(find.text('Caja').last);
    await tester.pumpAndSettle();
    expect(find.text('GANANCIA DEL TURNO'), findsOneWidget);
    await tester.scrollUntilVisible(find.text(coca.name), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text(coca.name), findsWidgets);
    expect(find.textContaining('vendidos · venta'), findsWidgets);
  });
}
