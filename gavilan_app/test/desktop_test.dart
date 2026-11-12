import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/app.dart';
import 'package:gavilan/core/ticket_html.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/state/app_state.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';
import 'package:gavilan/ui/cobrar/ticket_screen.dart';
import 'package:gavilan/ui/inventario/catalog_table_screen.dart';
import 'package:google_fonts/google_fonts.dart';

/// El mostrador en la computadora: teclado, impresión y la tabla del catálogo.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> startWide(WidgetTester tester) async {
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
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(GavilanApp)));

  Future<void> type(WidgetTester tester, String text) async {
    for (final ch in text.split('')) {
      final key = switch (ch) {
        '+' => LogicalKeyboardKey.numpadAdd,
        ' ' => LogicalKeyboardKey.space,
        _ => LogicalKeyboardKey(ch.toLowerCase().codeUnitAt(0)),
      };
      await tester.sendKeyDownEvent(key, character: ch);
      await tester.sendKeyUpEvent(key);
    }
    await tester.pump();
  }

  // Tocar un TextButton en la prueba carga el sombreador "ink_sparkle", que Flutter 3.47 no puede leer en las
  // pruebas; se llama a su acción directamente.
  Future<void> pressButton(WidgetTester tester, String label) async {
    final button = find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    tester.widget<ButtonStyleButton>(button.first).onPressed!();
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  testWidgets('se teclea el producto, + suma uno, F2 cobra y Enter termina', (tester) async {
    await startWide(tester);
    expect(find.text('Cuenta'), findsOneWidget);

    await type(tester, 'coca');
    await press(tester, LogicalKeyboardKey.enter);
    expect(container(tester).read(cartProvider).single.name, 'Coca 600 ml');

    await type(tester, '+');
    expect(container(tester).read(cartProvider).single.qty, 2);

    await press(tester, LogicalKeyboardKey.f2);
    expect(find.text('Cobrar en efectivo'), findsOneWidget);

    // Un número abre "¿Con cuánto paga?" sin tocar "Otro".
    await type(tester, '100');
    await press(tester, LogicalKeyboardKey.enter);
    expect(find.byType(TicketScreen), findsOneWidget);
    expect(find.text('\$64.00'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.enter);
    expect(find.byType(TicketScreen), findsNothing);
    expect(container(tester).read(cartProvider), isEmpty);
  });

  testWidgets('el lector de códigos agrega el producto sin seleccionar el buscador', (tester) async {
    await startWide(tester);
    final coca = container(tester).read(storeProvider).activeProducts.firstWhere((p) => p.name == 'Coca 600 ml');
    await type(tester, coca.barcode!);
    await press(tester, LogicalKeyboardKey.enter);
    expect(container(tester).read(cartProvider).single.productId, coca.id);
  });

  testWidgets('Esc vacía la cuenta y "Deshacer" la regresa', (tester) async {
    await startWide(tester);
    await tester.tap(find.text('Sabritas'));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.escape);
    expect(container(tester).read(cartProvider), isEmpty);
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pump();
    expect(container(tester).read(cartProvider).single.name, 'Sabritas');
  });

  testWidgets('la tabla cambia precio y existencia, y pega productos desde Excel', (tester) async {
    await startWide(tester);
    await tester.tap(find.text('Inventario').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar en tabla'));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogTableScreen), findsOneWidget);

    final store = container(tester).read(storeProvider);
    final agua = store.activeProducts.firstWhere((p) => p.name == 'Agua 1 L');
    Finder cell(String text) => find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text);

    await tester.enterText(cell(centsText(agua.priceCents)).first, '13.50');
    await tester.enterText(cell(agua.stock.toInt().toString()).first, '25');
    await tester.pump();
    expect(find.text('Guardar 1'), findsOneWidget);

    await pressButton(tester, 'Agregar renglón');
    // El renglón nuevo es el último con nombre y código vacíos (los dos alineados a la izquierda).
    final emptyLeft = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == '' && w.textAlign == TextAlign.left,
    );
    final blankName = emptyLeft.at(emptyLeft.evaluate().length - 2);
    await tester.enterText(blankName, 'Chicle\t\t5\t\t40\nPaleta de hielo\t\t12');
    await tester.pumpAndSettle();
    expect(find.text('Guardar 3'), findsOneWidget);

    // Ctrl+S guarda.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    final after = container(tester).read(storeProvider);
    final newAgua = after.productById(agua.id)!;
    expect(newAgua.priceCents, 1350);
    expect(newAgua.stock, 25);
    final chicle = after.activeProducts.firstWhere((p) => p.name == 'Chicle');
    expect(chicle.priceCents, 500);
    expect(chicle.trackStock, isTrue);
    expect(chicle.stock, 40);
    expect(after.activeProducts.any((p) => p.name == 'Paleta de hielo' && p.priceCents == 1200), isTrue);
    expect(find.text('Sin cambios'), findsOneWidget);
  });

  test('pegar desde Excel: renglones y celdas', () {
    expect(parsePastedGrid('a\tb\r\nc\td\r\n'), [
      ['a', 'b'],
      ['c', 'd'],
    ]);
    expect(parsePastedGrid('solo'), [
      ['solo'],
    ]);
  });

  test('el ticket para imprimir trae los montos y no deja pasar HTML', () {
    final sale = Sale(
      id: 's1',
      folio: 7,
      createdAt: DateTime(2026, 11, 12, 10, 30),
      lines: const [SaleLine(key: 'k', name: 'Pan <dulce>', unitCents: 800, qty: 2)],
      kind: SaleKind.pagada,
      sessionId: 'c1',
      method: PayMethod.efectivo,
      receivedCents: 2000,
    );
    final html = ticketHtml(business: 'Tienda & Co', sale: sale);
    expect(html, contains('Tienda &amp; Co'));
    expect(html, contains('Pan &lt;dulce&gt;'));
    expect(html, contains('\$16.00'));
    expect(html, contains('\$4.00'));
    expect(html, contains('PAGADO'));
  });
}

String centsText(int cents) => (cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2);
