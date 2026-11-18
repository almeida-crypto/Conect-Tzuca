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
import 'package:gavilan/state/app_state.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';
import 'package:gavilan/ui/cobrar/pay_sheet.dart';
import 'package:gavilan/ui/shell/home_shell.dart';
import 'package:gavilan/ui/widgets/buttons.dart';
import 'package:google_fonts/google_fonts.dart';

/// Formas de pago que acepta el negocio.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('un negocio nuevo empieza con efectivo y transferencia; los de antes con las tres', () async {
    final db = GavilanDb(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftRepository(db);
    var app = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(await repo.load())],
    );
    final n = app.read(storeProvider.notifier);
    n.startBusiness('La Esperanza');
    expect(app.read(storeProvider).acceptedMethods, [PayMethod.efectivo, PayMethod.transferencia]);

    n.togglePayMethod(PayMethod.tarjeta, true);
    n.togglePayMethod(PayMethod.transferencia, false);
    n.togglePayMethod(PayMethod.efectivo, false); // el efectivo no se apaga
    expect(app.read(storeProvider).acceptedMethods, [PayMethod.efectivo, PayMethod.tarjeta]);
    await n.flush();
    app.dispose();

    app = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(await repo.load())],
    );
    addTearDown(app.dispose);
    expect(app.read(storeProvider).acceptedMethods, [PayMethod.efectivo, PayMethod.tarjeta]);

    // Negocio de antes (sin dato): las tres.
    expect(seedStore(DateTime.now()).acceptedMethods, PayMethod.values);

    // Hacia la nube y de regreso.
    expect(payMethodsToRemote({PayMethod.tarjeta}), {
      'pay_methods': ['cash', 'card'],
    });
    expect(payMethodsFromRemote(['cash', 'transfer']), {PayMethod.efectivo, PayMethod.transferencia});
    expect(payMethodsFromRemote(null), isNull);
    await repo.applyRemote('businesses', [
      {
        'id': 'x',
        'name': 'La Esperanza',
        'pay_methods': ['cash'],
      },
    ]);
    expect((await repo.load())!.store.acceptedMethods, [PayMethod.efectivo]);
  });

  testWidgets('si solo acepta efectivo, al cobrar no salen los botones de forma de pago', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialDataProvider.overrideWithValue(
            LoadedData(
              store: seedStore(DateTime.now()).copyWith(payMethods: {PayMethod.efectivo}),
              plan: Plan.negocio,
            ),
          ),
        ],
        child: const GavilanApp(showSplash: false),
      ),
    );
    await tester.pumpAndSettle();
    final app = ProviderScope.containerOf(tester.element(find.byType(GavilanApp)));
    final coca = app.read(storeProvider).products.first;
    app.read(cartProvider.notifier).addProduct(coca);
    showPaySheet(tester.element(find.byType(HomeShell)));
    await tester.pumpAndSettle();
    expect(find.text('Solo efectivo'), findsOneWidget);
    expect(find.widgetWithText(GChip, 'Tarjeta'), findsNothing);
    expect(find.text('¿Con cuánto paga?'), findsOneWidget);

    app.read(storeProvider.notifier).togglePayMethod(PayMethod.tarjeta, true);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(GChip, 'Tarjeta'), findsOneWidget);
    expect(find.widgetWithText(GChip, 'Transfer.'), findsNothing);
  });
}
