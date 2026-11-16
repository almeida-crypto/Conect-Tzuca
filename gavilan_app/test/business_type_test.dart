import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/app.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/remote_mapping.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/business.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipo de negocio y módulos: cada negocio ve lo que usa.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('cada tipo prende sus módulos; un negocio de antes ve todo', () {
    final app = ProviderContainer();
    addTearDown(app.dispose);
    final n = app.read(storeProvider.notifier)..startBusiness('Tacos El Güero', type: BusinessType.restaurante);
    var s = app.read(storeProvider);
    expect(s.businessType, BusinessType.restaurante);
    expect(s.uses(Module.restaurante), isTrue);
    expect(s.uses(Module.pacas), isFalse);

    n.toggleModule(Module.apartados, true);
    s = app.read(storeProvider);
    expect(s.modules, {Module.restaurante, Module.apartados});

    final old = seedStore(DateTime.now()); // sin tipo: todo prendido, como antes
    expect(Module.values.every(old.uses), isTrue);
  });

  test('tipo y módulos viajan a Supabase y regresan', () {
    final row = businessSetupToRemote(BusinessType.ropa, {Module.pacas, Module.apartados});
    expect(row['business_type'], 'ropa');
    expect(row['modules'], {'restaurante': false, 'apartados': true, 'pacas': true, 'tandas': false});
    expect(modulesFromRemote(row['modules']), {Module.pacas, Module.apartados});
    expect(modulesFromRemote(<String, Object?>{}), isNull); // negocio de antes: sin elegir
  });

  test('se conservan al reabrir', () async {
    final db = GavilanDb(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftRepository(db);
    Future<ProviderContainer> open() async => ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(await repo.load())],
    );
    var c = await open();
    c.read(storeProvider.notifier)
      ..startBusiness('Pacas Lupita', type: BusinessType.ropa)
      ..toggleModule(Module.tandas, true);
    await c.read(storeProvider.notifier).flush();
    c.dispose();

    c = await open();
    addTearDown(c.dispose);
    expect(c.read(storeProvider).businessType, BusinessType.ropa);
    expect(c.read(storeProvider).modules, {Module.pacas, Module.apartados, Module.tandas});
  });

  Future<ProviderContainer> pumpWith(WidgetTester tester, BusinessType type, Plan plan) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = seedStore(DateTime.now()).copyWith(businessType: type, modules: type.defaultModules);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [initialDataProvider.overrideWithValue(LoadedData(store: store, plan: plan))],
        child: const GavilanApp(showSplash: false),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(GavilanApp)));
  }

  testWidgets('restaurante: Mesas es la primera pestaña y Fiados se va a Más', (tester) async {
    await pumpWith(tester, BusinessType.restaurante, Plan.negocio);
    expect(find.text('Mesas'), findsWidgets);
    expect(find.text('Fiados'), findsNothing);
    await tester.tap(find.text('Más').last);
    await tester.pumpAndSettle();
    expect(find.text('Fiados'), findsOneWidget);
    expect(find.text('Pacas y lotes'), findsWidgets); // en "Lo que uso", apagado
    expect(find.text('Lo que uso'), findsOneWidget);
  });

  testWidgets('tienda: pestañas de siempre y en Más no salen mesas ni pacas', (tester) async {
    await pumpWith(tester, BusinessType.tienda, Plan.negocio);
    expect(find.text('Fiados'), findsWidgets);
    expect(find.text('Mesas'), findsNothing);
    await tester.tap(find.text('Más').last);
    await tester.pumpAndSettle();
    // Los módulos apagados solo aparecen en "Lo que uso", con su interruptor.
    expect(find.text('Mesas y cocina'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(Module.values.length));
  });
}
