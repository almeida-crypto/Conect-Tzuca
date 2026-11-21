import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/layaway_rules.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/domain/variants.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';

/// Zapaterías y tiendas de ropa: tallas y colores, apartar piezas del inventario, reglas del dueño al cancelar,
/// entregado y recordatorios.
void main() {
  late ProviderContainer app;
  StoreNotifier store() => app.read(storeProvider.notifier);
  StoreState state() => app.read(storeProvider);
  CashSummary summary() => state().summaryFor(state().openSession!);

  setUp(
    () => app = ProviderContainer(
      overrides: [
        initialDataProvider.overrideWithValue(LoadedData(store: seedStore(DateTime.now()), plan: Plan.negocio)),
      ],
    ),
  );
  tearDown(() => app.dispose());

  const runner = Product(id: 'runner', name: 'Tenis Runner', priceCents: 89900, costCents: 50000, iconId: 'ropa');

  Product variant(String size, [String? color]) =>
      state().variantsOf('runner').firstWhere((v) => v.size == size && v.color == color);

  group('Tallas y colores', () {
    test('un modelo con sus tallas: cada talla lleva sus piezas y el modelo no se vende solo', () {
      final productsBefore = state().activeProducts.length;
      store().saveModel(runner, [
        (size: '25', color: 'Negro', qty: 2),
        (size: '26', color: 'Negro', qty: 3),
        (size: '26', color: 'Blanco', qty: 0),
      ], minStock: 1);

      final s = state();
      final model = s.productById('runner')!;
      expect(s.isModel(model), isTrue);
      expect((model.trackStock, model.stock, model.barcode), (false, 0.0, null));
      // Para el plan y las listas cuenta el modelo, no cada talla.
      expect(s.activeProducts.length, productsBefore + 1);
      expect(s.sellableProducts.any((p) => p.id == 'runner'), isFalse);
      expect(s.variantsOf('runner').map((v) => v.variantLabel), ['25 · Negro', '26 · Blanco', '26 · Negro']);
      expect(variant('26', 'Negro').name, 'Tenis Runner · 26 · Negro');
      expect((variant('26', 'Negro').priceCents, variant('26', 'Negro').costCents), (89900, 50000));
      expect(s.stockOfModel('runner'), 5);
      expect(variant('25', 'Negro').isLow, isFalse); // 2 piezas con aviso en 1: todavía no
      expect(variant('26', 'Blanco').isLow, isTrue);
    });

    test('al editar: llegan piezas, cambia el precio y la talla que se quita se oculta', () {
      store().saveModel(runner, [(size: '25', color: null, qty: 2), (size: '26', color: null, qty: 1)]);
      final old26 = variant('26');
      store().saveModel(runner.copyWith(name: 'Tenis Runner Pro', priceCents: 99900), [
        (size: '26', color: null, qty: 4), // llegaron 4
        (size: '27', color: null, qty: 5),
      ]);
      final s = state();
      expect(s.variantsOf('runner').map((v) => v.size), ['26', '27']);
      expect(variant('26').id, old26.id); // la misma talla, no una nueva
      expect(variant('26').stock, 5);
      expect(variant('26').name, 'Tenis Runner Pro · 26');
      expect(variant('27').priceCents, 99900);
      // La 25 no se borra: sus ventas siguen en los reportes.
      expect(s.products.where((p) => p.parentId == 'runner' && !p.active).single.size, '25');
    });

    test('un producto suelto con piezas pasa a tener tallas: su existencia se reparte', () {
      store().saveProduct(const Product(id: 'blusa', name: 'Blusa', priceCents: 25000, trackStock: true, stock: 6));
      store().saveModel(state().productById('blusa')!, [
        (size: 'CH', color: null, qty: 2),
        (size: 'M', color: null, qty: 4),
      ]);
      expect(state().productById('blusa')!.stock, 0);
      expect(state().stockOfModel('blusa'), 6);
    });

    test('"ya no lo vendo" oculta el modelo y todas sus tallas', () {
      store().saveModel(runner, [(size: '25', color: null, qty: 2)]);
      store().hideProduct('runner');
      expect(state().activeProducts.any((p) => p.id == 'runner'), isFalse);
      expect(state().sellableProducts.any((p) => p.parentId == 'runner'), isFalse);
    });

    test('las tallas se escriben con comas y se ordenan como en la tienda', () {
      expect(splitVariantList(' 22, 23 ,24,,23 / 25'), ['22', '23', '24', '25']);
      expect((['G', 'CH', 'XG', 'M']..sort(compareSizes)), ['CH', 'M', 'G', 'XG']);
      expect((['26', '25.5', '9']..sort(compareSizes)), ['9', '25.5', '26']);
      expect(variantCombos(['25', '26'], []), [(size: '25', color: null), (size: '26', color: null)]);
      expect(variantCombos([], ['Rojo']), [(size: null, color: 'Rojo')]);
      // Un nombre largo se recorta sin perder la talla.
      expect(
        variantName('Tenis deportivo para correr con amortiguación extra y suela', '26.5', 'Negro'),
        endsWith(' · 26.5 · Negro'),
      );
      expect(
        variantName('Tenis deportivo para correr con amortiguación extra y suela', '26.5', 'Negro').length,
        lessThanOrEqualTo(60),
      );
    });
  });

  group('Apartar piezas del inventario', () {
    test('la pieza apartada sale de la existencia, se ve como apartada y regresa si cancela', () {
      store().saveModel(runner, [(size: '26', color: null, qty: 3)]);
      final talla = variant('26');
      final l = store().addLayaway(
        customerId: 'c1',
        totalCents: 89900,
        depositCents: 20000,
        items: [(productId: talla.id, name: talla.name, qty: 1, unitCents: talla.priceCents)],
      );
      expect(l.description, 'Tenis Runner · 26');
      expect(variant('26').stock, 2);
      expect(state().reservedOf(talla.id), 1);
      expect(state().itemsOfLayaway(l.id).single.productId, talla.id);

      store().cancelLayaway(l.id);
      expect(variant('26').stock, 3);
      expect(state().reservedOf(talla.id), 0);
    });

    test('liquidado sigue apartado hasta que se lo lleva; entregado ya no', () {
      store().saveProduct(const Product(id: 'bolsa', name: 'Bolsa', priceCents: 50000, trackStock: true, stock: 1));
      final l = store().addLayaway(
        customerId: 'c1',
        totalCents: 50000,
        depositCents: 50000,
        items: [(productId: 'bolsa', name: 'Bolsa', qty: 1, unitCents: 50000)],
      );
      final paid = state().layawayById(l.id)!;
      expect((paid.status, paid.kept, paid.delivered), (LayawayStatus.liquidado, true, false));
      expect(state().reservedOf('bolsa'), 1);

      store().deliverLayaway(l.id);
      final done = state().layawayById(l.id)!;
      expect((done.delivered, done.kept), (true, false));
      expect(state().reservedOf('bolsa'), 0);
      expect(state().productById('bolsa')!.stock, 0); // ya no está en la tienda
      store().cancelLayaway(l.id); // entregado ya no se cancela
      expect(state().layawayById(l.id)!.status, LayawayStatus.liquidado);
    });
  });

  group('Reglas del dueño al cancelar', () {
    test('cuánto se devuelve con cada regla', () {
      expect(cancelSplit(CancelRule.devolverTodo, paid: 50000, deposit: 20000), (refund: 50000, credit: 0, kept: 0));
      expect(cancelSplit(CancelRule.quedarsePorcentaje, paid: 50000, deposit: 20000, keepPct: 10), (
        refund: 45000,
        credit: 0,
        kept: 5000,
      ));
      expect(cancelSplit(CancelRule.quedarseAnticipo, paid: 50000, deposit: 20000), (
        refund: 30000,
        credit: 0,
        kept: 20000,
      ));
      expect(cancelSplit(CancelRule.noDevolver, paid: 50000, deposit: 20000), (refund: 0, credit: 0, kept: 50000));
      expect(cancelSplit(CancelRule.saldoAFavor, paid: 50000, deposit: 20000), (refund: 0, credit: 50000, kept: 0));
    });

    test('las reglas viajan como JSON y sin configurar son las de siempre', () {
      const rules = LayawayRules(
        cancel: CancelRule.quedarsePorcentaje,
        keepPct: 15,
        days: 45,
        minDepositPct: 20,
        note: 'Sin cambios',
      );
      final back = LayawayRules.fromJson(rules.toJson());
      expect(
        (back.cancel, back.keepPct, back.days, back.minDepositPct, back.note),
        (CancelRule.quedarsePorcentaje, 15, 45, 20, 'Sin cambios'),
      );
      expect(back.minDepositFor(89900), 17980);
      expect(LayawayRules.fromJson(null).isStandard, isTrue);
      expect(LayawayRules.fromJson({'cancel': 'algo raro'}).cancel, CancelRule.preguntar);
      expect(LayawayRules.fromJson({'days': null}).days, isNull);
      store().setLayawayRules(rules);
      expect(state().layawayRules.days, 45);
    });

    test('lo que se devuelve en efectivo sale de la caja y queda anotado en el apartado', () {
      final l = store().addLayaway(customerId: 'c1', description: 'Vestido', totalCents: 60000, depositCents: 20000);
      store().addLayawayPayment(l.id, 10000, PayMethod.efectivo);
      final before = summary();
      store().cancelLayaway(l.id, refundCents: 27000, refundFromCash: true);
      final after = summary();
      expect(after.gastosCents, before.gastosCents + 27000);
      expect(after.expectedCashCents, before.expectedCashCents - 27000);
      final cancelled = state().layawayById(l.id)!;
      expect((cancelled.status, cancelled.refundCents, cancelled.creditCents), (LayawayStatus.cancelado, 27000, 0));
      expect(state().movements.last.concept, contains('Devolución de apartado'));
    });

    test('el saldo a favor se usa en otro apartado sin volver a entrar a la caja', () {
      final first = store().addLayaway(
        customerId: 'c1',
        description: 'Vestido',
        totalCents: 60000,
        depositCents: 30000,
      );
      store().cancelLayaway(first.id, creditCents: 30000);
      expect(state().creditOf('c1'), 30000);

      final cashBefore = summary().cashLayawayCents;
      final second = store().addLayaway(
        customerId: 'c1',
        description: 'Zapatos',
        totalCents: 50000,
        depositCents: 5000,
        useCreditCents: 30000,
      );
      expect(state().paidOfLayaway(second.id), 35000);
      expect(state().creditOf('c1'), 0);
      expect(state().creditLeftOf(first.id), 0);
      final fromCredit = state().paymentsOfLayaway(second.id).where((p) => p.fromCredit).single;
      expect((fromCredit.amountCents, fromCredit.fromLayawayId, fromCredit.sessionId), (30000, first.id, null));
      // Solo los $50 del anticipo nuevo entran a la caja.
      expect(summary().cashLayawayCents, cashBefore + 5000);
    });

    test('si el saldo alcanza para todo, queda liquidado en el momento', () {
      final first = store().addLayaway(
        customerId: 'c1',
        description: 'Vestido',
        totalCents: 60000,
        depositCents: 60000,
      );
      store().cancelLayaway(first.id, creditCents: 60000);
      final second = store().addLayaway(
        customerId: 'c1',
        description: 'Bolsa',
        totalCents: 45000,
        useCreditCents: 45000,
      );
      expect(state().layawayById(second.id)!.status, LayawayStatus.liquidado);
      expect(state().creditOf('c1'), 15000);
    });
  });

  group('Recordatorios', () {
    final now = DateTime(2026, 11, 20, 10);
    Layaway layaway({DateTime? due, int? every, DateTime? reminded, LayawayStatus status = LayawayStatus.activo}) =>
        Layaway(
          id: 'l',
          customerId: 'c1',
          description: 'Tenis',
          totalCents: 50000,
          createdAt: DateTime(2026, 11, 1),
          dueDate: due,
          payEveryDays: every,
          remindedAt: reminded,
          status: status,
        );

    test('avisa cuando se acerca la fecha, cuando ya pasó y cuando le toca abonar', () {
      ReminderReason? r(Layaway l, {DateTime? last}) =>
          reminderFor(l, pendingCents: 30000, lastPaymentAt: last, now: now);
      expect(r(layaway(due: DateTime(2026, 11, 22))), ReminderReason.vence);
      expect(r(layaway(due: DateTime(2026, 12, 15))), isNull);
      expect(r(layaway(due: DateTime(2026, 11, 18))), ReminderReason.vencido);
      expect(r(layaway(every: 7), last: DateTime(2026, 11, 12)), ReminderReason.abono);
      expect(r(layaway(every: 7), last: DateTime(2026, 11, 15)), isNull);
      expect(r(layaway(status: LayawayStatus.liquidado)), ReminderReason.recoger);
      // Ya se le avisó ayer: no se le insiste todavía.
      expect(r(layaway(due: DateTime(2026, 11, 18), reminded: DateTime(2026, 11, 19, 18))), isNull);
      expect(r(layaway(due: DateTime(2026, 11, 18), reminded: DateTime(2026, 11, 17))), ReminderReason.vencido);
    });

    test('el mensaje dice lo que falta y la fecha', () {
      final text = reminderMessage(
        ReminderReason.vence,
        business: 'Zapatería Lupita',
        customer: 'Doña Mary Pech',
        what: 'Tenis Runner · 26',
        pending: r'$300.00',
        paid: r'$599.00',
        total: r'$899.00',
        due: '22/11/2026',
      );
      expect(text, startsWith('Hola Doña,'));
      expect(text, contains('vence el 22/11/2026'));
      expect(text, contains(r'Te faltan $300.00'));
    });

    test('al mandarlo se anota para no repetirlo', () {
      final l = store().addLayaway(customerId: 'c1', description: 'Tenis', totalCents: 50000);
      store().markLayawayReminded(l.id);
      expect(state().layawayById(l.id)!.remindedAt, isNotNull);
    });
  });

  test('tallas, piezas apartadas, entregado, saldo a favor y reglas se guardan en el teléfono', () async {
    final db = GavilanDb(NativeDatabase.memory());
    final repo = DriftRepository(db);
    Future<ProviderContainer> open() async {
      final loaded = await repo.load();
      return ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(loaded)],
      );
    }

    var phone = await open();
    var n = phone.read(storeProvider.notifier);
    n.startBusiness('Zapatería Lupita');
    n.openCash(50000);
    final c = n.addCustomer('Doña Mary');
    n.saveModel(runner, [(size: '26', color: 'Negro', qty: 2)]);
    final talla = phone.read(storeProvider).variantsOf('runner').single;
    final l = n.addLayaway(
      customerId: c.id,
      totalCents: 89900,
      depositCents: 89900,
      payEveryDays: 7,
      items: [(productId: talla.id, name: talla.name, qty: 1, unitCents: talla.priceCents)],
    );
    n.deliverLayaway(l.id);
    final other = n.addLayaway(customerId: c.id, description: 'Sandalias', totalCents: 40000, depositCents: 10000);
    n.cancelLayaway(other.id, creditCents: 10000);
    n.setLayawayRules(const LayawayRules(cancel: CancelRule.saldoAFavor, days: 60));
    await n.flush();
    phone.dispose();

    phone = await open();
    final s = phone.read(storeProvider);
    expect(s.variantsOf('runner').single.variantLabel, '26 · Negro');
    expect(s.variantsOf('runner').single.stock, 1);
    final back = s.layawayById(l.id)!;
    expect((back.delivered, back.payEveryDays), (true, 7));
    expect(s.itemsOfLayaway(l.id).single.name, 'Tenis Runner · 26 · Negro');
    expect(s.creditOf(c.id), 10000);
    expect((s.layawayRules.cancel, s.layawayRules.days), (CancelRule.saldoAFavor, 60));
    phone.dispose();
    await db.close();
  });
}
