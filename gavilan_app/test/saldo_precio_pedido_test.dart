import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/core/ticket_text.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/domain/purchases.dart';
import 'package:gavilan/domain/reports.dart';
import 'package:gavilan/domain/variants.dart';
import 'package:gavilan/state/seed.dart';
import 'package:gavilan/state/store.dart';

/// Saldo a favor en Cobrar, precio por talla y pedido sugerido al proveedor.
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

  const bolsa = Product(id: 'bolsa', name: 'Bolsa', priceCents: 40000, costCents: 20000, trackStock: true, stock: 5);

  /// Doña Lupe canceló un apartado y le quedaron $300 a favor.
  void giveCredit() {
    final l = store().addLayaway(customerId: 'c1', description: 'Vestido', totalCents: 60000, depositCents: 30000);
    store().cancelLayaway(l.id, creditCents: 30000);
  }

  group('Saldo a favor en Cobrar', () {
    test('paga parte de una venta; en la caja solo entra lo que falta', () {
      store().saveProduct(bolsa);
      giveCredit();
      expect(state().customersWithCredit.single.$2, 30000);
      final before = summary();
      // Como la hoja de cobro: $300 del saldo (como efectivo) y $100 con tarjeta.
      final sale = store().checkout(
        lines: [const SaleLine(key: 'b', productId: 'bolsa', name: 'Bolsa', unitCents: 40000, qty: 1)],
        kind: SaleKind.pagada,
        customerId: 'c1',
        payments: const [
          SalePayment(method: PayMethod.efectivo, amountCents: 30000),
          SalePayment(method: PayMethod.tarjeta, amountCents: 10000),
        ],
      );
      store().useCreditInSale(sale.id, 'c1', 30000);

      expect(state().creditOf('c1'), 0);
      expect(state().creditPaidOf(sale.id), 30000);
      final after = summary();
      expect(after.expectedCashCents, before.expectedCashCents);
      expect(after.creditUsedCents, 30000);
      expect(after.otherInCents, before.otherInCents + 10000);
      expect(after.totalSoldCents, before.totalSoldCents + 40000);
      final methods = {
        for (final m in byMethod([sale], storeCredit: {sale.id: 30000})) m.label: m.cents,
      };
      expect(methods, {'Saldo a favor': 30000, 'Tarjeta': 10000});
      final text = ticketText(business: 'Tienda', sale: sale, creditCents: 30000);
      expect(text, contains(r'Saldo a favor -$300.00'));
      expect(text, contains(r'Pagó $100.00 con tarjeta'));
    });

    test('no usa más saldo del que tiene', () {
      giveCredit();
      final sale = store().checkout(
        lines: const [SaleLine(key: 'x', name: 'Algo', unitCents: 50000, qty: 1)],
        kind: SaleKind.pagada,
        method: PayMethod.efectivo,
      );
      store().useCreditInSale(sale.id, 'c1', 50000);
      expect(state().creditPaidOf(sale.id), 30000);
      expect(state().creditOf('c1'), 0);
    });
  });

  group('Precio por talla', () {
    test('una talla puede costar distinto; las demás valen lo del modelo', () {
      const runner = Product(id: 'runner', name: 'Tenis', priceCents: 89900);
      store().saveModel(
        runner,
        [(size: '26', color: null, qty: 2), (size: '30', color: null, qty: 1)],
        prices: {variantKey('30', null): 99900},
      );
      final v = {for (final p in state().variantsOf('runner')) p.size: p.priceCents};
      expect(v, {'26': 89900, '30': 99900});

      // Al subir el precio del modelo, la talla con precio propio se queda con el suyo si se vuelve a dar.
      store().saveModel(
        runner.copyWith(priceCents: 94900),
        [(size: '26', color: null, qty: 0), (size: '30', color: null, qty: 0)],
        prices: {variantKey('30', null): 99900},
      );
      final w = {for (final p in state().variantsOf('runner')) p.size: p.priceCents};
      expect(w, {'26': 94900, '30': 99900});
    });
  });

  group('Pedido sugerido', () {
    test('pide lo que hace falta para que alcance, con el proveedor de la última compra', () {
      final now = DateTime.now();
      store().saveProduct(
        const Product(id: 'refresco', name: 'Refresco', priceCents: 2000, costCents: 1400, trackStock: true, stock: 4),
      );
      store().saveProduct(
        const Product(id: 'jabon', name: 'Jabón', priceCents: 2000, trackStock: true, stock: 1, minStock: 3),
      );
      store().saveProduct(const Product(id: 'clavo', name: 'Clavo', priceCents: 500, trackStock: true, stock: 50));
      final s = store().addSupplier('Refresquera');
      store().addPurchase(
        supplierId: s.id,
        lines: [const PurchaseLine(productId: 'refresco', name: 'Refresco', qty: 24, unitCostCents: 1400)],
        paidCents: 33600,
      );
      // Se vendieron 56 refrescos en las últimas 4 semanas: 2 al día.
      store().checkout(
        lines: const [SaleLine(key: 'r', productId: 'refresco', name: 'Refresco', unitCents: 2000, qty: 56)],
        kind: SaleKind.pagada,
        method: PayMethod.efectivo,
      );
      final lines = {for (final l in state().restockSuggestions(now: now)) l.product.id: l};
      // Refresco: hay 4 + 24 − 56 = −28; para una semana hacen falta 14 más lo que falta.
      expect(state().productById('refresco')!.stock, -28);
      expect(lines['refresco']!.qty, 2 * 7 + 28);
      expect(lines['refresco']!.supplierId, s.id);
      // Jabón: no se vende pero está bajo su mínimo.
      expect(lines['jabon']!.qty, 2);
      expect(lines['jabon']!.supplierId, isNull);
      // Clavo: alcanza.
      expect(lines.containsKey('clavo'), isFalse);
      // Para un mes se pide más.
      final month = {for (final l in state().restockSuggestions(now: now, coverDays: 30)) l.product.id: l};
      expect(month['refresco']!.qty, 2 * 30 + 28);

      final text = restockMessage(business: 'Tienda', supplier: 'Refresquera', lines: [('Refresco', 42)]);
      expect(text, contains('Hola Refresquera'));
      expect(text, contains('• 42 Refresco'));
    });
  });

  test('el saldo a favor usado se guarda en el teléfono', () async {
    final db = GavilanDb(NativeDatabase.memory());
    final repo = DriftRepository(db);
    Future<ProviderContainer> open() async {
      final loaded = await repo.load();
      return ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo), initialDataProvider.overrideWithValue(loaded)],
      );
    }

    var phone = await open();
    final n = phone.read(storeProvider.notifier);
    n.startBusiness('Boutique');
    n.openCash(0);
    final c = n.addCustomer('Doña Mary');
    final l = n.addLayaway(customerId: c.id, description: 'Vestido', totalCents: 50000, depositCents: 20000);
    n.cancelLayaway(l.id, creditCents: 20000);
    final sale = n.checkout(
      lines: const [SaleLine(key: 'x', name: 'Blusa', unitCents: 25000, qty: 1)],
      kind: SaleKind.pagada,
      method: PayMethod.efectivo,
      receivedCents: 25000,
      customerId: c.id,
    );
    n.useCreditInSale(sale.id, c.id, 20000);
    await n.flush();
    final expected = phone.read(storeProvider).summaryFor(phone.read(storeProvider).openSession!).expectedCashCents;
    phone.dispose();

    phone = await open();
    final s = phone.read(storeProvider);
    expect(s.creditPaidOf(sale.id), 20000);
    expect(s.creditOf(c.id), 0);
    expect(s.summaryFor(s.openSession!).expectedCashCents, expected);
    expect(expected, 20000 + 5000); // el anticipo de antes y los $50 que faltaban
    phone.dispose();
    await db.close();
  });
}
