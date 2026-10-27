// Genera cuadros del inicio para revisarlos a ojo:
//   flutter test --run-skipped -t golden --update-goldens
// Las imágenes quedan en test/goldens/. (En pruebas el texto se dibuja como bloques.)
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/theme/theme.dart';
import 'package:gavilan/ui/splash/hawk.dart';
import 'package:gavilan/ui/splash/splash_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> loadSvgs(WidgetTester tester) async {
    // flutter_svg decodifica fuera del ciclo de prueba: le damos tiempo real.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
    }
  }

  testWidgets('cuadros del vuelo', (tester) async {
    tester.view.physicalSize = const Size(375 * 2, 812 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildGavilanTheme(),
        home: SplashScreen(onDone: () {}),
      ),
    );
    await loadSvgs(tester);

    var elapsed = 0;
    for (final ms in [700, 1150, 1700, 2200, 4000]) {
      await tester.pump(Duration(milliseconds: ms - elapsed));
      elapsed = ms;
      await expectLater(find.byType(SplashScreen), matchesGoldenFile('goldens/inicio_$ms.png'));
    }
  });

  testWidgets('poses del ala', (tester) async {
    tester.view.physicalSize = const Size(900, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFFF4ECDD),
          child: Row(
            children: [
              for (final u in [0.0, 0.2, 0.42, 0.72])
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Hawk(width: 200, pose: WingPose.flap(u)),
                ),
            ],
          ),
        ),
      ),
    );
    await loadSvgs(tester);
    await expectLater(find.byType(Row), matchesGoldenFile('goldens/poses_ala.png'));
  });
}
