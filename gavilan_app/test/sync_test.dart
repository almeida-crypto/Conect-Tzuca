import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/data/sync_remote.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/restaurant.dart';
import 'package:gavilan/domain/team.dart';
import 'package:gavilan/state/store.dart';
import 'package:gavilan/state/sync.dart';

import 'fake_server.dart';

/// Un teléfono: su propia base SQLite y su sesión contra el servidor simulado.
class Phone {
  Phone._(this.db, this.repo, this.remote, this.app);

  final GavilanDb db;
  final DriftRepository repo;
  final FakeRemote remote;
  final ProviderContainer app;

  static Future<Phone> open(FakeServer server, {String? device}) async {
    final db = GavilanDb(NativeDatabase.memory());
    final repo = DriftRepository(db, deviceCode: device);
    final remote = FakeRemote(server);
    final loaded = await repo.load();
    final app = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        initialDataProvider.overrideWithValue(loaded),
        syncRemoteProvider.overrideWithValue(remote),
        watchConnectivityProvider.overrideWithValue(false),
      ],
    );
    app.read(syncProvider); // arranca el motor
    await Future<void>.delayed(Duration.zero);
    return Phone._(db, repo, remote, app);
  }

  StoreNotifier get store => app.read(storeProvider.notifier);
  StoreState get state => app.read(storeProvider);
  SyncController get sync => app.read(syncProvider.notifier);
  SyncStatus get status => app.read(syncProvider);

  Future<void> settle() async {
    await store.flush();
    await sync.syncNow();
    await store.flush();
  }

  Future<LinkOutcome> login(String user) async {
    await sync.signIn(user, 'secreta1');
    return sync.ensureLinked();
  }

  Sale sell(String productId, double qty, {SaleKind kind = SaleKind.pagada, String? customerId}) {
    final p = state.productById(productId)!;
    return store.checkout(
      lines: [SaleLine(key: p.id, productId: p.id, name: p.name, unitCents: p.priceCents, qty: qty)],
      kind: kind,
      method: PayMethod.efectivo,
      receivedCents: kind == SaleKind.pagada ? p.priceCents * qty.toInt() : null,
      customerId: customerId,
    );
  }

  int expectedCash() => state.summaryFor(state.openSession!).expectedCashCents;

  Future<void> close() async {
    await store.flush();
    app.dispose();
    await db.close();
  }
}

/// Un negocio con un producto, caja abierta, una venta, un fiado, un abono y un gasto.
Future<String> _setUpShop(Phone p) async {
  p.store.startBusiness('Tienda La Esperanza');
  p.store.saveProduct(const Product(id: 'coca', name: 'Coca', priceCents: 1800, trackStock: true, stock: 24));
  p.store.openCash(50000);
  p.sell('coca', 2);
  final c = p.store.addCustomer('Doña Lupe');
  p.sell('coca', 1, kind: SaleKind.fiada, customerId: c.id);
  p.store.addAbono(c.id, 1000, PayMethod.efectivo);
  p.store.addMovement(CashKind.gasto, 3000, 'Hielo');
  await p.store.flush();
  return c.id;
}

void main() {
  late FakeServer server;
  final phones = <Phone>[];

  Future<Phone> phone({String? device}) async {
    final p = await Phone.open(server, device: device);
    phones.add(p);
    return p;
  }

  setUp(() => server = FakeServer());
  tearDown(() async {
    for (final p in phones) {
      await p.close();
    }
    phones.clear();
  });

  test('al entrar, el negocio del teléfono se sube completo', () async {
    final a = await phone();
    final lupe = await _setUpShop(a);
    expect(a.status.linked, isFalse);

    final outcome = await a.login('mary@correo.mx');
    await a.settle();

    expect(outcome.result, LinkResult.uploaded);
    expect(a.status.pending, 0);
    expect(a.status.problem, isNull);
    final bid = a.state.businessId;
    expect(server.table('businesses')[bid]!['name'], 'Tienda La Esperanza');
    // Sube con la existencia actual; las ventas viejas no vuelven a descontar.
    expect(server.table('products')['coca']!['stock_qty'], 21);
    expect(server.rows('sales'), hasLength(2));
    expect(server.rows('sale_items'), hasLength(2));
    expect(server.rows('inventory_movements'), isEmpty);
    expect(server.rows('credit_entries').where((e) => e['customer_id'] == lupe), hasLength(2));
    expect(server.rows('cash_movements').single['amount'], 30);
    expect(server.rows('sales').every((s) => s['business_id'] == bid), isTrue);
  });

  test('otro teléfono baja el negocio y después ve las ventas nuevas', () async {
    final a = await phone();
    final lupe = await _setUpShop(a);
    await a.login('mary@correo.mx');
    await a.settle();

    final b = await phone();
    final outcome = await b.login('mary@correo.mx');
    expect(outcome.result, LinkResult.downloaded);
    expect(b.state.businessName, 'Tienda La Esperanza');
    expect(b.state.businessId, a.state.businessId);
    expect(b.state.productById('coca')!.stock, 21);
    expect(b.state.sales, hasLength(2));
    expect(b.state.balanceOf(lupe), 800);
    expect(b.expectedCash(), a.expectedCash());
    expect(b.state.nextFolio, 1); // cada teléfono numera lo suyo

    // A vende sin internet; al volver la señal sube y B lo baja.
    a.remote.offline = true;
    a.sell('coca', 5);
    await a.settle();
    expect(a.status.pending, 1);
    expect(a.status.online, isFalse);

    a.remote.offline = false;
    await a.sync.syncNow();
    expect(a.status.pending, 0);
    await b.settle();
    expect(b.state.sales, hasLength(3));
    expect(b.state.productById('coca')!.stock, 16);
    expect(b.expectedCash(), a.expectedCash());
  });

  test('dos teléfonos venden sin internet y la existencia cuadra', () async {
    final a = await phone();
    await _setUpShop(a);
    await a.login('mary@correo.mx');
    await a.settle();
    final b = await phone();
    await b.login('mary@correo.mx');

    a.remote.offline = true;
    b.remote.offline = true;
    a.sell('coca', 4);
    b.sell('coca', 3);
    await a.settle();
    await b.settle();
    a.remote.offline = false;
    b.remote.offline = false;

    await a.settle();
    await b.settle();
    await a.settle();

    expect(server.table('products')['coca']!['stock_qty'], 21 - 4 - 3);
    expect(a.state.productById('coca')!.stock, 14);
    expect(b.state.productById('coca')!.stock, 14);
    expect(a.state.sales, hasLength(4));
    expect(b.state.sales, hasLength(4));
  });

  test('cada teléfono lleva sus propios folios y no chocan', () async {
    final a = await phone(device: 'K7');
    await _setUpShop(a);
    await a.login('mary@correo.mx');
    await a.settle();
    final b = await phone(device: 'R3');
    await b.login('mary@correo.mx');

    a.remote.offline = true;
    b.remote.offline = true;
    final fromA = a.sell('coca', 1);
    final fromB = b.sell('coca', 1);
    expect(fromB.folio, 1); // B empieza su propia numeración
    expect(fromA.folioLabel, isNot(fromB.folioLabel));
    expect(fromA.folioLabel, startsWith('K7-'));
    expect(fromB.folioLabel, startsWith('R3-'));

    a.remote.offline = false;
    b.remote.offline = false;
    await a.settle();
    await b.settle();
    await a.settle();
    expect(server.rows('sales').where((s) => s['device_id'] == 'R3'), hasLength(1));
    // Lo que vendió B no adelanta la numeración de A.
    final next = a.sell('coca', 1);
    await a.store.flush();
    expect(next.folio, fromA.folio + 1);
    expect(a.state.sales.firstWhere((s) => s.id == fromB.id).folioLabel, fromB.folioLabel);
  });

  test('la tiendita de ejemplo nunca se sube', () async {
    final a = await phone();
    a.store.loadDemo();
    await a.store.flush();

    final outcome = await a.login('nuevo@correo.mx');
    expect(outcome.result, LinkResult.needsBusiness);
    expect(server.writes, 0);
    expect(a.status.linked, isFalse);
  });

  test('con sesión iniciada, un negocio nuevo se da de alta en la nube', () async {
    final a = await phone();
    expect((await a.login('nuevo@correo.mx')).result, LinkResult.needsBusiness);
    a.store.startBusiness('Paletería El Oasis');
    expect((await a.sync.ensureLinked()).result, LinkResult.uploaded);
    expect(server.table('businesses')[a.state.businessId]!['name'], 'Paletería El Oasis');
  });

  test('si la cuenta tiene otro negocio, se pregunta y luego se reemplaza', () async {
    final a = await phone();
    await _setUpShop(a);
    await a.login('mary@correo.mx');
    await a.settle();

    final c = await phone();
    c.store.startBusiness('Otro negocio');
    await c.store.flush();
    final outcome = await c.login('mary@correo.mx');
    expect(outcome.result, LinkResult.conflict);
    expect(outcome.remoteName, 'Tienda La Esperanza');
    expect(c.state.businessName, 'Otro negocio');

    await c.sync.downloadBusiness(outcome.remoteId!, outcome.remoteName!);
    expect(c.state.businessName, 'Tienda La Esperanza');
    expect(c.state.sales, hasLength(2));
  });

  test('si el servidor rechaza un cambio, se detiene sin perder nada', () async {
    final a = await phone();
    await _setUpShop(a);
    await a.login('mary@correo.mx');
    await a.settle();

    server.rejectTables.add('sales');
    a.sell('coca', 1);
    a.store.addMovement(CashKind.gasto, 500, 'Bolsas');
    await a.settle();
    expect(a.status.problem, contains('rechazado'));
    expect(a.status.pending, 2);
    expect(server.rows('cash_movements'), hasLength(1));

    server.rejectTables.clear();
    await a.settle();
    expect(a.status.pending, 0);
    expect(a.status.problem, isNull);
    expect(server.rows('sales'), hasLength(3));
    expect(server.rows('cash_movements'), hasLength(2));
  });

  test('pacas, apartados y tandas se suben y otro teléfono los baja', () async {
    final a = await phone();
    final lupe = await _setUpShop(a);
    final lot = a.store.addLot('Paca americana', 350000);
    a.store.addLotSale(lot.id, 50000);
    final apartado = a.store.addLayaway(
      customerId: lupe,
      description: 'Vestido',
      totalCents: 60000,
      depositCents: 20000,
      dueDate: DateTime(2026, 12, 1),
    );
    final tanda = a.store.addBatch('Cochinita', DateTime(2026, 11, 1));
    a.store.addBatchOrder(batchId: tanda.id, customerName: 'Pedro', totalCents: 9000);
    await a.store.flush();

    expect((await a.login('mary@correo.mx')).result, LinkResult.uploaded);
    await a.settle();
    expect(a.status.pending, 0);
    expect(server.rows('lots').single['investment'], 3500);
    expect(server.rows('lot_sales').single['cash_session_id'], a.state.openSession!.id);
    expect(server.rows('layaways').single['due_date'], '2026-12-01');
    expect(server.rows('layaway_payments').single['amount'], 200);
    expect(server.rows('batch_orders').single['pay_status'], 'unpaid');

    final b = await phone();
    await b.login('mary@correo.mx');
    expect(b.state.recoveredOfLot(lot.id), 50000);
    expect(b.state.pendingOfLayaway(apartado.id), 40000);
    expect(b.state.layawayById(apartado.id)!.dueDate, DateTime(2026, 12, 1));
    expect(b.state.ordersOfBatch(tanda.id).single.customerName, 'Pedro');
    expect(b.expectedCash(), a.expectedCash());

    // Un abono que liquida en A llega a B como liquidado.
    a.store.addLayawayPayment(apartado.id, 40000, PayMethod.efectivo);
    final order = b.state.ordersOfBatch(tanda.id).single;
    b.store.updateBatchOrder(order.copyWith(paid: true));
    await a.settle();
    await b.settle();
    await a.settle();
    expect(b.state.layawayById(apartado.id)!.status, LayawayStatus.liquidado);
    expect(a.state.ordersOfBatch(tanda.id).single.paid, isTrue);
  });

  test('los enlaces del correo abren la sesión en la app', () async {
    final a = await phone();
    await _setUpShop(a);

    expect(await a.sync.openLink(Uri.parse('https://gavilan.mx/otra-cosa')), isNull);

    final confirmed = await a.sync.openLink(Uri.parse('mx.gavilan.gavilan://auth/confirmado?code=mary@correo.mx'));
    expect(confirmed, AuthLink.confirmed);
    expect(a.status.email, 'mary@correo.mx');
    expect((await a.sync.ensureLinked()).result, LinkResult.uploaded);

    await a.sync.signOut();
    await a.sync.sendPasswordReset('mary@correo.mx');
    expect(a.remote.resets, ['mary@correo.mx']);
    final recovery = await a.sync.openLink(Uri.parse('mx.gavilan.gavilan://auth/nueva-clave?code=mary@correo.mx'));
    expect(recovery, AuthLink.newPassword);
    await a.sync.updatePassword('nueva123');
    expect(a.remote.password, 'nueva123');

    // Abierto en otro celular: el correo se confirma, pero hay que entrar con la contraseña.
    await a.sync.signOut();
    expect(await a.sync.openLink(Uri.parse('mx.gavilan.gavilan://auth/confirmado')), AuthLink.confirmedSignIn);
    expect(a.status.signedIn, isFalse);
  });

  test('un cajero se une con código, vende y no puede cambiar el catálogo', () async {
    final owner = await phone(device: 'K7');
    await _setUpShop(owner);
    await owner.login('mary@correo.mx');
    await owner.settle();
    expect(owner.status.role, MemberRole.owner);
    expect(owner.app.read(permissionsProvider).manageTeam, isTrue);

    final code = await owner.sync.createInvite(MemberRole.cashier, 'Juan');
    expect((await owner.sync.invites()).single.role, MemberRole.cashier);

    final cashier = await phone(device: 'R3');
    cashier.store.loadDemo();
    await cashier.sync.signIn('juan@correo.mx', 'secreta1');
    final outcome = await cashier.sync.joinWithCode(formatInviteCode(code));
    expect(outcome.result, LinkResult.downloaded);
    expect(cashier.state.businessName, 'Tienda La Esperanza');
    expect(cashier.status.role, MemberRole.cashier);
    final can = cashier.app.read(permissionsProvider);
    expect(can.editCatalog, isFalse);
    expect(can.manageTeam, isFalse);
    expect(await owner.sync.invites(), isEmpty); // el código ya se usó

    final sale = cashier.sell('coca', 2);
    await cashier.settle();
    await owner.settle();
    expect(cashier.status.pending, 0);
    expect(owner.state.sales.any((s) => s.id == sale.id), isTrue);
    expect(owner.state.productById('coca')!.stock, 19);

    // Un código ya usado no sirve otra vez.
    final other = await phone();
    await other.sync.signIn('pedro@correo.mx', 'secreta1');
    expect(() => other.sync.joinWithCode(code), throwsA(isA<SyncException>()));

    expect(await owner.sync.members(), hasLength(2));
    await owner.sync.removeMember('juan@correo.mx');
    expect((await owner.sync.members()).single.role, MemberRole.owner);
  });

  test('el mesero manda la comanda y la cocina la recibe sola', () async {
    final waiter = await phone(device: 'K7');
    await _setUpShop(waiter);
    waiter.store.addTables(4);
    await waiter.login('mary@correo.mx');
    await waiter.settle();

    final kitchen = await phone(device: 'R3');
    await kitchen.login('mary@correo.mx');
    expect(kitchen.state.activeTables, hasLength(4));

    final mesa = waiter.state.activeTables[2];
    final order = waiter.store.openOrder(tableId: mesa.id);
    waiter.store.addOrderItem(order.id, waiter.state.productById('coca')!, notes: 'sin hielo');
    waiter.store.sendToKitchen(order.id);
    await waiter.settle();

    // Sin tocar nada en cocina: el aviso de Realtime baja la comanda.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await kitchen.store.flush();
    final queued = kitchen.state.kitchenOrders.single;
    expect(kitchen.state.orderTitle(queued), mesa.name);
    final item = kitchen.state.kitchenItemsOf(queued.id).single;
    expect(item.notes, 'sin hielo');

    kitchen.store.setItemStatus(item.id, KitchenStatus.listo);
    await kitchen.settle();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await waiter.store.flush();
    expect(waiter.state.itemsOfOrder(order.id).single.status, KitchenStatus.listo);

    final sale = waiter.store.chargeOrder(order.id, kind: SaleKind.pagada, receivedCents: 1800);
    await waiter.settle();
    expect(server.table('sales')[sale.id]!['order_id'], order.id);
    expect(server.table('orders')[order.id]!['status'], 'closed');
  });

  test('sin sesión no se anota nada para subir', () async {
    final a = await phone();
    await _setUpShop(a);
    expect(await a.repo.pendingCount(), 0);
  });
}
