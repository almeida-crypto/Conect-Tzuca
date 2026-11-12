import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/app.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';
import 'package:gavilan/ui/inventario/starter_catalog_screen.dart';
import 'package:google_fonts/google_fonts.dart';

/// Primer uso: un negocio sin productos y la lista de productos comunes.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Tocar un InkWell en la prueba carga el sombreador "ink_sparkle", que Flutter 3.47 no lee en pruebas:
  // se llama a su acción directamente.
  Future<void> tapInk(WidgetTester tester, String text) async {
    final ink = find.ancestor(of: find.text(text), matching: find.byType(InkWell)).first;
    tester.widget<InkWell>(ink).onTap!();
    await tester.pumpAndSettle();
  }

  Finder priceOf(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
    matching: find.byType(TextField),
  );

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(GavilanApp)));

  testWidgets('negocio nuevo: elegir de la lista con su precio', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: GavilanApp(showSplash: false)));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Tienda de mi tía');
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    expect(find.text('Agrega tus primeros productos'), findsOneWidget);
    await tapInk(tester, 'Elegir de una lista');
    expect(find.byType(StarterCatalogScreen), findsOneWidget);

    // Escribir el precio marca el producto; tocar otro lo marca sin precio.
    await tester.enterText(priceOf('Coca-Cola 600 ml'), '19');
    await tester.pump();
    await tapInk(tester, 'Papas chicas');
    expect(find.text('2 productos marcados'), findsOneWidget);

    await tester.tap(find.text('Agregar 2'));
    await tester.pump();
    expect(find.text('Falta el precio del producto en rojo'), findsOneWidget);

    await tester.enterText(priceOf('Papas chicas'), '21.50');
    await tester.pump();
    await tester.tap(find.text('Agregar 2'));
    await tester.pumpAndSettle();

    expect(find.byType(StarterCatalogScreen), findsNothing);
    final products = container(tester).read(storeProvider).activeProducts;
    expect(products.map((p) => (p.name, p.priceCents)), [('Coca-Cola 600 ml', 1900), ('Papas chicas', 2150)]);
    expect(find.text('Agrega tus primeros productos'), findsNothing);
    expect(find.text('Coca-Cola 600 ml'), findsOneWidget);
  });

  testWidgets('un código que no existe se ofrece dar de alta', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialDataProvider.overrideWithValue(LoadedData(store: seedStore(DateTime.now()), plan: Plan.semilla)),
        ],
        child: const GavilanApp(showSplash: false),
      ),
    );
    await tester.pump();
    for (final ch in '7500000000001'.split('')) {
      final key = LogicalKeyboardKey(ch.codeUnitAt(0));
      await tester.sendKeyDownEvent(key, character: ch);
      await tester.sendKeyUpEvent(key);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('El código 7500000000001 no está en tus productos'), findsOneWidget);
    expect(find.text('Darlo de alta'), findsOneWidget);
  });
}
