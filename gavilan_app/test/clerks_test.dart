import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/app.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/remote_mapping.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/clerk.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/domain/team.dart';
import 'package:gavilan/state/clerk_session.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';
import 'package:gavilan/state/sync.dart';
import 'package:gavilan/ui/clerks/lock_screen.dart';
import 'package:gavilan/ui/shell/home_shell.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cambio de cajero con PIN en un aparato compartido.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final dueno = Clerk.create(name: 'Víctor', role: ClerkRole.dueno, pin: '1234');
  final ana = Clerk.create(name: 'Ana', role: ClerkRole.cajero, pin: '5678');
  final luis = Clerk.create(name: 'Luis', role: ClerkRole.encargado, pin: '2468');

  SaleLine lineOf(Product p, double qty) =>
      SaleLine(key: p.id, productId: p.id, name: p.name, unitCents: p.priceCents, unitCostCents: p.costCents, qty: qty);

  ProviderContainer demo({List<Clerk> clerks = const [], DateTime Function()? clock}) {
    final app = ProviderContainer(
      overrides: [
        initialDataProvider.overrideWithValue(
          LoadedData(
            store: seedStore(DateTime.now()).copyWith(clerks: clerks),
            plan: Plan.negocio,
          ),
        ),
        if (clock != null) clerkSessionProvider.overrideWith(() => ClerkSessionNotifier(clock: clock)),
      ],
    );
    addTearDown(app.dispose);
    return app;
  }

  group('PIN', () {
    test('se guarda como huella con sal, no el número', () {
      expect(dueno.pinHash, isNot(contains('1234')));
      expect(dueno.checkPin('1234'), isTrue);
      expect(dueno.checkPin('1235'), isFalse);
      // Mismo PIN, otra sal: otra huella.
      final otro = Clerk.create(name: 'Otro', role: ClerkRole.cajero, pin: '1234');
      expect(otro.pinHash, isNot(dueno.pinHash));
      expect(dueno.withPin('9999').checkPin('9999'), isTrue);
      expect(dueno.withPin('9999').checkPin('1234'), isFalse);
    });

    test('solo 4 números', () {
      expect(isValidPin('0420'), isTrue);
      expect(isValidPin('123'), isFalse);
      expect(isValidPin('12345'), isFalse);
      expect(isValidPin('12a4'), isFalse);
    });

    test('ida y vuelta en JSON', () {
      final back = clerksFromJson(clerksToJson([dueno, ana]));
      expect(back.map((c) => (c.id, c.name, c.role)), [
        (dueno.id, 'Víctor', ClerkRole.dueno),
        (ana.id, 'Ana', ClerkRole.cajero),
      ]);
      expect(back.last.checkPin('5678'), isTrue);
      expect(clerksFromJson(null), isEmpty);
      expect(clerksFromJson(''), isEmpty);
    });
  });

  test('permisos: el cajero cobra pero no cancela ni ve ganancias; el encargado sí; el dueño todo', () {
    const owner = MemberRole.owner;
    final cajero = Permissions(owner, clerk: ClerkRole.cajero);
    expect([cajero.cancelSales, cajero.seeProfit, cajero.editCatalog, cajero.manageTables], everyElement(isFalse));
    expect([cajero.manageClerks, cajero.manageTeam, cajero.resetPhone, cajero.inviteAdmins], everyElement(isFalse));

    final encargado = Permissions(owner, clerk: ClerkRole.encargado);
    expect([encargado.cancelSales, encargado.seeProfit, encargado.editCatalog], everyElement(isTrue));
    expect([encargado.manageClerks, encargado.manageTeam, encargado.resetPhone], everyElement(isFalse));

    final jefe = Permissions(owner, clerk: ClerkRole.dueno);
    expect([
      jefe.cancelSales,
      jefe.seeProfit,
      jefe.manageClerks,
      jefe.manageTeam,
      jefe.inviteAdmins,
    ], everyElement(isTrue));

    // El PIN no da más de lo que permite la cuenta: un cajero de la cuenta sigue sin cancelar.
    final cuentaCajero = Permissions(MemberRole.cashier, clerk: ClerkRole.dueno);
    expect([cuentaCajero.cancelSales, cuentaCajero.manageClerks], everyElement(isFalse));
    // Sin PIN, como siempre.
    expect(const Permissions(null).manageClerks, isTrue);
  });

  test('5 PIN equivocados: espera un minuto', () {
    var now = DateTime(2026, 11, 16, 9);
    final app = demo(clerks: [dueno, ana], clock: () => now);
    final s = app.read(clerkSessionProvider.notifier);
    expect(app.read(clerkSessionProvider).locked, isTrue);
    for (var i = 0; i < 4; i++) {
      expect(s.unlock(ana, '0000'), UnlockResult.wrongPin);
    }
    expect(s.unlock(ana, '0000'), UnlockResult.blocked);
    expect(s.unlock(ana, '5678'), UnlockResult.blocked); // ni con el bueno
    expect(s.secondsBlocked(), 60);
    now = now.add(const Duration(seconds: 61));
    expect(s.unlock(ana, '5678'), UnlockResult.ok);
    expect(app.read(activeClerkProvider)?.name, 'Ana');
    s.lock();
    expect(app.read(clerkSessionProvider).locked, isTrue);
    expect(app.read(clerkSessionProvider).lastId, ana.id);
  });

  test('cada venta, gasto y abono queda a nombre de quien atiende', () {
    final app = demo(clerks: [dueno, ana]);
    final n = app.read(storeProvider.notifier);
    StoreState st() => app.read(storeProvider);
    final pan = st().products.firstWhere((p) => p.name.startsWith('Pan'));

    // Bloqueado: permisos de cajero (nadie entra con permisos de dueño sin PIN).
    expect(app.read(permissionsProvider).cancelSales, isFalse);

    app.read(clerkSessionProvider.notifier).unlock(ana, '5678');
    expect(app.read(permissionsProvider).seeProfit, isFalse);
    final v1 = n.checkout(lines: [lineOf(pan, 2)], kind: SaleKind.pagada, method: PayMethod.efectivo);
    n.addMovement(CashKind.gasto, 5000, 'Hielo');
    final cliente = n.addCustomer('Doña Rosa');
    n.checkout(lines: [lineOf(pan, 1)], kind: SaleKind.fiada, customerId: cliente.id);
    n.addAbono(cliente.id, 500, PayMethod.efectivo);

    app.read(clerkSessionProvider.notifier).lock();
    app.read(clerkSessionProvider.notifier).unlock(dueno, '1234');
    expect(app.read(permissionsProvider).seeProfit, isTrue);
    final v2 = n.checkout(lines: [lineOf(pan, 5)], kind: SaleKind.pagada, method: PayMethod.tarjeta);

    expect(st().sales.firstWhere((s) => s.id == v1.id).clerk, 'Ana');
    expect(st().sales.firstWhere((s) => s.id == v2.id).clerk, 'Víctor');
    expect(st().movements.last.clerk, 'Ana');
    expect(st().credit.where((e) => e.type == CreditType.abono).last.clerk, 'Ana');

    final rows = st().salesByClerk(st().openSession!);
    // Las ventas de antes de usar PIN quedan como "Sin nombre".
    expect(rows.map((r) => r.name), containsAll(['Víctor', 'Ana', 'Sin nombre']));
    expect(rows.firstWhere((r) => r.name == 'Víctor'), (name: 'Víctor', count: 1, cents: pan.priceCents * 5));
    expect([for (var i = 1; i < rows.length; i++) rows[i - 1].cents >= rows[i].cents], everyElement(isTrue));
    final anaRow = rows.firstWhere((r) => r.name == 'Ana');
    expect(anaRow.count, 2);
    expect(anaRow.cents, pan.priceCents * 3);
  });

  test('sin PIN no hay nombres ni "ventas por persona"', () {
    final app = demo();
    final n = app.read(storeProvider.notifier);
    final pan = app.read(storeProvider).products.firstWhere((p) => p.name.startsWith('Pan'));
    final v = n.checkout(lines: [lineOf(pan, 1)], kind: SaleKind.pagada, method: PayMethod.efectivo);
    expect(v.clerk, isNull);
    expect(app.read(storeProvider).salesByClerk(app.read(storeProvider).openSession!), isEmpty);
  });

  test('Entregar caja: anota lo contado sin mover lo que debe haber', () {
    final app = demo(clerks: [dueno, ana]);
    final n = app.read(storeProvider.notifier);
    StoreState st() => app.read(storeProvider);
    app.read(clerkSessionProvider.notifier).unlock(ana, '5678');
    final expected = st().summaryFor(st().openSession!).expectedCashCents;

    final diff = n.handOverCash(expected - 1000, to: 'Víctor');
    expect(diff, -1000);
    expect(st().summaryFor(st().openSession!).expectedCashCents, expected);
    final m = st().movements.last;
    expect(m.kind, CashKind.arqueo);
    expect(m.clerk, 'Ana');
    expect(m.amountCents, expected - 1000);
    expect(m.concept, contains('Entregó la caja a Víctor'));
    expect(m.concept, contains('faltaron \$10.00'));

    // Así sube a la nube y así se lee de vuelta.
    final remote = movementToRemote(m);
    expect(remote['kind'], 'count');
    expect(remote['clerk_name'], 'Ana');
    final back = movementFromRemote({...remote, 'cash_session_id': m.sessionId});
    expect(back.kind, CashKind.arqueo);
    expect(back.clerkName, 'Ana');
  });

  test('las personas y sus PIN se guardan en el aparato y nunca suben a la nube', () async {
    final db = GavilanDb(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftRepository(db);
    var app = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(await repo.load())],
    );
    app.read(storeProvider.notifier).startBusiness('La Esperanza');
    await app.read(storeProvider.notifier).flush();
    await repo.link(app.read(storeProvider).businessId);
    final before = await repo.pendingCount();

    app.read(storeProvider.notifier)
      ..saveClerk(dueno)
      ..saveClerk(ana)
      ..setLockMinutes(5);
    await app.read(storeProvider.notifier).flush();
    expect(await repo.pendingCount(), before);
    app.dispose();

    app = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(await repo.load())],
    );
    addTearDown(app.dispose);
    final s = app.read(storeProvider);
    expect(s.clerks.map((c) => c.name), ['Víctor', 'Ana']);
    expect(s.lockMinutes, 5);
    expect(s.clerks.last.checkPin('5678'), isTrue);
    // Cada vez que se abre la app, empieza bloqueada.
    expect(app.read(clerkSessionProvider).locked, isTrue);

    app.read(storeProvider.notifier).disablePins();
    await app.read(storeProvider.notifier).flush();
    final again = await repo.load();
    expect(again!.store.clerks, isEmpty);
    expect(again.store.lockMinutes, isNull);
  });

  group('pantalla', () {
    Future<ProviderContainer> pumpApp(WidgetTester tester, {List<Clerk> clerks = const []}) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialDataProvider.overrideWithValue(
              LoadedData(
                store: seedStore(DateTime.now()).copyWith(clerks: clerks),
                plan: Plan.negocio,
              ),
            ),
          ],
          child: const GavilanApp(showSplash: false),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(GavilanApp)));
    }

    Future<void> typePin(WidgetTester tester, String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.descendant(of: find.byType(LockScreen), matching: find.text(d)));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
    }

    testWidgets('al abrir pide quién atiende; con el PIN entra y F4 vuelve a bloquear', (tester) async {
      final app = await pumpApp(tester, clerks: [dueno, ana]);
      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.text('¿Quién atiende?'), findsOneWidget);

      await tester.tap(find.text('Ana'));
      await tester.pump();
      await typePin(tester, '1111');
      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.textContaining('PIN equivocado'), findsOneWidget);

      await typePin(tester, '5678');
      expect(find.byType(LockScreen), findsNothing);
      expect(app.read(activeClerkProvider)?.name, 'Ana');
      expect(find.text('Atiende'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.f4);
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsOneWidget);
      expect(app.read(clerkSessionProvider).locked, isTrue);
    });

    testWidgets('sin personas no se pide PIN', (tester) async {
      await pumpApp(tester);
      expect(find.byType(LockScreen), findsNothing);
      expect(find.text('Atiende'), findsNothing);
    });

    testWidgets('un cajero cancela solo si el dueño pone su PIN', (tester) async {
      final app = await pumpApp(tester, clerks: [dueno, ana, luis]);
      await tester.tap(find.text('Ana'));
      await tester.pump();
      await typePin(tester, '5678');

      final consumer = tester.state<ConsumerState>(find.byType(HomeShell));
      final asked = allowOrAskPin(
        consumer.context,
        consumer.ref,
        allowed: (c) => c.cancelSales,
        action: 'Cancelar la venta',
      );
      await tester.pumpAndSettle();
      expect(find.text('Hace falta el PIN del dueño o un encargado'), findsOneWidget);
      // Pueden autorizar el dueño y el encargado; Ana no.
      expect(find.text('Luis'), findsOneWidget);
      for (final d in '1234'.split('')) {
        await tester.tap(find.text(d).last);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      expect(await asked, isTrue);
      // Quien atiende sigue siendo Ana.
      expect(app.read(activeClerkProvider)?.name, 'Ana');
    });
  });
}
