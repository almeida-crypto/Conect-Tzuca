import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/app.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/remote_mapping.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/clerk.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/state/clerk_session.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';
import 'package:gavilan/ui/fiados/credit_limit.dart';
import 'package:gavilan/ui/shell/home_shell.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tope de fiado: general y por cliente, aviso al fiar de más y quién puede pasarse.
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

  test('el tope del cliente manda; si no tiene, el general; sin ninguno, no hay tope', () {
    final app = demo();
    final n = app.read(storeProvider.notifier);
    StoreState s() => app.read(storeProvider);
    final lupe = s().customers.first.id;
    final debt = s().balanceOf(lupe);

    expect(s().creditLimitOf(lupe), isNull);
    expect(s().creditCheck(lupe, 999999).over, isFalse);

    n.setDefaultCreditLimit(debt + 1000);
    expect(s().creditLimitOf(lupe), debt + 1000);
    expect(s().creditCheck(lupe, 1000).over, isFalse); // queda justo en el tope
    expect(s().creditCheck(lupe, 1001).over, isTrue);
    expect(s().creditCheck(lupe, 1001).afterCents, debt + 1001);

    n.setCustomerCreditLimit(lupe, debt + 50000);
    expect(s().creditLimitOf(lupe), debt + 50000);
    expect(s().creditCheck(lupe, 1001).over, isFalse);

    n.setCustomerCreditLimit(lupe, null); // vuelve al general
    expect(s().creditLimitOf(lupe), debt + 1000);
    n.setDefaultCreditLimit(null);
    expect(s().creditLimitOf(lupe), isNull);

    n.setDefaultCreditLimit(999999999999); // nada irreal
    expect(s().defaultCreditLimitCents, 99999999);
  });

  test('los topes se guardan al reabrir y suben a la nube', () async {
    final db = GavilanDb(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftRepository(db);
    var app = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(await repo.load())],
    );
    final n = app.read(storeProvider.notifier);
    n.startBusiness('La Esperanza');
    final rosa = n.addCustomer('Doña Rosa');
    await n.flush();
    await repo.link(app.read(storeProvider).businessId);
    n.setCustomerCreditLimit(rosa.id, 300000);
    n.setDefaultCreditLimit(100000);
    await n.flush();

    final changes = [
      for (final row in await repo.pending())
        for (final t in outboxTables(row.payload)) t,
    ];
    expect(changes, containsAll(['customers', 'businesses']));
    expect(customerToRemote(app.read(storeProvider).customerById(rosa.id)!)['credit_limit'], 3000);
    expect(creditLimitToRemote(100000), {'credit_limit': 1000});
    app.dispose();

    app = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(await repo.load())],
    );
    addTearDown(app.dispose);
    expect(app.read(storeProvider).customerById(rosa.id)!.creditLimitCents, 300000);
    expect(app.read(storeProvider).defaultCreditLimitCents, 100000);

    // Lo que baja de la nube también se guarda (otro celular puso el tope).
    await repo.applyRemote('businesses', [
      {'id': 'x', 'name': 'La Esperanza', 'credit_limit': 1500},
    ]);
    await repo.applyRemote('customers', [
      {'id': rosa.id, 'name': 'Doña Rosa', 'credit_limit': '2500.00'},
    ]);
    final again = (await repo.load())!.store;
    expect(again.defaultCreditLimitCents, 150000);
    expect(again.customerById(rosa.id)!.creditLimitCents, 250000);
  });

  group('al fiar de más', () {
    final dueno = Clerk.create(name: 'Víctor', role: ClerkRole.dueno, pin: '1234');
    final ana = Clerk.create(name: 'Ana', role: ClerkRole.cajero, pin: '5678');

    Future<(ProviderContainer, ConsumerState)> pumpApp(WidgetTester tester, {List<Clerk> clerks = const []}) async {
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
      final app = ProviderScope.containerOf(tester.element(find.byType(GavilanApp)));
      if (clerks.isNotEmpty) {
        app.read(clerkSessionProvider.notifier).unlock(ana, '5678');
        await tester.pumpAndSettle();
      }
      return (app, tester.state<ConsumerState>(find.byType(HomeShell)));
    }

    testWidgets('dentro del tope no pregunta nada', (tester) async {
      final (app, home) = await pumpApp(tester);
      final lupe = app.read(storeProvider).customers.first;
      final asked = confirmCreditLimit(home.context, home.ref, lupe, 1000);
      await tester.pumpAndSettle();
      expect(await asked, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('el dueño ve el aviso y puede fiar de todos modos', (tester) async {
      final (app, home) = await pumpApp(tester);
      final lupe = app.read(storeProvider).customers.first;
      app.read(storeProvider.notifier).setCustomerCreditLimit(lupe.id, app.read(storeProvider).balanceOf(lupe.id));
      final asked = confirmCreditLimit(home.context, home.ref, lupe, 5000);
      await tester.pumpAndSettle();
      expect(find.text('${lupe.name} se pasa de su tope'), findsOneWidget);
      expect(find.textContaining('quedaría en'), findsOneWidget);
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Fiar de todos modos')).onPressed!();
      await tester.pumpAndSettle();
      expect(await asked, isTrue);
    });

    testWidgets('un cajero necesita el PIN del dueño; con "No fiar" no se fía', (tester) async {
      final (app, home) = await pumpApp(tester, clerks: [dueno, ana]);
      final lupe = app.read(storeProvider).customers.first;
      app.read(storeProvider.notifier).setDefaultCreditLimit(0);

      var asked = confirmCreditLimit(home.context, home.ref, lupe, 5000);
      await tester.pumpAndSettle();
      expect(find.textContaining('el dueño o un encargado pone su PIN'), findsOneWidget);
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'No fiar')).onPressed!();
      await tester.pumpAndSettle();
      expect(await asked, isFalse);

      asked = confirmCreditLimit(home.context, home.ref, lupe, 5000);
      await tester.pumpAndSettle();
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Pedir PIN')).onPressed!();
      await tester.pumpAndSettle();
      expect(find.text('Hace falta el PIN del dueño o un encargado'), findsOneWidget);
      for (final d in '1234'.split('')) {
        await tester.tap(find.text(d).last);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      expect(await asked, isTrue);
      expect(app.read(activeClerkProvider)?.name, 'Ana'); // sigue atendiendo Ana
    });
  });
}
