import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/models.dart';
import '../domain/plan.dart';
import '../state/store.dart';
import 'database.dart';
import 'remote_mapping.dart';

/// Lo que se recupera al abrir la app.
class LoadedData {
  const LoadedData({required this.store, required this.plan});

  final StoreState store;
  final Plan plan;
}

/// Dónde se guardan los datos. Las pantallas solo hablan con esta interfaz.
abstract class StoreRepository {
  /// null si todavía no hay negocio (primer arranque).
  Future<LoadedData?> load();

  /// Reemplaza todo (alta del negocio o datos de ejemplo). Quita el enlace con la nube.
  Future<void> replaceAll(StoreState state, Plan plan);
  Future<void> clear();

  Future<void> upsertProduct(Product product, {required bool isNew});
  Future<void> addStock(Product updated, double delta);
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

  /// Operaciones de sincronización; null si este almacenamiento no sincroniza.
  SyncStore? get sync;
}

/// Lo que necesita el motor de sincronización del almacenamiento local.
abstract class SyncStore {
  /// Negocio de Supabase al que está enlazado este teléfono (null = solo local).
  String? get linkedBusinessId;

  /// Enlaza con la nube. Con [uploadAll] anota todo lo que hay para subirlo.
  Future<void> link(String businessId, {StoreState? uploadAll});

  /// Borra lo local y prepara el teléfono para bajar un negocio de la nube.
  Future<void> prepareDownload(String businessId, String businessName);

  Future<List<OutboxRow>> pending({int limit = 50});
  Future<int> pendingCount();
  Future<void> markSent(int outboxId);
  Future<void> markFailed(int outboxId, String error);

  Future<DateTime?> cursor(String table);
  Future<void> setCursor(String table, DateTime at);

  /// Aplica filas que bajaron de Supabase. No las vuelve a anotar para subir.
  Future<void> applyRemote(String table, List<RemoteRow> rows);
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
  Future<void> upsertProduct(Product product, {required bool isNew}) async {}
  @override
  Future<void> addStock(Product updated, double delta) async {}
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
  @override
  SyncStore? get sync => null;
}

const _kBusiness = 'business_name';
const _kBusinessId = 'business_id';
const _kDemo = 'is_demo';
const _kFolio = 'next_folio';
const _kPlan = 'plan';
const _kLinked = 'linked_business';
String _kCursor(String table) => 'cursor:$table';

/// Tablas de Supabase en el orden en que se bajan (primero lo que otras filas referencian).
const pullTables = [
  'businesses',
  'customers',
  'products',
  'cash_sessions',
  'sales',
  'sale_items',
  'credit_entries',
  'cash_movements',
];

class DriftRepository implements StoreRepository, SyncStore {
  DriftRepository(this.db);

  final GavilanDb db;
  String? _linked;

  @override
  SyncStore get sync => this;

  @override
  String? get linkedBusinessId => _linked;

  // ---------- Lectura ----------

  Future<Map<String, String>> _meta() async => {for (final m in await db.select(db.metaTable).get()) m.key: m.value};

  @override
  Future<LoadedData?> load() async {
    final meta = await _meta();
    _linked = meta[_kLinked];
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
      businessId: meta[_kBusinessId] ?? '',
      isDemo: meta[_kDemo] == '1',
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
          _session(s),
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

  static CashSession _session(SessionRow s) => CashSession(
    id: s.id,
    openedAt: s.openedAt,
    openingCents: s.openingCents,
    closedAt: s.closedAt,
    expectedCents: s.expectedCents,
    countedCents: s.countedCents,
  );

  // ---------- Conversión a renglones locales ----------

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

  /// Anota cambios para subir, solo si el teléfono está enlazado a la nube.
  Future<void> _enqueue(List<RemoteChange> changes) async {
    if (_linked == null || changes.isEmpty) return;
    await db
        .into(db.outboxTable)
        .insert(
          OutboxTableCompanion.insert(
            payload: jsonEncode([
              for (final c in changes) {'table': c.table, 'rows': c.rows},
            ]),
            createdAt: DateTime.now(),
          ),
        );
  }

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
    await _setMeta(_kBusinessId, state.businessId);
    await _setMeta(_kBusiness, state.businessName);
    await _setMeta(_kDemo, state.isDemo ? '1' : '0');
    await _setMeta(_kFolio, '${state.nextFolio}');
    await _setMeta(_kPlan, plan.name);
  });

  Future<void> _deleteEverything() async {
    for (final table in db.allTables) {
      await db.delete(table).go();
    }
    _linked = null;
  }

  @override
  Future<void> clear() => db.transaction(_deleteEverything);

  @override
  Future<void> upsertProduct(Product product, {required bool isNew}) => db.transaction(() async {
    await db.into(db.productsTable).insertOnConflictUpdate(_productRow(product));
    await _enqueue([
      (table: 'products', rows: [productToRemote(product, withStock: isNew)]),
    ]);
  });

  @override
  Future<void> addStock(Product updated, double delta) => db.transaction(() async {
    await db.into(db.productsTable).insertOnConflictUpdate(_productRow(updated));
    final now = DateTime.now();
    await _enqueue([
      (
        table: 'inventory_movements',
        rows: [
          stockToRemote(
            id: stableId('${updated.id}/purchase/${now.microsecondsSinceEpoch}'),
            productId: updated.id,
            change: delta,
            reason: 'purchase',
            at: now,
          ),
        ],
      ),
    ]);
  });

  @override
  Future<void> recordSale({
    required Sale sale,
    required List<Product> changedProducts,
    CreditEntry? charge,
    required int nextFolio,
  }) => db.transaction(() async {
    await _insertSale(sale);
    for (final p in changedProducts) {
      await db.into(db.productsTable).insertOnConflictUpdate(_productRow(p));
    }
    if (charge != null) await db.into(db.creditEntriesTable).insertOnConflictUpdate(_creditRow(charge));
    await _setMeta(_kFolio, '$nextFolio');
    await _enqueue([
      ...saleToRemote(sale, stockTracked: {for (final p in changedProducts) p.id}),
      if (charge != null) (table: 'credit_entries', rows: [creditToRemote(charge)]),
    ]);
  });

  @override
  Future<void> upsertCustomer(Customer customer) => db.transaction(() async {
    await db
        .into(db.customersTable)
        .insertOnConflictUpdate(CustomerRow(id: customer.id, name: customer.name, phone: customer.phone));
    await _enqueue([
      (table: 'customers', rows: [customerToRemote(customer)]),
    ]);
  });

  @override
  Future<void> insertCredit(CreditEntry entry) => db.transaction(() async {
    await db.into(db.creditEntriesTable).insertOnConflictUpdate(_creditRow(entry));
    await _enqueue([
      (table: 'credit_entries', rows: [creditToRemote(entry)]),
    ]);
  });

  @override
  Future<void> upsertSession(CashSession session) => db.transaction(() async {
    await db.into(db.cashSessionsTable).insertOnConflictUpdate(_sessionRow(session));
    await _enqueue([
      (table: 'cash_sessions', rows: [sessionToRemote(session)]),
    ]);
  });

  @override
  Future<void> insertMovement(CashMovement movement) => db.transaction(() async {
    await db.into(db.cashMovementsTable).insertOnConflictUpdate(_movementRow(movement));
    await _enqueue([
      (table: 'cash_movements', rows: [movementToRemote(movement)]),
    ]);
  });

  @override
  Future<void> setPlan(Plan plan) => _setMeta(_kPlan, plan.name);

  // ---------- Sincronización ----------

  @override
  Future<void> link(String businessId, {StoreState? uploadAll}) => db.transaction(() async {
    await _setMeta(_kLinked, businessId);
    await _setMeta(_kBusinessId, businessId);
    _linked = businessId;
    final s = uploadAll;
    if (s == null) return;
    // Todo lo que ya existía en el teléfono, en orden de dependencias. Los productos
    // suben con su existencia actual, por eso las ventas viejas no vuelven a descontar.
    if (s.customers.isNotEmpty) {
      await _enqueue([(table: 'customers', rows: s.customers.map(customerToRemote).toList())]);
    }
    if (s.products.isNotEmpty) {
      await _enqueue([
        (table: 'products', rows: [for (final p in s.products) productToRemote(p, withStock: true)]),
      ]);
    }
    if (s.sessions.isNotEmpty) {
      await _enqueue([(table: 'cash_sessions', rows: s.sessions.map(sessionToRemote).toList())]);
    }
    for (final sale in s.sales) {
      await _enqueue(saleToRemote(sale));
    }
    if (s.credit.isNotEmpty) {
      await _enqueue([(table: 'credit_entries', rows: s.credit.map(creditToRemote).toList())]);
    }
    if (s.movements.isNotEmpty) {
      await _enqueue([(table: 'cash_movements', rows: s.movements.map(movementToRemote).toList())]);
    }
  });

  @override
  Future<void> prepareDownload(String businessId, String businessName) => db.transaction(() async {
    await _deleteEverything();
    await _setMeta(_kBusinessId, businessId);
    await _setMeta(_kBusiness, businessName);
    await _setMeta(_kDemo, '0');
    await _setMeta(_kFolio, '1');
    await _setMeta(_kLinked, businessId);
    _linked = businessId;
  });

  @override
  Future<List<OutboxRow>> pending({int limit = 50}) =>
      (db.select(db.outboxTable)
            ..orderBy([(t) => OrderingTerm.asc(t.id)])
            ..limit(limit))
          .get();

  @override
  Future<int> pendingCount() async {
    final count = db.outboxTable.id.count();
    final row = await (db.selectOnly(db.outboxTable)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<void> markSent(int outboxId) => (db.delete(db.outboxTable)..where((t) => t.id.equals(outboxId))).go();

  @override
  Future<void> markFailed(int outboxId, String error) => db.customUpdate(
    'UPDATE outbox SET attempts = attempts + 1, last_error = ? WHERE id = ?',
    variables: [Variable.withString(error), Variable.withInt(outboxId)],
    updates: {db.outboxTable},
  );

  @override
  Future<DateTime?> cursor(String table) async {
    final value = (await _meta())[_kCursor(table)];
    return value == null ? null : DateTime.parse(value);
  }

  @override
  Future<void> setCursor(String table, DateTime at) => _setMeta(_kCursor(table), at.toUtc().toIso8601String());

  @override
  Future<void> applyRemote(String table, List<RemoteRow> rows) => db.transaction(() async {
    for (final r in rows) {
      switch (table) {
        case 'businesses':
          await _setMeta(_kBusiness, r['name']! as String);
        case 'customers':
          await db.into(db.customersTable).insertOnConflictUpdate(customerFromRemote(r));
        case 'products':
          await db.into(db.productsTable).insertOnConflictUpdate(productFromRemote(r));
        case 'cash_sessions':
          await db.into(db.cashSessionsTable).insertOnConflictUpdate(sessionFromRemote(r));
        case 'sales':
          final sale = saleFromRemote(r);
          await db.into(db.salesTable).insertOnConflictUpdate(sale);
          // El siguiente folio nunca queda por debajo de lo que ya hay en la nube.
          final folio = int.tryParse((await _meta())[_kFolio] ?? '') ?? 1;
          if (sale.folio >= folio) await _setMeta(_kFolio, '${sale.folio + 1}');
        case 'sale_items':
          await db.into(db.saleLinesTable).insertOnConflictUpdate(saleLineFromRemote(r));
        case 'credit_entries':
          await db.into(db.creditEntriesTable).insertOnConflictUpdate(creditFromRemote(r));
        case 'cash_movements':
          await db.into(db.cashMovementsTable).insertOnConflictUpdate(movementFromRemote(r));
      }
    }
  });
}
