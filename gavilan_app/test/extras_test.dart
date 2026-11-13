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

/// Extras con precio en el restaurante.
void main() {
  late ProviderContainer app;
  StoreNotifier n() => app.read(storeProvider.notifier);
  StoreState s() => app.read(storeProvider);
  Product p(String start) => s().products.firstWhere((x) => x.name.startsWith(start));

  setUp(
    () => app = ProviderContainer(
      overrides: [
        initialDataProvider.overrideWithValue(LoadedData(store: seedStore(DateTime.now()), plan: Plan.negocio)),
      ],
    ),
  );
  tearDown(() => app.dispose());

  test('alta, cambio y baja de extras', () {
    final e = n().saveExtra(name: ' Salsa macha ', priceCents: 800);
    expect(s().activeExtras.map((x) => x.name), contains('Salsa macha'));
    n().saveExtra(id: e.id, name: 'Salsa macha', priceCents: 900);
    expect(s().extras.firstWhere((x) => x.id == e.id).priceCents, 900);
    n().removeExtra(e.id);
    expect(s().activeExtras.any((x) => x.id == e.id), isFalse);
  });

  test('los extras se suman a la cuenta, separan renglones y llegan al ticket', () {
    n().addTables(1);
    final order = n().openOrder(tableId: s().activeTables.first.id);
    final pan = p('Pan');
    const queso = ItemExtra('Extra queso', 1000);

    final plain = n().addOrderItem(order.id, pan);
    final withCheese = n().addOrderItem(order.id, pan, extras: const [queso]);
    expect(withCheese.id, isNot(plain.id)); // con extra es otro renglón
    n().addOrderItem(order.id, pan, extras: const [queso]); // se junta con el de queso
    expect(s().itemsOfOrder(order.id).firstWhere((i) => i.id == withCheese.id).qty, 2);

    expect(s().totalOfOrder(order.id), pan.priceCents * 3 + 1000 * 2);

    // Agregarle el extra al renglón sencillo desde la hoja de indicaciones.
    n().setItemDetails(plain.id, notes: 'bien dorado', extras: const [queso]);
    expect(s().totalOfOrder(order.id), (pan.priceCents + 1000) * 3);
    n().setItemNotes(plain.id, 'sin azúcar'); // cambiar solo las notas no quita el extra
    expect(s().itemsOfOrder(order.id).firstWhere((i) => i.id == plain.id).extras, [queso]);

    final sale = n().chargeOrder(order.id, kind: SaleKind.pagada, receivedCents: 100000);
    expect(sale.totalCents, (pan.priceCents + 1000) * 3);
    expect(sale.lines.first.name, '${pan.name} (extra queso)');
    expect(sale.lines.first.unitCents, pan.priceCents + 1000);
  });

  test('los extras viajan a Supabase y regresan', () {
    final item = OrderItem(
      id: 'i1',
      orderId: 'o1',
      name: 'Tacos',
      qty: 2,
      unitCents: 2500,
      extras: const [ItemExtra('Extra queso', 1000)],
      createdAt: DateTime.utc(2026, 11, 13),
    );
    final row = orderItemToRemote(item);
    expect(row['extras'], [
      {'name': 'Extra queso', 'price': 10.0},
    ]);
    expect(extrasFromJson(orderItemFromRemote(row).extras), [const ItemExtra('Extra queso', 1000)]);

    const extra = Extra(id: 'x', name: 'Doble carne', priceCents: 2000);
    final back = extraFromRemote(extraToRemote(extra));
    expect((back.name, back.priceCents, back.active), ('Doble carne', 2000, true));
  });

  test('extras y platillos con extras se conservan al reabrir', () async {
    final db = GavilanDb(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftRepository(db);
    Future<ProviderContainer> open() async => ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(await repo.load())],
    );
    var c = await open();
    final store = c.read(storeProvider.notifier)..loadDemo();
    store.saveExtra(name: 'Aguacate', priceCents: 1500);
    store.addTables(1);
    final order = store.openOrder(tableId: c.read(storeProvider).activeTables.first.id);
    final item = store.addOrderItem(
      order.id,
      c.read(storeProvider).products.first,
      extras: const [ItemExtra('Aguacate', 1500)],
    );
    await store.flush();
    c.dispose();

    c = await open();
    addTearDown(c.dispose);
    expect(c.read(storeProvider).activeExtras.map((e) => e.name), contains('Aguacate'));
    expect(c.read(storeProvider).orderItems.firstWhere((i) => i.id == item.id).extras, [
      const ItemExtra('Aguacate', 1500),
    ]);
  });
}
