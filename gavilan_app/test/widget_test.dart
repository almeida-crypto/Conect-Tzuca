import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/app.dart';
import 'package:gavilan/ui/cobrar/ticket_screen.dart';
import 'package:gavilan/ui/widgets/buttons.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: GavilanApp(showSplash: false)));
    await tester.pump();
  }

  testWidgets('arranca en la caja con los productos de ejemplo', (tester) async {
    await start(tester);
    expect(find.text('Abarrotes Doña Mary'), findsOneWidget);
    expect(find.text('Coca 600 ml'), findsOneWidget);
    expect(find.text('Cobrar'), findsWidgets);
  });

  testWidgets('cobrar en efectivo muestra el ticket con el cambio', (tester) async {
    await start(tester);
    await tester.tap(find.text('Coca 600 ml'));
    await tester.tap(find.text('Coca 600 ml'));
    await tester.pump();
    expect(find.text('\$36.00'), findsWidgets);

    await tester.tap(find.widgetWithText(GButton, 'Cobrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\$50'));
    await tester.pump();
    expect(find.text('\$14.00'), findsOneWidget);

    await tester.tap(find.text('Cobrar en efectivo'));
    await tester.pumpAndSettle();
    expect(find.byType(TicketScreen), findsOneWidget);
    expect(find.text('PAGADO'), findsOneWidget);
  });
}
