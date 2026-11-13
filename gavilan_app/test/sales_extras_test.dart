import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/core/ticket_text.dart';
import 'package:gavilan/data/remote_mapping.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/domain/profit.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';

/// Descuentos, devoluciones parciales y cambiar de mesa.
void main() {
  late ProviderContainer app;
  StoreNotifier n() => app.read(storeProvider.notifier);
  StoreState s() => app.read(storeProvider);
  Product p(String start) => s().products.firstWhere((x) => x.name.startsWith(start));
  SaleLine line(Product x, double q) =>
      SaleLine(key: x.id, productId: x.id, name: x.name, unitCents: x.priceCents, unitCostCents: x.costCents, qty: q);

  setUp(
    () => app = ProviderContainer(
      overrides: [
        initialDataProvider.overrideWithValue(LoadedData(store: seedStore(DateTime.now()), plan: Plan.negocio)),
      ],
    ),
  );
  tearDown(() => app.dispose());

  test('descuento: baja el total, la caja y la ganancia, y viaja a Supabase', () {
    final coca = p('Coca');
    final cashBefore = s().summaryFor(s().openSession!).expectedCashCents;
    final sale = n().checkout(
      lines: [line(coca, 2)],
      kind: SaleKind.pagada,
      method: PayMethod.efectivo,
      discountCents: 400,
    );
    expect(sale.subtotalCents, coca.priceCents * 2);
    expect(sale.totalCents, coca.priceCents * 2 - 400);
    expect(s().summaryFor(s().openSession!).expectedCashCents, cashBefore + sale.totalCents);

    final row = profitOfSale(sale);
    expect(row, sale.totalCents);

    final remote = saleToRemote(sale).first.rows.single;
    expect(remote['subtotal'], coca.priceCents * 2 / 100);
    expect(remote['discount'], 4.0);
    expect(saleFromRemote(remote).discountCents, 400);
    expect(ticketText(business: 'X', sale: sale), contains('Descuento -\$4.00'));
  });

  test('el descuento nunca pasa del total', () {
    final pan = p('Pan');
    final sale = n().checkout(lines: [line(pan, 1)], kind: SaleKind.pagada, discountCents: 999999);
    expect(sale.totalCents, 0);
  });

  test('devolver una parte en efectivo: venta nueva con lo que se queda', () {
    final coca = p('Coca');
    final pan = p('Pan');
    final cashBefore = s().summaryFor(s().openSession!).expectedCashCents;
    final stockBefore = s().productById(coca.id)!.stock;
    final sale = n().checkout(lines: [line(coca, 3), line(pan, 2)], kind: SaleKind.pagada, method: PayMethod.efectivo);

    final kept = n().returnItems(sale.id, {0: 1}, reason: 'Producto en mal estado')!;
    expect(kept.lines.map((l) => (l.name, l.qty)), [(coca.name, 2.0), (pan.name, 2.0)]);
    expect(s().sales.firstWhere((x) => x.id == sale.id).cancelled, isTrue);
    expect(s().sales.firstWhere((x) => x.id == sale.id).cancelReason, contains(kept.folioLabel));
    expect(s().productById(coca.id)!.stock, stockBefore - 2);
    expect(s().summaryFor(s().openSession!).expectedCashCents, cashBefore + coca.priceCents * 2 + pan.priceCents * 2);
  });

  test('devolver una parte de un fiado: la deuda queda solo con lo que se llevó', () {
    final pan = p('Pan');
    final cliente = n().addCustomer('Don Pepe');
    final sale = n().checkout(lines: [line(pan, 5)], kind: SaleKind.fiada, customerId: cliente.id);
    n().returnItems(sale.id, {0: 2}, reason: 'Ya no lo quiso');
    expect(s().balanceOf(cliente.id), pan.priceCents * 3);
  });

  test('devolver todo es cancelar', () {
    final pan = p('Pan');
    final sale = n().checkout(lines: [line(pan, 2)], kind: SaleKind.pagada);
    expect(n().returnItems(sale.id, {0: 2}, reason: 'x'), isNull);
    expect(s().sales.firstWhere((x) => x.id == sale.id).cancelled, isTrue);
  });

  test('pasar la cuenta a otra mesa libre, y la mesa sale en el ticket', () {
    n().addTables(3);
    final mesas = s().activeTables;
    final order = n().openOrder(tableId: mesas[0].id);
    n().addOrderItem(order.id, p('Coca'));
    n().openOrder(tableId: mesas[1].id); // la 2 ocupada

    expect(n().moveOrder(order.id, mesas[1].id), isFalse);
    expect(n().moveOrder(order.id, mesas[2].id), isTrue);
    expect(s().openOrderOfTable(mesas[0].id), isNull);
    expect(s().openOrderOfTable(mesas[2].id)!.id, order.id);

    final sale = n().chargeOrder(order.id, kind: SaleKind.pagada, receivedCents: p('Coca').priceCents);
    final place = s().orderTitle(s().orderById(sale.orderId!)!);
    expect(place, mesas[2].fullName);
    expect(ticketText(business: 'X', sale: sale, place: place), contains(mesas[2].fullName));
  });
}

/// Lo que cuenta la ganancia como vendido para una sola venta (con el descuento repartido).
int profitOfSale(Sale sale) => profitOf([sale]).soldCents;
