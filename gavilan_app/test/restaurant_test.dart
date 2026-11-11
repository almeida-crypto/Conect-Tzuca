import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/domain/restaurant.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';

void main() {
  late ProviderContainer app;
  StoreNotifier store() => app.read(storeProvider.notifier);
  StoreState state() => app.read(storeProvider);
  Product product(String name) => state().products.firstWhere((p) => p.name.startsWith(name));

  setUp(
    () => app = ProviderContainer(
      overrides: [
        initialDataProvider.overrideWithValue(LoadedData(store: seedStore(DateTime.now()), plan: Plan.negocio)),
      ],
    ),
  );
  tearDown(() => app.dispose());

  test('mesas numeradas en orden', () {
    store().addTables(3);
    store().addTables(2);
    expect(state().activeTables.map((t) => t.name), ['Mesa 1', 'Mesa 2', 'Mesa 3', 'Mesa 4', 'Mesa 5']);
    store().removeTable(state().activeTables.first.id);
    store().renameTable(state().activeTables.first.id, 'Terraza');
    expect(state().activeTables.map((t) => t.name), ['Terraza', 'Mesa 3', 'Mesa 4', 'Mesa 5']);
    store().addTables(1); // no repite "Mesa 5"
    expect(state().activeTables.last.name, 'Mesa 6');
  });

  test('zonas: cada una con su numeración, agrupadas y con nombre completo en cocina', () {
    store().addTables(2);
    store().addTables(2, zone: 'Terraza');
    store().addTables(1, zone: 'Segunda planta');
    store().addTables(1, zone: 'Terraza');
    expect(state().zones, [null, 'Terraza', 'Segunda planta']);
    expect(state().tablesIn('Terraza').map((t) => t.name), ['Mesa 1', 'Mesa 2', 'Mesa 3']);
    expect(state().tablesIn(null).map((t) => t.name), ['Mesa 1', 'Mesa 2']);
    // Agrupadas: primero sin zona, luego cada zona en el orden en que se creó.
    expect(state().activeTables.map((t) => t.fullName), [
      'Mesa 1',
      'Mesa 2',
      'Mesa 1 · Terraza',
      'Mesa 2 · Terraza',
      'Mesa 3 · Terraza',
      'Mesa 1 · Segunda planta',
    ]);

    final terraza = state().tablesIn('Terraza').first;
    final order = store().openOrder(tableId: terraza.id);
    expect(state().orderTitle(order), 'Mesa 1 · Terraza');

    // Cambiar de zona y quitar la zona.
    store().moveTable(terraza.id, 'Segunda planta');
    expect(state().tablesIn('Segunda planta'), hasLength(2));
    store().moveTable(terraza.id, '  ');
    expect(state().tableById(terraza.id)!.zone, isNull);
  });

  test('comanda: anotar, mandar a cocina, preparar, servir y cobrar', () {
    store().addTables(2);
    final mesa = state().activeTables.first;
    final order = store().openOrder(tableId: mesa.id);
    expect(store().openOrder(tableId: mesa.id).id, order.id); // la misma cuenta, no otra

    final coca = product('Coca');
    store().addOrderItem(order.id, coca);
    store().addOrderItem(order.id, coca); // se junta: 2 cocas
    store().addOrderItem(order.id, coca, notes: 'sin hielo'); // otra nota, otro renglón
    expect(state().itemsOfOrder(order.id), hasLength(2));
    expect(state().itemsOfOrder(order.id).first.qty, 2);
    expect(state().kitchenOrders, isEmpty); // nada enviado todavía

    expect(store().sendToKitchen(order.id), 2);
    expect(state().kitchenOrders.single.id, order.id);
    expect(store().sendToKitchen(order.id), 0); // no se manda dos veces

    // Lo que se agrega después sale en otra tanda a cocina.
    final pan = store().addOrderItem(order.id, product('Pan'));
    expect(state().itemsOfOrder(order.id).where((i) => !i.sent), hasLength(1));
    store().sendToKitchen(order.id);

    final first = state().itemsOfOrder(order.id).first;
    store().setItemStatus(first.id, KitchenStatus.preparando);
    store().markOrderReady(order.id);
    expect(state().kitchenItemsOf(order.id).every((i) => i.status == KitchenStatus.listo), isTrue);
    for (final i in state().kitchenItemsOf(order.id)) {
      store().setItemStatus(i.id, KitchenStatus.servido);
    }
    expect(state().kitchenOrders, isEmpty);
    expect(state().itemsOfOrder(order.id).firstWhere((i) => i.id == pan.id).servedAt, isNotNull);

    final total = state().totalOfOrder(order.id);
    expect(total, coca.priceCents * 3 + product('Pan').priceCents);
    final cashBefore = state().summaryFor(state().openSession!).expectedCashCents;
    final sale = store().chargeOrder(order.id, kind: SaleKind.pagada, method: PayMethod.efectivo, receivedCents: total);
    expect(sale.orderId, order.id);
    expect(sale.totalCents, total);
    expect(state().orderById(order.id)!.status, OrderStatus.cerrada);
    expect(state().openOrderOfTable(mesa.id), isNull); // la mesa queda libre
    expect(state().summaryFor(state().openSession!).expectedCashCents, cashBefore + total);
  });

  test('cancelar un platillo antes de mandarlo y cancelar la cuenta', () {
    final order = store().openOrder(label: 'Juan');
    expect(state().orderTitle(order), 'Para llevar · Juan');
    final item = store().addOrderItem(order.id, product('Coca'));
    store().setItemQty(item.id, 0);
    expect(state().totalOfOrder(order.id), 0);
    expect(store().sendToKitchen(order.id), 0);

    store().addOrderItem(order.id, product('Pan'));
    store().sendToKitchen(order.id);
    store().cancelOrder(order.id);
    expect(state().orderById(order.id)!.status, OrderStatus.cancelada);
    expect(state().kitchenOrders, isEmpty);
  });

  test('el restaurante se guarda en el teléfono y vuelve al abrir', () async {
    final db = GavilanDb(NativeDatabase.memory());
    final repo = DriftRepository(db);
    var phone = ProviderContainer(overrides: [repositoryProvider.overrideWithValue(repo)]);
    final n = phone.read(storeProvider.notifier);
    n.loadDemo();
    n.addTables(2);
    n.addTables(1, zone: 'Terraza');
    final mesa = phone.read(storeProvider).tablesIn(null).last;
    final order = n.openOrder(tableId: mesa.id);
    final coca = phone.read(storeProvider).products.first;
    n.addOrderItem(order.id, coca, notes: 'bien fría');
    n.sendToKitchen(order.id);
    await n.flush();
    phone.dispose();

    phone = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(await repo.load())],
    );
    final s = phone.read(storeProvider);
    expect(s.activeTables.map((t) => t.fullName), ['Mesa 1', 'Mesa 2', 'Mesa 1 · Terraza']);
    expect(s.openOrderOfTable(mesa.id)!.id, order.id);
    final item = s.itemsOfOrder(order.id).single;
    expect(item.notes, 'bien fría');
    expect(item.sent, isTrue);
    expect(s.kitchenOrders.single.id, order.id);

    final sale = phone
        .read(storeProvider.notifier)
        .chargeOrder(order.id, kind: SaleKind.pagada, receivedCents: coca.priceCents);
    await phone.read(storeProvider.notifier).flush();
    phone.dispose();
    final again = (await repo.load())!.store;
    expect(again.sales.firstWhere((x) => x.id == sale.id).orderId, order.id);
    await db.close();
  });
}
