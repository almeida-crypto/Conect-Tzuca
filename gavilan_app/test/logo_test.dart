import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/core/logo.dart';
import 'package:gavilan/core/ticket_html.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/state/store.dart';

/// El logo del negocio en el ticket.
void main() {
  final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
  final sale = Sale(
    id: 's',
    folio: 7,
    createdAt: DateTime(2026, 11, 18, 10),
    lines: const [SaleLine(key: 'l', productId: 'p', name: 'Coca', unitCents: 1800, unitCostCents: 1200, qty: 1)],
    kind: SaleKind.pagada,
    sessionId: 'c',
    method: PayMethod.efectivo,
    receivedCents: 2000,
  );

  test('el ticket impreso lleva el logo dentro del mismo HTML, y sin logo no lleva imagen', () {
    final withLogo = ticketHtml(business: 'La Esperanza', sale: sale, logo: png);
    expect(withLogo, contains('<img class="logo" alt="" src="data:image/png;base64,iVBORwECAw=="'));
    expect(ticketHtml(business: 'La Esperanza', sale: sale), isNot(contains('<img')));
    expect(imageDataUri(Uint8List.fromList([0xFF, 0xD8, 0xFF])), startsWith('data:image/jpeg;base64,'));
  });

  test('solo los planes de pago traen el logo', () {
    expect(Plan.semilla.limits.logo, isFalse);
    expect(Plan.emprendedor.limits.logo, isTrue);
    expect(Plan.negocio.limits.logo, isTrue);
  });

  testWidgets('el logo queda chico, sin deformarse y con fondo blanco en lugar de transparente', (tester) async {
    await tester.runAsync(() async {
      // Un logo de 1000×500 transparente con un cuadro negro en medio.
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(400, 200, 200, 100), ui.Paint());
      final image = await recorder.endRecording().toImage(1000, 500);
      final raw = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

      final logo = (await prepareLogo(raw))!;
      expect(logo.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]); // PNG
      final codec = await ui.instantiateImageCodec(logo);
      final out = (await codec.getNextFrame()).image;
      expect((out.width, out.height), (480, 240)); // cabe en 600×240 sin deformarse
      final pixels = (await out.toByteData())!; // RGBA
      expect([for (var i = 0; i < 4; i++) pixels.getUint8(i)], [255, 255, 255, 255]); // esquina: blanco
      final middle = (120 * 480 + 240) * 4;
      expect(pixels.getUint8(middle), lessThan(30)); // el cuadro sigue negro

      expect(await prepareLogo(Uint8List.fromList([1, 2, 3])), isNull); // no es imagen
    });
  });

  test('el logo se guarda en el teléfono y se puede quitar', () async {
    final db = GavilanDb(NativeDatabase.memory());
    final repo = DriftRepository(db);
    Future<ProviderContainer> open() async => ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(await repo.load())],
    );

    var app = await open();
    var n = app.read(storeProvider.notifier);
    n.startBusiness('La Esperanza');
    n.setLogo(png);
    final path = app.read(storeProvider).logoPath!;
    expect(path, matches(RegExp(r'/logo-\d+\.png$')));
    await n.flush();
    app.dispose();

    app = await open();
    expect(app.read(storeProvider).logo, png);
    n = app.read(storeProvider.notifier);
    n.setLogo(null);
    await n.flush();
    app.dispose();

    app = await open();
    expect(app.read(storeProvider).logoPath, isNull);
    expect(await repo.photoPaths(), isEmpty);
    app.dispose();
    await db.close();
  });
}
