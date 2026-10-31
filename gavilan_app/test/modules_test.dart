import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';

void main() {
  late ProviderContainer app;
  StoreNotifier store() => app.read(storeProvider.notifier);
  StoreState state() => app.read(storeProvider);
  CashSummary summary() => state().summaryFor(state().openSession!);

  setUp(
    () => app = ProviderContainer(
      overrides: [
        initialDataProvider.overrideWithValue(LoadedData(store: seedStore(DateTime.now()), plan: Plan.semilla)),
      ],
    ),
  );
  tearDown(() => app.dispose());

  group('Pacas y lotes', () {
    test('lleva lo recuperado y pasa a ganancia', () {
      final lot = store().addLot('Paca de ropa americana', 350000);
      store().addLotSale(lot.id, 120000);
      store().addLotSale(lot.id, 150000, note: '6 blusas');
      expect(state().recoveredOfLot(lot.id), 270000);
      expect(state().openLots, hasLength(1));

      store().addLotSale(lot.id, 100000);
      expect(state().recoveredOfLot(lot.id) - lot.investmentCents, 20000); // ya es ganancia
      expect(state().salesOfLot(lot.id).first.amountCents, 100000); // la más reciente primero
    });

    test('lo cobrado de la paca entra en efectivo al corte', () {
      final before = summary();
      final lot = store().addLot('Lote de juguetes', 100000);
      store().addLotSale(lot.id, 25000);
      expect(summary().lotSalesCents, 25000);
      expect(summary().expectedCashCents, before.expectedCashCents + 25000);
      expect(summary().totalSoldCents, before.totalSoldCents + 25000);
    });

    test('al cerrar ya no cuenta como activa', () {
      final lot = store().addLot('Paca', 1000);
      store().closeLot(lot.id);
      expect(state().openLots, isEmpty);
      expect(state().lots.single.closedAt, isNotNull);
    });
  });

  group('Apartados', () {
    test('anticipo y abonos hasta liquidar', () {
      final l = store().addLayaway(
        customerId: 'c1',
        description: 'Vestido azul talla M',
        totalCents: 60000,
        depositCents: 20000,
      );
      expect(state().paidOfLayaway(l.id), 20000);
      expect(state().pendingOfLayaway(l.id), 40000);
      expect(state().layawayById(l.id)!.status, LayawayStatus.activo);
      // El anticipo lleva la hora del apartado: así se distingue de los abonos.
      expect(state().paymentsOfLayaway(l.id).single.createdAt, l.createdAt);

      store().addLayawayPayment(l.id, 25000, PayMethod.efectivo);
      expect(state().layawayById(l.id)!.status, LayawayStatus.activo);
      store().addLayawayPayment(l.id, 15000, PayMethod.transferencia);
      expect(state().pendingOfLayaway(l.id), 0);
      expect(state().layawayById(l.id)!.status, LayawayStatus.liquidado);
    });

    test('al corte entra solo lo pagado en efectivo; lo demás va aparte', () {
      final before = summary();
      final l = store().addLayaway(customerId: 'c1', description: 'Tenis', totalCents: 90000, depositCents: 30000);
      store().addLayawayPayment(l.id, 10000, PayMethod.tarjeta);
      expect(summary().cashLayawayCents, 30000);
      expect(summary().otherLayawayCents, 10000);
      expect(summary().expectedCashCents, before.expectedCashCents + 30000);
    });

    test('cancelar no borra lo abonado', () {
      final l = store().addLayaway(customerId: 'c1', description: 'Bolsa', totalCents: 50000, depositCents: 10000);
      store().cancelLayaway(l.id);
      expect(state().layawayById(l.id)!.status, LayawayStatus.cancelado);
      expect(state().paidOfLayaway(l.id), 10000);
    });
  });

  group('Pedidos por tanda', () {
    test('pedidos, entrega, pago e insumos', () {
      final cashBefore = summary().expectedCashCents;
      final t = store().addBatch('Cochinita del domingo', DateTime(2026, 11, 1));
      final a = store().addBatchOrder(batchId: t.id, customerName: 'Doña Lupe', totalCents: 18000, detail: '1 kg');
      store().addBatchOrder(batchId: t.id, customerName: 'Don Beto', totalCents: 9000);
      store().setBatchSupplies(t.id, 12000);
      store().updateBatchOrder(a.copyWith(delivery: DeliveryStatus.entregado, paid: true));

      final orders = state().ordersOfBatch(t.id);
      expect(orders, hasLength(2));
      expect(orders.first.paid, isTrue);
      expect(orders.first.delivery, DeliveryStatus.entregado);
      expect(state().batchById(t.id)!.suppliesCents, 12000);
      // Las tandas no tocan el corte de caja.
      expect(summary().expectedCashCents, cashBefore);
    });
  });

  test('los tres módulos se guardan en el teléfono y vuelven al abrir', () async {
    final db = GavilanDb(NativeDatabase.memory());
    final repo = DriftRepository(db);
    var phone = ProviderContainer(overrides: [repositoryProvider.overrideWithValue(repo)]);
    final n = phone.read(storeProvider.notifier);
    n.loadDemo();
    final lot = n.addLot('Paca', 300000);
    n.addLotSale(lot.id, 50000, note: 'chamarras');
    final l = n.addLayaway(
      customerId: 'c1',
      description: 'Vestido',
      totalCents: 60000,
      depositCents: 20000,
      dueDate: DateTime(2026, 12, 1),
    );
    final t = n.addBatch('Marquesitas', DateTime(2026, 11, 7));
    final o = n.addBatchOrder(batchId: t.id, customerName: 'Pedro', totalCents: 7000, phone: '9971112233');
    n.updateBatchOrder(o.copyWith(paid: true, delivery: DeliveryStatus.listo));
    n.setBatchSupplies(t.id, 2500);
    await n.flush();
    phone.dispose();

    phone = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(await repo.load())],
    );
    final s = phone.read(storeProvider);
    expect(s.recoveredOfLot(lot.id), 50000);
    expect(s.salesOfLot(lot.id).single.note, 'chamarras');
    expect(s.pendingOfLayaway(l.id), 40000);
    expect(s.layawayById(l.id)!.dueDate, DateTime(2026, 12, 1));
    final order = s.ordersOfBatch(t.id).single;
    expect(order.paid, isTrue);
    expect(order.delivery, DeliveryStatus.listo);
    expect(order.phone, '9971112233');
    expect(s.batchById(t.id)!.suppliesCents, 2500);
    expect(s.summaryFor(s.openSession!).lotSalesCents, 50000);
    phone.dispose();
    await db.close();
  });
}
