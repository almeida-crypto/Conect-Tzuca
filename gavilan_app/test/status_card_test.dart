import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/ui/inventario/status_card_screen.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tarjeta para Estados de WhatsApp.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, {bool showPrice = true, bool watermark = false}) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: StatusCard(
          product: const Product(id: 'v', name: 'Vestido azul', priceCents: 35000),
          businessName: 'Boutique La Esperanza',
          stamp: 'Recién llegado',
          color: StatusCardColor.cenote,
          showPrice: showPrice,
          watermark: watermark,
        ),
      ),
    );
  }

  testWidgets('lleva el negocio, el producto, el precio y el sello; sin foto, el icono', (tester) async {
    await pump(tester);
    expect(find.text('BOUTIQUE LA ESPERANZA'), findsOneWidget);
    expect(find.text('Vestido azul'), findsOneWidget);
    expect(find.text(r'$350'), findsOneWidget);
    expect(find.text('RECIÉN LLEGADO'), findsOneWidget);
    expect(find.text('Hecho con Gavilán'), findsNothing);
    expect(tester.takeException(), isNull); // cabe sin desbordarse
  });

  testWidgets('sin precio y, en el plan gratis, con la marca de agua', (tester) async {
    await pump(tester, showPrice: false, watermark: true);
    expect(find.text(r'$350'), findsNothing);
    expect(find.text('Hecho con Gavilán'), findsOneWidget);
  });
}
