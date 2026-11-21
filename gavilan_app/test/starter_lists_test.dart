import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/business.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/domain/starter_catalog.dart';
import 'package:gavilan/state/store.dart';
import 'package:gavilan/theme/theme.dart';
import 'package:gavilan/ui/inventario/starter_catalog_screen.dart';
import 'package:gavilan/ui/widgets/product_icons.dart';
import 'package:google_fonts/google_fonts.dart';

/// Listas de inicio por giro: tiendita, fonda, papelería, ferretería y farmacia.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('cada lista tiene productos con icono que existe y sin nombres repetidos', () {
    for (final k in StarterKind.values) {
      final items = [for (final g in k.groups) ...g.items];
      expect(items.length, greaterThan(20), reason: k.label);
      expect(items.map((i) => i.name.toLowerCase()).toSet(), hasLength(items.length), reason: k.label);
      for (final i in items) {
        expect(productIcons.containsKey(i.iconId), isTrue, reason: '${k.label}: ${i.name}');
        expect(i.hintPesos, greaterThan(0));
      }
    }
  });

  test('una fonda empieza en la lista de fonda; lo demás, en la de tiendita', () {
    expect(StarterKind.of(BusinessType.restaurante), StarterKind.fonda);
    expect(StarterKind.of(BusinessType.encargos), StarterKind.fonda);
    expect(StarterKind.of(BusinessType.tienda), StarterKind.tiendita);
    expect(StarterKind.of(null), StarterKind.tiendita);
  });

  testWidgets('se marcan productos de dos listas y se agregan juntos', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final app = ProviderContainer(
      overrides: [
        initialDataProvider.overrideWithValue(
          LoadedData(
            store: StoreState.blank.copyWith(
              businessId: 'b',
              businessName: 'Fonda Doña Mary',
              businessType: BusinessType.restaurante,
            ),
            plan: Plan.negocio,
          ),
        ),
      ],
    );
    addTearDown(app.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: app,
        child: MaterialApp(
          theme: buildGavilanTheme().copyWith(splashFactory: InkRipple.splashFactory),
          home: const StarterCatalogScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Finder priceOf(String name) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
      matching: find.byType(TextField),
    );

    // Abre en la de fonda.
    expect(find.text('Panucho'), findsOneWidget);
    await tester.enterText(priceOf('Panucho'), '22');
    await tester.pump();

    // Cambia a farmacia: lo marcado en fonda se queda.
    await tester.tap(find.text('Farmacia'));
    await tester.pumpAndSettle();
    expect(find.text('Fonda (1)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Repelente de mosquitos'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(priceOf('Repelente de mosquitos'), '95');
    await tester.pump();
    expect(find.text('2 productos marcados'), findsOneWidget);

    await tester.tap(find.text('Agregar 2'));
    await tester.pumpAndSettle();
    final products = app.read(storeProvider).activeProducts;
    expect(products.map((p) => (p.name, p.priceCents)), [('Panucho', 2200), ('Repelente de mosquitos', 9500)]);
  });
}
