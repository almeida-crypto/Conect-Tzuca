import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/app.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/business.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';
import 'package:gavilan/ui/cobrar/open_bills.dart';
import 'package:gavilan/ui/restaurant/floor_plan.dart';
import 'package:google_fonts/google_fonts.dart';

/// La pestaña Cobrar de un restaurante: cuentas abiertas a la mano, menú por grupos y sin lector de códigos.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  StoreState restaurant() => seedStore(DateTime.now()).copyWith(
    businessType: BusinessType.restaurante,
    modules: {Module.restaurante},
    products: const [
      Product(id: 't', name: 'Tacos de pastor', priceCents: 2000, iconId: 'taco'),
      Product(id: 'h', name: 'Horchata', priceCents: 2500, iconId: 'refresco'),
      Product(id: 'm', name: 'Marquesita', priceCents: 3000, iconId: 'dulce'),
    ],
  );

  test('grupos del menú por el icono del producto', () {
    expect(MenuGroup.of(const Product(id: 'a', name: 'x', priceCents: 1, iconId: 'taco')), MenuGroup.platillos);
    expect(MenuGroup.of(const Product(id: 'a', name: 'x', priceCents: 1, iconId: 'cafe')), MenuGroup.bebidas);
    expect(MenuGroup.of(const Product(id: 'a', name: 'x', priceCents: 1, iconId: 'helado')), MenuGroup.postres);
    expect(MenuGroup.of(const Product(id: 'a', name: 'x', priceCents: 1, iconId: 'limpieza')), MenuGroup.otros);
  });

  test('solo las cuentas con algo por cobrar, la más vieja primero', () {
    final app = ProviderContainer(
      overrides: [initialDataProvider.overrideWithValue(LoadedData(store: restaurant(), plan: Plan.negocio))],
    );
    addTearDown(app.dispose);
    final n = app.read(storeProvider.notifier);
    n.addTables(3);
    final s = app.read(storeProvider);
    final first = n.openOrder(tableId: s.activeTables[0].id);
    n.addOrderItem(first.id, s.productById('t')!);
    n.openOrder(tableId: s.activeTables[1].id); // abierta pero vacía
    final takeout = n.openOrder(label: 'Juan');
    n.addOrderItem(takeout.id, s.productById('h')!);
    expect(billsToCharge(app.read(storeProvider)).map((o) => o.id), [first.id, takeout.id]);
  });

  testWidgets('en el celular: cuentas arriba, menú por grupos y sin el botón de escanear', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [initialDataProvider.overrideWithValue(LoadedData(store: restaurant(), plan: Plan.negocio))],
        child: const GavilanApp(showSplash: false),
      ),
    );
    await tester.pump();
    final app = ProviderScope.containerOf(tester.element(find.byType(GavilanApp)));
    final n = app.read(storeProvider.notifier);
    n.addTables(2);
    final s = app.read(storeProvider);
    final o = n.openOrder(tableId: s.activeTables[0].id);
    n.addOrderItem(o.id, s.productById('t')!);
    await tester.pumpAndSettle();

    // Mesas es la primera pestaña; Cobrar la segunda.
    final cobrar = find.ancestor(of: find.text('Cobrar').last, matching: find.byType(GestureDetector)).first;
    tester.widget<GestureDetector>(cobrar).onTap!();
    await tester.pumpAndSettle();

    expect(find.text('Cuentas por cobrar · 1'), findsOneWidget);
    expect(find.byType(BillCard), findsOneWidget);
    expect(find.text('Platillos'), findsOneWidget);
    expect(find.text('Bebidas'), findsOneWidget);
    expect(find.text('Postres'), findsOneWidget);
    expect(find.byTooltip('Escanear con la cámara'), findsNothing);
    expect(find.text('Buscar platillo o bebida'), findsOneWidget);

    // Lo marcado "solo en mesas" no sale en Cobrar.
    expect(find.text('Marquesita'), findsOneWidget);
    n.saveProduct(s.productById('m')!.copyWith(place: ProductPlace.mesas));
    await tester.pumpAndSettle();
    expect(find.text('Marquesita'), findsNothing);
    expect(find.text('Horchata'), findsOneWidget);
  });

  testWidgets('en la computadora, Mesas muestra el salón dibujado; se puede cambiar a tarjetas', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [initialDataProvider.overrideWithValue(LoadedData(store: restaurant(), plan: Plan.negocio))],
        child: const GavilanApp(showSplash: false),
      ),
    );
    await tester.pump();
    final app = ProviderScope.containerOf(tester.element(find.byType(GavilanApp)));
    final n = app.read(storeProvider.notifier);
    n.addTables(3);
    final s = app.read(storeProvider);
    final o = n.openOrder(tableId: s.activeTables[0].id);
    n.addOrderItem(o.id, s.productById('t')!);
    await tester.pumpAndSettle();

    expect(find.byType(TableDrawing), findsNWidgets(3));
    expect(find.text('1 de 3 ocupadas'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Mesa 1, ocupada')), findsOneWidget);
    expect(find.bySemanticsLabel('Mesa 2, libre'), findsOneWidget);

    tester.widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>)).onSelectionChanged!({false});
    await tester.pumpAndSettle();
    expect(find.byType(TableDrawing), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Acomodar: arrastrar una mesa la deja donde la sueltas', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [initialDataProvider.overrideWithValue(LoadedData(store: restaurant(), plan: Plan.negocio))],
        child: const GavilanApp(showSplash: false),
      ),
    );
    await tester.pump();
    final app = ProviderScope.containerOf(tester.element(find.byType(GavilanApp)));
    app.read(storeProvider.notifier).addTables(2);
    await tester.pumpAndSettle();

    tester.widget<TextButton>(find.widgetWithText(TextButton, 'Acomodar')).onPressed!();
    await tester.pumpAndSettle();
    expect(find.textContaining('Arrastra cada mesa'), findsOneWidget);
    expect(find.text('4 sillas'), findsNWidgets(2));

    final first = app.read(storeProvider).activeTables.first;
    await tester.drag(find.byType(TableDrawing).first, const Offset(300, 160));
    await tester.pumpAndSettle();
    final moved = app.read(storeProvider).tableById(first.id)!;
    expect(moved.placed, isTrue);
    expect(moved.x! % 10, 0);
    expect(moved.x, greaterThan(200));
    expect(moved.y, greaterThan(100));

    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Listo')).onPressed!();
    await tester.pumpAndSettle();
    expect(find.textContaining('Arrastra cada mesa'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
