// Imágenes para la ficha de Google Play (capturas 1080×1920 e imagen destacada 1024×500), con los datos de ejemplo.
// Para regenerarlas:
//   flutter test test/store_assets_test.dart --run-skipped -t golden --update-goldens
// Quedan en play-store/graficos/.
@Tags(['golden'])
library;

import 'dart:io';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/app.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/business.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/state/app_state.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';
import 'package:gavilan/theme/colors.dart';
import 'package:google_fonts/google_fonts.dart';

const _out = '../play-store/graficos';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final sdk = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
    final icons = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await loader.load();
    }
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  /// La tiendita de ejemplo con algo en la cuenta y un apartado.
  LoadedData demo() {
    final seed = seedStore(DateTime.now()).copyWith(businessType: BusinessType.otro, isDemo: false);
    return LoadedData(store: seed, plan: Plan.negocio);
  }

  Future<ProviderContainer> openApp(WidgetTester tester, GlobalKey key) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [initialDataProvider.overrideWithValue(demo())],
        child: RepaintBoundary(key: key, child: const GavilanApp(showSplash: false)),
      ),
    );
    await settle(tester);
    final app = ProviderScope.containerOf(tester.element(find.byType(GavilanApp)));
    app.read(planProvider.notifier).set(Plan.negocio);
    await settle(tester);
    return app;
  }

  /// Guarda la pantalla a 1080×1920 (tres veces su tamaño lógico).
  Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$_out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await settle(tester);
  }

  testWidgets('capturas de la app', (tester) async {
    final key = GlobalKey();
    final app = await openApp(tester, key);
    final store = app.read(storeProvider);
    final cart = app.read(cartProvider.notifier);
    for (final p in store.activeProducts.take(3)) {
      cart.addProduct(p);
    }
    cart.addProduct(store.activeProducts.first);
    await settle(tester);
    await shot(tester, key, '1-cobrar');

    cart.clear();
    await tab(tester, 'Caja');
    await shot(tester, key, '2-caja');

    await tab(tester, 'Inventario');
    await shot(tester, key, '3-inventario');

    await tab(tester, 'Fiados');
    await shot(tester, key, '4-fiados');

    await tab(tester, 'Más');
    await shot(tester, key, '5-mas');
  });

  testWidgets('imagen destacada 1024x500', (tester) async {
    tester.view.physicalSize = const Size(1024, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          // Material: sin él, los textos salen con la línea amarilla de "falta tema".
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [GColors.marca, GColors.marcaOscura],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(64, 48, 32, 48),
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Gavilán',
                          style: GoogleFonts.manrope(fontSize: 78, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'El punto de venta de tu negocio',
                          style: GoogleFonts.manrope(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Cobra, fía, aparta y lleva tu inventario.\nFunciona sin internet.',
                          style: GoogleFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.92),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(flex: 5, child: Image.asset('assets/hawk/gavilan.png', fit: BoxFit.contain)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump();
    }
    await expectLater(find.byKey(key), matchesGoldenFile('../../play-store/graficos/destacada-1024x500.png'));
  });
}
