import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/domain/reports.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';
import 'package:gavilan/theme/theme.dart';
import 'package:gavilan/ui/caja/reports_screen.dart';
import 'package:google_fonts/google_fonts.dart';

/// Los reportes del dueño, ahora dentro de la app (antes solo en el panel web).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final now = DateTime(2026, 11, 18, 15);

  Sale sale(
    String id,
    DateTime at,
    int cents, {
    String session = 'a',
    PayMethod method = PayMethod.efectivo,
    SaleKind kind = SaleKind.pagada,
    String? clerk,
    int cost = 0,
    bool cancelled = false,
    List<SalePayment> payments = const [],
  }) => Sale(
    id: id,
    folio: int.parse(id.replaceAll(RegExp(r'\D'), '').padLeft(1, '0')),
    createdAt: at,
    lines: [
      SaleLine(key: id, productId: 'p$cents', name: 'Producto $cents', unitCents: cents, qty: 1, unitCostCents: cost),
    ],
    kind: kind,
    sessionId: session,
    method: kind == SaleKind.fiada ? null : method,
    clerk: clerk,
    cancelledAt: cancelled ? at : null,
    payments: payments,
  );

  group('periodos', () {
    test('hoy, ayer, 7 días, este mes y mes pasado', () {
      final hoy = periodFor(PeriodKey.hoy, now: now);
      expect((hoy.from, hoy.to, hoy.days), (DateTime(2026, 11, 18), DateTime(2026, 11, 19), 1));
      final ayer = periodFor(PeriodKey.ayer, now: now);
      expect((ayer.from, ayer.to), (DateTime(2026, 11, 17), DateTime(2026, 11, 18)));
      expect(periodFor(PeriodKey.semana, now: now).days, 7);
      expect(periodFor(PeriodKey.mes, now: now).from, DateTime(2026, 11));
      final pasado = periodFor(PeriodKey.mesPasado, now: now);
      expect((pasado.from, pasado.to), (DateTime(2026, 10), DateTime(2026, 11)));
      expect(periodFor(PeriodKey.semana, now: now).previous.to, DateTime(2026, 11, 12));
    });

    test('rango de fechas: los dos días incluidos, aunque vengan al revés', () {
      final r = rangePeriod(DateTime(2026, 11, 20), DateTime(2026, 11, 3));
      expect((r.from, r.to, r.days), (DateTime(2026, 11, 3), DateTime(2026, 11, 21), 18));
      expect(r.label, '3 nov al 20 nov 2026');
      expect(rangePeriod(DateTime(2026, 1, 5), DateTime(2026, 1, 5)).label, '5 ene 2026');
    });
  });

  test('ventas del periodo sin canceladas; por día, hora, forma de pago, persona y caja', () {
    final all = [
      sale('s1', DateTime(2026, 11, 18, 9), 10000, clerk: 'Ana'),
      sale('s2', DateTime(2026, 11, 18, 9, 30), 5000, method: PayMethod.tarjeta, clerk: 'Luis', session: 'b'),
      sale('s3', DateTime(2026, 11, 18, 13), 3000, kind: SaleKind.fiada, clerk: 'Ana'),
      sale('s4', DateTime(2026, 11, 18, 14), 9999, cancelled: true),
      sale(
        's5',
        DateTime(2026, 11, 18, 22),
        4000,
        payments: const [
          SalePayment(method: PayMethod.efectivo, amountCents: 1000),
          SalePayment(method: PayMethod.transferencia, amountCents: 3000),
        ],
      ),
      sale('s6', DateTime(2026, 11, 17, 12), 7000),
    ];
    final p = periodFor(PeriodKey.hoy, now: now);
    final sales = salesIn(all, p);
    expect(sales.map((s) => s.id), ['s1', 's2', 's3', 's5']);
    final t = totalsOf(sales);
    expect((t.cents, t.count, t.averageCents), (22000, 4, 5500));
    expect(changePct(22000, totalsOf(salesIn(all, p.previous)).cents)!.round(), 214);

    final hours = byHour(sales);
    expect(hours.first.label, '7');
    expect(hours.last.label, '22'); // pasa de las 21 porque hubo una venta a las 22
    expect(hours.firstWhere((b) => b.label == '9').cents, 15000);

    final week = byDay(salesIn(all, periodFor(PeriodKey.semana, now: now)), periodFor(PeriodKey.semana, now: now));
    expect(week.length, 7);
    expect(week.last.cents, 22000);
    expect(week[5].cents, 7000);

    final methods = {for (final m in byMethod(sales)) m.label: m.cents};
    expect(methods, {'Efectivo': 11000, 'Tarjeta': 5000, 'Fiado': 3000, 'Transferencia': 3000});

    final clerks = {for (final c in byClerk(sales)) c.label: (c.cents, c.count)};
    expect(clerks, {'Ana': (13000, 2), 'Luis': (5000, 1), 'Sin PIN': (4000, 1)});
    expect(byClerk([sales.last]), isEmpty); // sin PIN nadie tiene nombre

    final registers = byRegister(sales, (s) => s.sessionId == 'b' ? 'Barra' : 'Mostrador');
    expect(registers.first.label, 'Mostrador');
    expect(registers.first.share, closeTo(17000 / 22000, 0.001));
  });

  test('descargas para Excel: fecha legible, formas de pago y celdas seguras', () {
    final s = [
      sale(
        's1',
        DateTime(2026, 11, 18, 9, 5),
        4000,
        clerk: '=HACK()',
        payments: const [
          SalePayment(method: PayMethod.efectivo, amountCents: 1000),
          SalePayment(method: PayMethod.tarjeta, amountCents: 3000),
        ],
      ),
    ];
    final csv = salesCsv(s, (_) => 'Caja, la de "arriba"');
    expect(csv.startsWith('﻿Fecha,Folio,Total'), isTrue);
    expect(csv, contains('2026-11-18 09:05,1,40.00,0.00,Efectivo 10.00 + Tarjeta 30.00,\'=HACK(),"Caja, la de ""arriba"""'));

    final products = productsCsv(profitIn([sale('s2', now, 1000, cost: 1200), sale('s3', now, 500)]));
    expect(products, contains('Producto 1000,1,10.00,12.00,-2.00,-20'));
    expect(products, contains('Producto 500,1,5.00,,,'));
  });

  group('pantalla', () {
    Widget app(Plan plan) {
      final seed = seedStore(now);
      return ProviderScope(
        overrides: [initialDataProvider.overrideWithValue(LoadedData(store: seed, plan: plan))],
        child: MaterialApp(
          // Sin el destello de tinta (su sombreador no se carga en las pruebas).
          theme: buildGavilanTheme().copyWith(splashFactory: InkRipple.splashFactory),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(onPressed: () => openReports(context, ref), child: const Text('Abrir')),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Semilla: candado y explicación del plan', (tester) async {
      await tester.pumpWidget(app(Plan.semilla));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportsScreen), findsNothing);
      expect(find.text('Disponible en plan Emprendedor'), findsOneWidget);
    });

    testWidgets('Emprendedor: abre con periodos, gráfica y descargas', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(Plan.emprendedor));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportsScreen), findsOneWidget);
      expect(find.text('Reportes'), findsOneWidget);
      expect(find.text('Este mes'), findsOneWidget);
      expect(find.text('Elegir fechas'), findsOneWidget);
      await tester.tap(find.text('7 días'));
      await tester.pumpAndSettle();
      expect(find.text('Últimos 7 días · todas las cajas'), findsOneWidget);
      expect(find.text('Ventas por día'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
