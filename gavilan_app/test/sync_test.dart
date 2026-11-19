import 'dart:typed_data';

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

  /// Lo que debe haber en la caja de un turno (de este u otro celular).
  int cashOf(String sessionId) =>
      state.summaryFor(state.sessions.firstWhere((s) => s.id == sessionId)).expectedCashCents;

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
    expect(b.cashOf(a.state.openSession!.id), a.expectedCash());
    // La caja abierta es de A: B no la toma como suya.
    expect(b.state.openSession, isNull);
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
    expect(b.cashOf(a.state.openSession!.id), a.expectedCash());
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

  test('si el servidor rechaza un cambio, se aparta y lo demás sigue subiendo', () async {
    final a = await phone();
    await _setUpShop(a);
    await a.login('mary@correo.mx');
    await a.settle();

    server.rejectTables.add('sales');
    a.sell('coca', 1);
    a.store.addMovement(CashKind.gasto, 500, 'Bolsas');
    await a.settle();
    // La venta queda apartada, pero el gasto (que va después) sí sube.
    expect(a.status.failed, 1);
    expect(a.status.pending, 0);
    expect(a.status.problem, 'Un cambio no se pudo subir');
    expect(server.rows('cash_movements'), hasLength(2));
    final failed = await a.sync.failedChanges();
    expect(failed.single.what, startsWith('Venta'));
    expect(failed.single.error, contains('rechazado'));

    // Se reintenta sola unas veces; luego espera al usuario.
    await a.settle();
    await a.settle();
    expect((await a.repo.failed()).single.attempts, maxAutoRetries);
    server.rejectTables.clear();
    await a.settle();
    expect(a.status.failed, 1);
    expect(server.rows('sales'), hasLength(2));

    await a.sync.retryFailed();
    await a.store.flush();
    expect(a.status.failed, 0);
    expect(a.status.problem, isNull);
    expect(server.rows('sales'), hasLength(3));
  });

  test('los cambios apartados se explican en palabras', () {
    expect(describeChange('[{"table":"customers","rows":[]}]'), 'Cliente');
    expect(
      describeChange('[{"table":"sales"},{"table":"sale_items"},{"table":"sale_payments"}]'),
      'Venta, productos de una venta y pago de una venta',
    );
    expect(
      friendlyRejection('new row violates row-level security policy'),
      'Tu cuenta no tiene permiso para este cambio',
    );
    expect(friendlyRejection('insert violates foreign key constraint'), 'Depende de otro cambio que tampoco se subió');
    expect(friendlyRejection('Solo el dueño puede'), 'Solo el dueño puede');
  });

  test('descartar un cambio apartado deja el teléfono como la nube', () async {
    final a = await phone();
    await _setUpShop(a);
    await a.login('mary@correo.mx');
    await a.settle();
    final coca = a.state.productById('coca')!;

    server.rejectTables.add('products');
    a.store.saveProduct(coca.copyWith(priceCents: 2000));
    await a.settle();
    expect(a.status.failed, 1);
    expect(a.state.productById('coca')!.priceCents, 2000);

    final change = (await a.sync.failedChanges()).single;
    expect(change.what, 'Producto');
    await a.sync.discardFailed(change.id);
    await a.store.flush();
    expect(a.status.failed, 0);
    expect(a.status.problem, isNull);
    // Volvió a bajar el catálogo: el precio es otra vez el de la nube.
    expect(a.state.productById('coca')!.priceCents, 1800);
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
    expect(b.cashOf(a.state.openSession!.id), a.expectedCash());

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

  test('el servidor no deja que el cajero cancele ni que el mesero vea las ventas', () async {
    final owner = await phone(device: 'K7');
    await _setUpShop(owner);
    await owner.login('mary@correo.mx');
    await owner.settle();
    final business = owner.state.businessId;

    final cashier = await phone(device: 'R3');
    await cashier.sync.signIn('juan@correo.mx', 'secreta1');
    await cashier.sync.joinWithCode(await owner.sync.createInvite(MemberRole.cashier, 'Juan'));
    cashier.store.openCash(0); // cada celular abre su propia caja
    final sale = cashier.sell('coca', 1);
    await cashier.settle();
    final row = Map<String, Object?>.from(server.table('sales')[sale.id]!);

    // Volver a subir la misma venta (un reintento) sí pasa; cancelarla no.
    await cashier.remote.upsert('sales', business, [row]);
    expect(
      () => cashier.remote.upsert('sales', business, [
        {...row, 'status': 'cancelled', 'notes': 'me equivoqué'},
      ]),
      throwsA(isA<SyncException>()),
    );
    // El dueño sí cancela.
    await owner.settle();
    expect(owner.store.cancelSale(sale.id, reason: 'Se cobró mal'), isNotNull);
    await owner.settle();
    expect(owner.status.pending, 0);
    expect(server.table('sales')[sale.id]!['status'], 'cancelled');

    // El mesero baja productos y mesas, pero no ventas, cortes, fiados ni clientes.
    final waiter = await phone(device: 'M2');
    await waiter.sync.signIn('ana@correo.mx', 'secreta1');
    await waiter.sync.joinWithCode(await owner.sync.createInvite(MemberRole.waiter, 'Ana'));
    expect(waiter.state.businessName, 'Tienda La Esperanza');
    expect(waiter.state.productById('coca'), isNotNull);
    expect(waiter.state.sales, isEmpty);
    expect(waiter.state.sessions, isEmpty);
    expect(waiter.state.customers, isEmpty);
    expect(waiter.state.credit, isEmpty);
  });

  test('si el dueño saca a un empleado, su celular borra los datos del negocio', () async {
    final owner = await phone(device: 'K7');
    await _setUpShop(owner);
    await owner.login('mary@correo.mx');
    await owner.settle();

    final cashier = await phone(device: 'R3');
    await cashier.sync.signIn('juan@correo.mx', 'secreta1');
    await cashier.sync.joinWithCode(await owner.sync.createInvite(MemberRole.cashier, 'Juan'));
    cashier.sell('coca', 1);
    await cashier.settle();
    expect(cashier.state.hasBusiness, isTrue);

    // Mientras siga en el equipo no pasa nada.
    await cashier.sync.checkMembership();
    expect(cashier.state.hasBusiness, isTrue);

    await owner.sync.removeMember('juan@correo.mx');
    await cashier.sync.checkMembership();
    await cashier.store.flush();
    expect(cashier.state.hasBusiness, isFalse);
    expect(cashier.state.products, isEmpty);
    expect(cashier.repo.linkedBusinessId, isNull);
    expect(cashier.status.problem, contains('Ya no eres parte de "Tienda La Esperanza"'));
    // Al reabrir sigue vacío.
    expect(await cashier.repo.load(), isNull);
    // Al dueño no le pasa nada.
    await owner.settle();
    expect(owner.state.hasBusiness, isTrue);
    expect(owner.state.sales, hasLength(3));
  });

  test('el celular del dueño y el de otra cuenta nunca se borran solos', () async {
    final owner = await phone(device: 'K7');
    await _setUpShop(owner);
    await owner.login('mary@correo.mx');
    await owner.settle();
    // Aunque el servidor no lo encuentre (algo raro), al dueño no se le borra nada.
    server.membership['mary@correo.mx']!.clear();
    await owner.sync.checkMembership();
    await owner.store.flush();
    expect(owner.state.hasBusiness, isTrue);
    expect(owner.status.problem, contains('ya no pertenece'));
    server.membership['mary@correo.mx']![owner.state.businessId] = MemberRole.owner;

    // Un cajero presta su celular y alguien entra con otra cuenta: tampoco se borra.
    final cashier = await phone(device: 'R3');
    await cashier.sync.signIn('juan@correo.mx', 'secreta1');
    await cashier.sync.joinWithCode(await owner.sync.createInvite(MemberRole.cashier, 'Juan'));
    await cashier.sync.signOut();
    await cashier.sync.signIn('pedro@correo.mx', 'secreta1');
    await cashier.sync.checkMembership();
    await cashier.store.flush();
    expect(cashier.state.hasBusiness, isTrue);
  });

  test('cada celular lleva su caja y el dueño ve todas juntas', () async {
    final owner = await phone(device: 'K7');
    await _setUpShop(owner); // abre su caja y vende
    await owner.login('mary@correo.mx');
    await owner.settle();

    final cashier = await phone(device: 'R3');
    await cashier.sync.signIn('juan@correo.mx', 'secreta1');
    await cashier.sync.joinWithCode(await owner.sync.createInvite(MemberRole.cashier, 'Juan'));
    // La caja abierta del dueño no es la suya: abre la propia.
    expect(cashier.state.openSession, isNull);
    cashier.store.openCash(20000);
    final mine = cashier.state.openSession!;
    expect(mine.device, 'R3');
    cashier.sell('coca', 3);
    await cashier.settle();
    expect(cashier.expectedCash(), 20000 + 1800 * 3);

    await owner.settle();
    // La caja del dueño no cambió por las ventas del cajero.
    final ownerCash = owner.expectedCash();
    expect(owner.state.openSession!.device, 'K7');
    final cuts = owner.state.cutsOn(DateTime.now());
    expect(cuts.map((c) => (c.device, c.mine, c.open)), [('K7', true, true), ('R3', false, true)]);
    expect(cuts.last.summary.expectedCashCents, 20000 + 1800 * 3);
    expect(cuts.first.summary.expectedCashCents, ownerCash);
    final total = cuts.fold(CashSummary.zero, (a, c) => a + c.summary);
    expect(total.expectedCashCents, ownerCash + 20000 + 1800 * 3);
    expect(owner.state.severalRegisters, isTrue);

    // Ayer no hubo nada.
    expect(owner.state.cutsOn(DateTime.now().subtract(const Duration(days: 1))), isEmpty);
  });

  test('la foto de un producto se sube y el otro celular la baja', () async {
    final a = await phone(device: 'K7');
    await _setUpShop(a);
    await a.login('mary@correo.mx');
    await a.settle();

    final jpeg = Uint8List.fromList(List.generate(300, (i) => i % 256));
    a.store.setProductPhoto('coca', jpeg);
    final path = a.state.productById('coca')!.photoPath!;
    expect(path, startsWith('${a.state.businessId}/coca-'));
    expect(a.state.photoOf(a.state.productById('coca')!), jpeg);
    await a.settle();
    expect(server.storage[path], jpeg);
    expect(server.table('products')['coca']!['image_path'], path);
    expect(await a.repo.pendingPhotos(), isEmpty);

    final b = await phone(device: 'R3');
    await b.login('mary@correo.mx');
    await b.settle();
    expect(b.state.productById('coca')!.photoPath, path);
    expect(b.state.photoOf(b.state.productById('coca')!), jpeg);

    // Otra foto: la anterior se borra del celular y el otro baja la nueva.
    final second = Uint8List.fromList(List.filled(200, 7));
    a.store.setProductPhoto('coca', second);
    await a.settle();
    await b.settle();
    expect(b.state.photoOf(b.state.productById('coca')!), second);
    expect(await b.repo.photoPaths(), {b.state.productById('coca')!.photoPath});

    // Quitarla.
    a.store.setProductPhoto('coca', null);
    await a.settle();
    await b.settle();
    expect(b.state.productById('coca')!.photoPath, isNull);
  });

  test('el cajero aparta con foto: se sube y el dueño la ve; el mesero no puede subirla', () async {
    final owner = await phone(device: 'K7');
    await _setUpShop(owner);
    await owner.login('mary@correo.mx');
    await owner.settle();
    final code = await owner.sync.createInvite(MemberRole.cashier, 'Juan');
    final cashier = await phone(device: 'R3');
    await cashier.sync.signIn('juan@correo.mx', 'secreta1');
    await cashier.sync.joinWithCode(code);
    await cashier.settle();

    final customer = cashier.store.addCustomer('Doña Rosa');
    final jpeg = Uint8List.fromList(List.generate(120, (i) => i));
    final l = cashier.store.addLayaway(
      customerId: customer.id,
      description: 'Vestido azul talla M',
      totalCents: 45000,
      depositCents: 10000,
      photo: jpeg,
    );
    expect(l.photoPath, startsWith('${cashier.state.businessId}/layaway-${l.id}-'));
    expect(cashier.state.photoOfLayaway(l), jpeg);
    await cashier.settle();
    expect(cashier.status.pending, 0);
    expect(server.storage[l.photoPath], jpeg);
    expect(server.table('layaways')[l.id]!['photo_path'], l.photoPath);

    await owner.settle();
    final seen = owner.state.layawayById(l.id)!;
    expect(owner.state.photoOfLayaway(seen), jpeg);

    // Otra foto: el dueño baja la nueva.
    final second = Uint8List.fromList(List.filled(80, 3));
    cashier.store.setLayawayPhoto(l.id, second);
    await cashier.settle();
    await owner.settle();
    expect(owner.state.photoOfLayaway(owner.state.layawayById(l.id)!), second);

    // Un mesero no sube fotos (en Supabase lo niega la regla del almacenamiento).
    final waiterCode = await owner.sync.createInvite(MemberRole.waiter, 'Luis');
    final waiter = await phone(device: 'M1');
    await waiter.sync.signIn('luis@correo.mx', 'secreta1');
    await waiter.sync.joinWithCode(waiterCode);
    await waiter.settle();
    await expectLater(
      waiter.remote.uploadPhoto('${owner.state.businessId}/layaway-x-1.jpg', jpeg),
      throwsA(isA<SyncException>()),
    );
    // Y el cajero no sube fotos de producto.
    await expectLater(
      cashier.remote.uploadPhoto('${owner.state.businessId}/coca-1.jpg', jpeg),
      throwsA(isA<SyncException>()),
    );
  });

  test('una devolución de otro día se sube y el otro celular la ve', () async {
    final a = await phone(device: 'K7');
    await _setUpShop(a);
    await a.login('mary@correo.mx');
    await a.settle();
    final sale = a.sell('coca', 3);
    a.store.closeCash(a.state.summaryFor(a.state.openSession!).expectedCashCents);
    a.store.openCash(0);
    final ret = a.store.returnFromPastSale(sale.id, {0: 1}, reason: 'Mal estado')!;
    await a.settle();
    expect(a.status.pending, 0);
    final row = server.table('sale_returns')[ret.id]!;
    expect(row['sale_id'], sale.id);
    expect((row['lines']! as List).single, containsPair('qty', 1.0));

    final b = await phone(device: 'R3');
    await b.login('mary@correo.mx');
    await b.settle();
    final seen = b.state.returnsOf(sale.id).single;
    expect(seen.amountCents, ret.amountCents);
    expect(b.state.returnedOf(sale.id)['coca'], 1);
    expect(b.state.productById('coca')!.stock, a.state.productById('coca')!.stock);
  });

  test('el logo del negocio se sube y el otro celular lo baja', () async {
    final a = await phone(device: 'K7');
    await _setUpShop(a);
    await a.login('mary@correo.mx');
    await a.settle();

    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, ...List.filled(100, 9)]);
    a.store.setLogo(png);
    final path = a.state.logoPath!;
    expect(path, startsWith('${a.state.businessId}/logo-'));
    await a.settle();
    expect(server.storage[path], png);
    expect(server.table('businesses')[a.state.businessId]!['logo_path'], path);
    expect(server.table('businesses')[a.state.businessId]!['name'], isNotNull); // no pisa lo demás

    final b = await phone(device: 'R3');
    await b.login('mary@correo.mx');
    await b.settle();
    expect(b.state.logoPath, path);
    expect(b.state.logo, png);

    // Quitarlo también llega al otro celular.
    a.store.setLogo(null);
    await a.settle();
    await b.settle();
    expect(b.state.logoPath, isNull);
    expect(b.state.logo, isNull);
  });

  test('el plano acomodado como el local llega a los demás celulares y se guarda', () async {
    final owner = await phone(device: 'K7');
    await _setUpShop(owner);
    owner.store.addTables(3);
    await owner.login('mary@correo.mx');
    await owner.settle();

    final t = owner.state.activeTables;
    owner.store.placeTable(t[0].id, 400, 120);
    owner.store.shapeTable(t[1].id, shape: TableShape.redonda, seats: 6);
    await owner.settle();

    final other = await phone(device: 'R3');
    await other.login('mary@correo.mx');
    final a = other.state.tableById(t[0].id)!;
    final b = other.state.tableById(t[1].id)!;
    expect((a.x, a.y, a.placed), (400, 120, true));
    expect((b.shape, b.seats, b.placed), (TableShape.redonda, 6, false));
    expect(other.state.tableById(t[2].id)!.seats, 4);

    // Paredes, barra...: también llegan, y lo quitado se quita en el otro celular.
    final bar = owner.store.addFloorItem(null, FloorItemKind.barra);
    owner.store.renameFloorItem(bar.id, 'Barra de bebidas');
    owner.store.moveFloorItem(bar.id, 500, 300);
    final wall = owner.store.addFloorItem(null, FloorItemKind.pared);
    owner.store.rotateFloorItem(wall.id);
    await owner.settle();
    await other.settle();
    final seenBar = other.state.floorItemsIn(null).firstWhere((f) => f.id == bar.id);
    expect((seenBar.title, seenBar.x, seenBar.y, seenBar.kind), ('Barra de bebidas', 500, 300, FloorItemKind.barra));
    final seenWall = other.state.floorItemById(wall.id)!;
    expect((seenWall.width, seenWall.height), (FloorItemKind.pared.height, FloorItemKind.pared.width));
    owner.store.removeFloorItem(wall.id);
    await owner.settle();
    await other.settle();
    expect(other.state.floorItemsIn(null).map((f) => f.id), [bar.id]);

    // Se guarda en el teléfono: al volver a abrir sigue igual.
    await owner.store.flush();
    final reloaded = await owner.repo.load();
    final again = reloaded!.store.tables.firstWhere((x) => x.id == t[0].id);
    expect((again.x, again.y), (400, 120));

    // Cambiar de zona la suelta del plano; "Acomodar solas" también.
    owner.store.moveTable(t[0].id, 'Terraza');
    expect(owner.state.tableById(t[0].id)!.placed, isFalse);
    owner.store.placeTable(t[2].id, 10, 10);
    owner.store.resetLayout(null);
    expect(owner.state.tablesIn(null).any((x) => x.placed), isFalse);
    await owner.settle();
  });

  test('"imprimir el ticket al cobrar" se recuerda en este aparato y viene apagado', () async {
    final p = await phone(device: 'K7');
    await _setUpShop(p);
    expect(p.state.ticketPrint, isFalse);
    p.store.setTicketPrint(true);
    await p.store.flush();
    expect((await p.repo.load())!.store.ticketPrint, isTrue);
  });

  test('el mesero manda la comanda y la cocina la recibe sola', () async {
    final waiter = await phone(device: 'K7');
    await _setUpShop(waiter);
    waiter.store.addTables(4);
    waiter.store.addTables(1, zone: 'Terraza');
    await waiter.login('mary@correo.mx');
    await waiter.settle();

    final kitchen = await phone(device: 'R3');
    await kitchen.login('mary@correo.mx');
    expect(kitchen.state.activeTables, hasLength(5));
    expect(kitchen.state.tablesIn('Terraza').single.fullName, 'Mesa 1 · Terraza');

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

  // ---------- Varios negocios en una cuenta ----------
  // Cada negocio vive en su propia base del teléfono: aquí, dos "Phone" con la misma cuenta son dos
  // negocios en el mismo celular.

  test('una cuenta en dos negocios: dueña del suyo y mesera en otro, sin mezclarse', () async {
    final guero = await phone(device: 'G1');
    await _setUpShop(guero);
    await guero.login('guero@correo.mx');
    await guero.settle();
    final code = await guero.sync.createInvite(MemberRole.waiter, 'Ana');

    // Ana ya tiene su negocio en el celular y respaldado.
    final perfumes = await phone(device: 'A1');
    perfumes.store.startBusiness('Perfumes Ana');
    perfumes.store.saveProduct(const Product(id: 'p1', name: 'Perfume', priceCents: 45000));
    await perfumes.store.flush();
    expect((await perfumes.login('ana@correo.mx')).result, LinkResult.uploaded);

    // Se une al restaurante con el código: como este celular ya tiene su negocio, va aparte.
    final outcome = await perfumes.sync.joinWithCode(formatInviteCode(code));
    expect(outcome.result, LinkResult.joinedOther);
    expect(outcome.remoteName, 'Tienda La Esperanza');
    expect(perfumes.state.businessName, 'Perfumes Ana'); // no se tocó

    // El otro negocio se abre en su propio archivo y se baja de la nube.
    final turno = await phone(device: 'A1');
    await turno.sync.signIn('ana@correo.mx', 'secreta1');
    await turno.sync.downloadBusiness(outcome.remoteId!, outcome.remoteName!);
    expect(turno.state.businessName, 'Tienda La Esperanza');
    expect(turno.status.role, MemberRole.waiter);
    expect(turno.state.productById('p1'), isNull); // nada de sus perfumes aquí

    // En su negocio sigue siendo la dueña, y su cuenta ve los dos.
    await perfumes.settle();
    expect(perfumes.status.role, MemberRole.owner);
    final mine = await perfumes.sync.accountBusinesses();
    expect(mine.map((b) => (b.name, b.role)), [
      ('Perfumes Ana', MemberRole.owner),
      ('Tienda La Esperanza', MemberRole.waiter),
    ]);
    // El dueño del restaurante no ve el negocio de Ana.
    expect((await guero.sync.accountBusinesses()).map((b) => b.name), ['Tienda La Esperanza']);
  });

  test('crear otro negocio con la misma cuenta lo sube como uno más', () async {
    final first = await phone();
    first.store.startBusiness('Tacos en la noche');
    await first.store.flush();
    await first.login('beto@correo.mx');

    final second = await phone();
    second.store.startBusiness('Tienda en la mañana');
    await second.store.flush();
    await second.sync.signIn('beto@correo.mx', 'secreta1');
    // Sin pedirlo, se pregunta (puede ser un negocio de prueba)…
    expect((await second.sync.ensureLinked()).result, LinkResult.conflict);
    // …recién creado a propósito, se sube como otro negocio de la cuenta.
    expect((await second.sync.ensureLinked(createIfNew: true)).result, LinkResult.uploaded);
    expect((await second.sync.accountBusinesses()).map((b) => b.name), ['Tacos en la noche', 'Tienda en la mañana']);
    expect(second.status.role, MemberRole.owner);
  });
}
