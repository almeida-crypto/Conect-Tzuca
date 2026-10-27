import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
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

  static Future<Phone> open(FakeServer server) async {
    final db = GavilanDb(NativeDatabase.memory());
    final repo = DriftRepository(db);
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

  Future<Phone> phone() async {
    final p = await Phone.open(server);
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
    expect(b.state.nextFolio, a.state.nextFolio);

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

  test('sin sesión no se anota nada para subir', () async {
    final a = await phone();
    await _setUpShop(a);
    expect(await a.repo.pendingCount(), 0);
  });
}
