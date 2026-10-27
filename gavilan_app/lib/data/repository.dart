import 'package:drift/drift.dart';

import '../domain/models.dart';
import '../domain/plan.dart';
import '../state/store.dart';
import 'database.dart';

/// Lo que se recupera al abrir la app.
class LoadedData {
  const LoadedData({required this.store, required this.plan});

  final StoreState store;
  final Plan plan;
}

/// Dónde se guardan los datos. La app solo habla con esta interfaz, así se puede
/// cambiar el almacenamiento (Drift hoy, PowerSync después) sin tocar las pantallas.
abstract class StoreRepository {
  /// null si todavía no hay negocio (primer arranque).
  Future<LoadedData?> load();

  /// Reemplaza todo (alta del negocio o datos de ejemplo).
  Future<void> replaceAll(StoreState state, Plan plan);
  Future<void> clear();

  Future<void> upsertProduct(Product product);
  Future<void> recordSale({
    required Sale sale,
    required List<Product> changedProducts,
    CreditEntry? charge,
    required int nextFolio,
  });
  Future<void> upsertCustomer(Customer customer);
  Future<void> insertCredit(CreditEntry entry);
  Future<void> upsertSession(CashSession session);
  Future<void> insertMovement(CashMovement movement);
  Future<void> setPlan(Plan plan);
}

/// Sin almacenamiento: para la vista previa en navegador y algunas pruebas.
class MemoryRepository implements StoreRepository {
  @override
  Future<LoadedData?> load() async => null;
  @override
  Future<void> replaceAll(StoreState state, Plan plan) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> upsertProduct(Product product) async {}
  @override
  Future<void> recordSale({
    required Sale sale,
    required List<Product> changedProducts,
    CreditEntry? charge,
    required int nextFolio,
  }) async {}
  @override
  Future<void> upsertCustomer(Customer customer) async {}
  @override
  Future<void> insertCredit(CreditEntry entry) async {}
  @override
  Future<void> upsertSession(CashSession session) async {}
  @override
  Future<void> insertMovement(CashMovement movement) async {}
  @override
  Future<void> setPlan(Plan plan) async {}
}

const _kBusiness = 'business_name';
const _kFolio = 'next_folio';
const _kPlan = 'plan';

class DriftRepository implements StoreRepository {
  DriftRepository(this.db);

  final GavilanDb db;

  // ---------- Lectura ----------

  @override
  Future<LoadedData?> load() async {
    final meta = {for (final m in await db.select(db.metaTable).get()) m.key: m.value};
    final name = meta[_kBusiness];
    if (name == null || name.isEmpty) return null;

    final lines = await (db.select(db.saleLinesTable)..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    final bySale = <String, List<SaleLine>>{};
    for (final l in lines) {
      bySale
          .putIfAbsent(l.saleId, () => [])
          .add(
            SaleLine(
              key: l.lineKey,
              productId: l.productId,
              name: l.name,
              unitCents: l.unitCents,
              unitCostCents: l.unitCostCents,
              qty: l.qty,
            ),
          );
    }

    final store = StoreState(
      businessName: name,
      nextFolio: int.tryParse(meta[_kFolio] ?? '') ?? 1,
      products: [for (final p in await db.select(db.productsTable).get()) _product(p)],
      customers: [
        for (final c in await db.select(db.customersTable).get()) Customer(id: c.id, name: c.name, phone: c.phone),
      ],
      sales: [
        for (final s in await (db.select(db.salesTable)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get())
          Sale(
            id: s.id,
            folio: s.folio,
            createdAt: s.createdAt,
            lines: List.unmodifiable(bySale[s.id] ?? const []),
            kind: s.kind,
            sessionId: s.sessionId,
            method: s.method,
            receivedCents: s.receivedCents,
            customerId: s.customerId,
          ),
      ],
      credit: [
        for (final e in await (db.select(db.creditEntriesTable)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get())
          CreditEntry(
            id: e.id,
            customerId: e.customerId,
            type: e.type,
            amountCents: e.amountCents,
            createdAt: e.createdAt,
            saleId: e.saleId,
            method: e.method,
            sessionId: e.sessionId,
          ),
      ],
      sessions: [
        for (final s in await (db.select(db.cashSessionsTable)..orderBy([(t) => OrderingTerm.asc(t.openedAt)])).get())
          CashSession(
            id: s.id,
            openedAt: s.openedAt,
            openingCents: s.openingCents,
            closedAt: s.closedAt,
            expectedCents: s.expectedCents,
            countedCents: s.countedCents,
          ),
      ],
      movements: [
        for (final m in await (db.select(db.cashMovementsTable)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get())
          CashMovement(
            id: m.id,
            sessionId: m.sessionId,
            kind: m.kind,
            amountCents: m.amountCents,
            concept: m.concept,
            createdAt: m.createdAt,
          ),
      ],
    );
    final plan = Plan.values.asNameMap()[meta[_kPlan]] ?? Plan.semilla;
    return LoadedData(store: store, plan: plan);
  }

  static Product _product(ProductRow p) => Product(
    id: p.id,
    name: p.name,
    priceCents: p.priceCents,
    costCents: p.costCents,
    barcode: p.barcode,
    iconId: p.iconId,
    trackStock: p.trackStock,
    stock: p.stock,
    minStock: p.minStock,
    active: p.active,
  );

  // ---------- Conversión a renglones ----------

  static ProductRow _productRow(Product p) => ProductRow(
    id: p.id,
    name: p.name,
    priceCents: p.priceCents,
    costCents: p.costCents,
    barcode: p.barcode,
    iconId: p.iconId,
    trackStock: p.trackStock,
    stock: p.stock,
    minStock: p.minStock,
    active: p.active,
  );

  static CreditRow _creditRow(CreditEntry e) => CreditRow(
    id: e.id,
    customerId: e.customerId,
    type: e.type,
    amountCents: e.amountCents,
    createdAt: e.createdAt,
    saleId: e.saleId,
    method: e.method,
    sessionId: e.sessionId,
  );

  static SessionRow _sessionRow(CashSession s) => SessionRow(
    id: s.id,
    openedAt: s.openedAt,
    openingCents: s.openingCents,
    closedAt: s.closedAt,
    expectedCents: s.expectedCents,
    countedCents: s.countedCents,
  );

  static MovementRow _movementRow(CashMovement m) => MovementRow(
    id: m.id,
    sessionId: m.sessionId,
    kind: m.kind,
    amountCents: m.amountCents,
    concept: m.concept,
    createdAt: m.createdAt,
  );

  Future<void> _insertSale(Sale s) async {
    await db
        .into(db.salesTable)
        .insertOnConflictUpdate(
          SaleRow(
            id: s.id,
            folio: s.folio,
            createdAt: s.createdAt,
            kind: s.kind,
            sessionId: s.sessionId,
            method: s.method,
            receivedCents: s.receivedCents,
            customerId: s.customerId,
          ),
        );
    for (var i = 0; i < s.lines.length; i++) {
      final l = s.lines[i];
      await db
          .into(db.saleLinesTable)
          .insertOnConflictUpdate(
            SaleLineRow(
              saleId: s.id,
              position: i,
              lineKey: l.key,
              productId: l.productId,
              name: l.name,
              unitCents: l.unitCents,
              unitCostCents: l.unitCostCents,
              qty: l.qty,
            ),
          );
    }
  }

  Future<void> _setMeta(String key, String value) =>
      db.into(db.metaTable).insertOnConflictUpdate(MetaRow(key: key, value: value));

  // ---------- Escritura ----------

  @override
  Future<void> replaceAll(StoreState state, Plan plan) => db.transaction(() async {
    await _deleteEverything();
    await db.batch((b) {
      b.insertAll(db.productsTable, state.products.map(_productRow));
      b.insertAll(db.customersTable, state.customers.map((c) => CustomerRow(id: c.id, name: c.name, phone: c.phone)));
      b.insertAll(db.creditEntriesTable, state.credit.map(_creditRow));
      b.insertAll(db.cashSessionsTable, state.sessions.map(_sessionRow));
      b.insertAll(db.cashMovementsTable, state.movements.map(_movementRow));
    });
    for (final s in state.sales) {
      await _insertSale(s);
    }
    await _setMeta(_kBusiness, state.businessName);
    await _setMeta(_kFolio, '${state.nextFolio}');
    await _setMeta(_kPlan, plan.name);
  });

  Future<void> _deleteEverything() async {
    for (final table in db.allTables) {
      await db.delete(table).go();
    }
  }

  @override
  Future<void> clear() => db.transaction(_deleteEverything);

  @override
  Future<void> upsertProduct(Product product) => db.into(db.productsTable).insertOnConflictUpdate(_productRow(product));

  @override
  Future<void> recordSale({
    required Sale sale,
    required List<Product> changedProducts,
    CreditEntry? charge,
    required int nextFolio,
  }) => db.transaction(() async {
    await _insertSale(sale);
    for (final p in changedProducts) {
      await upsertProduct(p);
    }
    if (charge != null) await insertCredit(charge);
    await _setMeta(_kFolio, '$nextFolio');
  });

  @override
  Future<void> upsertCustomer(Customer customer) => db
      .into(db.customersTable)
      .insertOnConflictUpdate(CustomerRow(id: customer.id, name: customer.name, phone: customer.phone));

  @override
  Future<void> insertCredit(CreditEntry entry) =>
      db.into(db.creditEntriesTable).insertOnConflictUpdate(_creditRow(entry));

  @override
  Future<void> upsertSession(CashSession session) =>
      db.into(db.cashSessionsTable).insertOnConflictUpdate(_sessionRow(session));

  @override
  Future<void> insertMovement(CashMovement movement) =>
      db.into(db.cashMovementsTable).insertOnConflictUpdate(_movementRow(movement));

  @override
  Future<void> setPlan(Plan plan) => _setMeta(_kPlan, plan.name);
}
