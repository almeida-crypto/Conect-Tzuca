import '../domain/business.dart';
import '../core/limits.dart';

import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/models.dart';
import '../domain/plan.dart';
import '../domain/restaurant.dart';
import '../domain/team.dart';
import '../state/store.dart';
import 'database.dart';
import 'remote_mapping.dart';
import '../domain/clerk.dart';

part 'repository_contracts.dart';
part 'repository_rows.dart';

const _kBusiness = 'business_name';
const _kType = 'business_type';
const _kClerks = 'clerks';
const _kClerkLock = 'clerk_lock';
const _kModules = 'modules';
const _kCreditLimit = 'credit_limit';
const _kPayMethods = 'pay_methods';
const _kRegisterName = 'register_name';
const _kKitchenPrint = 'kitchen_print';
const _kTicketPrint = 'ticket_print';
const _kLogo = 'logo_path';
const _kBusinessId = 'business_id';
const _kDemo = 'is_demo';
const _kFolio = 'next_folio';
const _kPlan = 'plan';
const _kLinked = 'linked_business';
const _kDevice = 'device_code';
const _kRole = 'member_role';
const _kLinkedUser = 'linked_user';
String _kCursor(String table) => 'cursor:$table';

/// Veces que un cambio rechazado se vuelve a intentar solo antes de quedar apartado para el usuario.
const maxAutoRetries = 3;

/// Tablas de Supabase que toca un cambio de la fila.
Set<String> outboxTables(String payload) => {
  for (final c in (jsonDecode(payload) as List).cast<Map<String, dynamic>>()) c['table'] as String,
};

/// Tablas de Supabase en el orden en que se bajan (primero lo que otras filas referencian).
const pullTables = [
  'businesses',
  'customers',
  'products',
  'cash_sessions',
  'sales',
  'sale_items',
  'sale_payments',
  'sale_returns',
  'credit_entries',
  'cash_movements',
  'lots',
  'lot_sales',
  'layaways',
  'layaway_payments',
  'batches',
  'batch_orders',
  'restaurant_tables',
  'floor_items',
  'extras',
  'orders',
  'order_items',
];

/// Lo que cambia en el restaurante: se baja al instante cuando avisa Realtime.
const restaurantTables = {'restaurant_tables', 'orders', 'order_items'};

class DriftRepository implements StoreRepository, SyncStore {
  DriftRepository(this.db, {String? deviceCode}) : _device = deviceCode;

  final GavilanDb db;
  String? _linked;
  String? _device;
  MemberRole? _role;
  String? _linkedUser;

  @override
  MemberRole? get role => _role;

  @override
  String? get linkedUser => _linkedUser;

  @override
  Future<void> setLinkedUser(String? userId) async {
    if (userId == _linkedUser) return;
    _linkedUser = userId;
    if (userId == null) {
      await (db.delete(db.metaTable)..where((t) => t.key.equals(_kLinkedUser))).go();
    } else {
      await _setMeta(_kLinkedUser, userId);
    }
  }

  @override
  Future<void> setRole(MemberRole? role) async {
    _role = role;
    if (role == null) {
      await (db.delete(db.metaTable)..where((t) => t.key.equals(_kRole))).go();
    } else {
      await _setMeta(_kRole, role.name);
    }
  }

  @override
  String get deviceCode => _device ??= newDeviceCode();

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
    _role = MemberRole.fromRemote(meta[_kRole]);
    _linkedUser = meta[_kLinkedUser];
    _device = meta[_kDevice] ?? _device;
    if (_device == null) await _setMeta(_kDevice, deviceCode);
    final name = meta[_kBusiness];
    if (name == null || name.isEmpty) return null;

    final lines = await (db.select(db.saleLinesTable)..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    final payRows = await (db.select(
      db.salePaymentsTable,
    )..orderBy([(t) => OrderingTerm.asc(t.position), (t) => OrderingTerm.asc(t.id)])).get();
    final paysBySale = <String, List<SalePayment>>{};
    for (final p in payRows) {
      paysBySale.putIfAbsent(p.saleId, () => []).add(SalePayment(method: p.method, amountCents: p.amountCents));
    }
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
      businessType: BusinessType.fromName(meta[_kType]),
      clerks: clerksFromJson(meta[_kClerks]),
      lockMinutes: int.tryParse(meta[_kClerkLock] ?? ''),
      modules: modulesFromText(meta[_kModules]),
      defaultCreditLimitCents: int.tryParse(meta[_kCreditLimit] ?? ''),
      payMethods: payMethodsFromText(meta[_kPayMethods]),
      registerName: (meta[_kRegisterName] ?? '').isEmpty ? null : meta[_kRegisterName],
      kitchenPrint: meta[_kKitchenPrint] == '1',
      ticketPrint: meta[_kTicketPrint] == '1',
      logoPath: (meta[_kLogo] ?? '').isEmpty ? null : meta[_kLogo],
      nextFolio: int.tryParse(meta[_kFolio] ?? '') ?? 1,
      products: [for (final p in await db.select(db.productsTable).get()) _product(p)],
      photos: {for (final f in await db.select(db.productPhotosTable).get()) f.path: f.bytes},
      customers: [
        for (final c in await db.select(db.customersTable).get())
          Customer(id: c.id, name: c.name, phone: c.phone, creditLimitCents: c.creditLimitCents),
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
            device: s.device,
            orderId: s.orderId,
            cancelledAt: s.cancelledAt,
            cancelReason: s.cancelReason,
            cancelledInSession: s.cancelledInSession,
            discountCents: s.discountCents,
            clerk: s.clerkName,
            payments: List.unmodifiable(paysBySale[s.id] ?? const <SalePayment>[]),
            tipCents: s.tipCents,
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
            clerk: e.clerkName,
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
            clerk: m.clerkName,
          ),
      ],
    );
    final withModules = store.copyWith(
      lots: [for (final r in await db.select(db.lotsTable).get()) _lot(r)],
      lotSales: [for (final r in await db.select(db.lotSalesTable).get()) _lotSale(r)],
      saleReturns: [
        for (final r in await (db.select(db.saleReturnsTable)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get())
          _saleReturn(r),
      ],
      layaways: [for (final r in await db.select(db.layawaysTable).get()) _layaway(r)],
      layawayPayments: [for (final r in await db.select(db.layawayPaymentsTable).get()) _layawayPayment(r)],
      batches: [for (final r in await db.select(db.batchesTable).get()) _batch(r)],
      batchOrders: [for (final r in await db.select(db.batchOrdersTable).get()) _batchOrder(r)],
      tables: [for (final r in await db.select(db.diningTablesTable).get()) _table(r)],
      floorItems: [for (final r in await db.select(db.floorItemsTable).get()) _floorItem(r)],
      extras: [
        for (final r in await (db.select(db.extrasTable)..orderBy([(t) => OrderingTerm.asc(t.position)])).get())
          Extra(id: r.id, name: r.name, priceCents: r.priceCents, active: r.active, position: r.position),
      ],
      orders: [for (final r in await db.select(db.ordersTable).get()) _order(r)],
      orderItems: [
        for (final r in await (db.select(db.orderItemsTable)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get())
          _orderItem(r),
      ],
    );
    final plan = Plan.values.asNameMap()[meta[_kPlan]] ?? Plan.semilla;
    return LoadedData(store: withModules, plan: plan);
  }

  // ---------- Conversión a renglones locales ----------

  Future<void> _insertSale(Sale s) async {
    await db
        .into(db.salesTable)
        .put(
          SaleRow(
            id: s.id,
            folio: s.folio,
            createdAt: s.createdAt,
            kind: s.kind,
            sessionId: s.sessionId,
            method: s.method,
            receivedCents: s.receivedCents,
            customerId: s.customerId,
            device: s.device,
            orderId: s.orderId,
            cancelledAt: s.cancelledAt,
            cancelReason: s.cancelReason,
            cancelledInSession: s.cancelledInSession,
            discountCents: s.discountCents,
            clerkName: s.clerk,
            tipCents: s.tipCents,
          ),
        );
    for (final (i, p) in s.payments.indexed) {
      await db
          .into(db.salePaymentsTable)
          .put(
            SalePaymentRow(
              id: salePaymentId(s.id, i),
              saleId: s.id,
              method: p.method,
              amountCents: p.amountCents,
              position: i,
            ),
          );
    }
    for (var i = 0; i < s.lines.length; i++) {
      final l = s.lines[i];
      await db
          .into(db.saleLinesTable)
          .put(
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

  Future<void> _setMeta(String key, String value) => db.into(db.metaTable).put(MetaRow(key: key, value: value));

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
      b.insertAll(
        db.customersTable,
        state.customers.map(
          (c) => CustomerRow(id: c.id, name: c.name, phone: c.phone, creditLimitCents: c.creditLimitCents),
        ),
      );
      b.insertAll(db.creditEntriesTable, state.credit.map(_creditRow));
      b.insertAll(db.cashSessionsTable, state.sessions.map(_sessionRow));
      b.insertAll(db.cashMovementsTable, state.movements.map(_movementRow));
      b.insertAll(db.lotsTable, state.lots.map(_lotRow));
      b.insertAll(db.lotSalesTable, state.lotSales.map(_lotSaleRow));
      b.insertAll(db.layawaysTable, state.layaways.map(_layawayRow));
      b.insertAll(db.layawayPaymentsTable, state.layawayPayments.map(_layawayPaymentRow));
      b.insertAll(db.batchesTable, state.batches.map(_batchRow));
      b.insertAll(db.batchOrdersTable, state.batchOrders.map(_batchOrderRow));
      b.insertAll(db.diningTablesTable, state.tables.map(_tableRow));
      b.insertAll(db.extrasTable, state.extras.map(_extraRow));
      b.insertAll(db.ordersTable, state.orders.map(_orderRow));
      b.insertAll(db.orderItemsTable, state.orderItems.map(_orderItemRow));
    });
    for (final s in state.sales) {
      await _insertSale(s);
    }
    await _setMeta(_kBusinessId, state.businessId);
    await _setMeta(_kBusiness, state.businessName);
    if (state.businessType != null) await _setMeta(_kType, state.businessType!.name);
    if (state.modules != null) await _setMeta(_kModules, modulesToText(state.modules!));
    if (state.defaultCreditLimitCents != null) await _setMeta(_kCreditLimit, '${state.defaultCreditLimitCents}');
    if (state.payMethods != null) await _setMeta(_kPayMethods, payMethodsToText(state.payMethods!));
    if (state.clerks.isNotEmpty) await setClerks(state.clerks, state.lockMinutes);
    await _setMeta(_kDemo, state.isDemo ? '1' : '0');
    await _setMeta(_kFolio, '${state.nextFolio}');
    await _setMeta(_kPlan, plan.name);
  });

  Future<void> _deleteEverything() async {
    for (final table in db.allTables) {
      await db.delete(table).go();
    }
    _linked = null;
    _role = null;
    _linkedUser = null;
    // La clave del teléfono se queda: es del aparato, no del negocio.
    await _setMeta(_kDevice, deviceCode);
  }

  @override
  Future<void> clear() => db.transaction(_deleteEverything);

  @override
  Future<void> upsertProduct(Product product, {required bool isNew}) => db.transaction(() async {
    await db.into(db.productsTable).put(_productRow(product));
    await _enqueue([
      (table: 'products', rows: [productToRemote(product, withStock: isNew)]),
    ]);
  });

  @override
  Future<void> addStock(Product updated, double delta, {bool adjustment = false}) => db.transaction(() async {
    await db.into(db.productsTable).put(_productRow(updated));
    final now = DateTime.now();
    await _enqueue([
      (
        table: 'inventory_movements',
        rows: [
          stockToRemote(
            id: stableId('${updated.id}/${adjustment ? 'adjustment' : 'purchase'}/${now.microsecondsSinceEpoch}'),
            productId: updated.id,
            change: delta,
            reason: adjustment ? 'adjustment' : 'purchase',
            at: now,
          ),
        ],
      ),
    ]);
  });

  @override
  Future<void> cancelSale({required Sale sale, required List<Product> restocked, CreditEntry? reversal}) =>
      db.transaction(() async {
        await _insertSale(sale);
        for (final p in restocked) {
          await db.into(db.productsTable).put(_productRow(p));
        }
        if (reversal != null) await db.into(db.creditEntriesTable).put(_creditRow(reversal));
        final at = sale.cancelledAt ?? DateTime.now();
        final back = <String, double>{};
        for (final l in sale.lines) {
          if (l.productId != null && restocked.any((p) => p.id == l.productId)) {
            back[l.productId!] = (back[l.productId!] ?? 0) + l.qty;
          }
        }
        await _enqueue([
          // Solo el renglón de la venta (con estado "cancelled"); sus renglones no cambian.
          saleToRemote(sale).first,
          if (back.isNotEmpty)
            (
              table: 'inventory_movements',
              rows: [
                for (final e in back.entries)
                  stockToRemote(
                    id: stableId('${sale.id}/return/${e.key}'),
                    productId: e.key,
                    change: e.value,
                    reason: 'return',
                    refId: sale.id,
                    at: at,
                  ),
              ],
            ),
          if (reversal != null) (table: 'credit_entries', rows: [creditToRemote(reversal)]),
        ]);
      });

  @override
  Future<void> recordReturn({required SaleReturn ret, required List<Product> restocked, CreditEntry? reversal}) =>
      db.transaction(() async {
        await db.into(db.saleReturnsTable).put(_saleReturnRow(ret));
        for (final p in restocked) {
          await db.into(db.productsTable).put(_productRow(p));
        }
        if (reversal != null) await db.into(db.creditEntriesTable).put(_creditRow(reversal));
        final back = <String, double>{};
        for (final l in ret.lines) {
          if (l.productId != null && restocked.any((p) => p.id == l.productId)) {
            back[l.productId!] = (back[l.productId!] ?? 0) + l.qty;
          }
        }
        await _enqueue([
          (table: 'sale_returns', rows: [saleReturnToRemote(ret)]),
          if (back.isNotEmpty)
            (
              table: 'inventory_movements',
              rows: [
                for (final e in back.entries)
                  stockToRemote(
                    id: stableId('${ret.id}/stock/${e.key}'),
                    productId: e.key,
                    change: e.value,
                    reason: 'return',
                    refId: ret.saleId,
                    at: ret.createdAt,
                  ),
              ],
            ),
          if (reversal != null) (table: 'credit_entries', rows: [creditToRemote(reversal)]),
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
      await db.into(db.productsTable).put(_productRow(p));
    }
    if (charge != null) await db.into(db.creditEntriesTable).put(_creditRow(charge));
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
        .put(
          CustomerRow(
            id: customer.id,
            name: customer.name,
            phone: customer.phone,
            creditLimitCents: customer.creditLimitCents,
          ),
        );
    await _enqueue([
      (table: 'customers', rows: [customerToRemote(customer)]),
    ]);
  });

  @override
  Future<void> setRegisterName(String? name) => _setMeta(_kRegisterName, name ?? '');

  // ---------- Fotos de producto ----------

  @override
  Future<void> savePhoto(String productId, String path, Uint8List bytes, {bool uploaded = false}) =>
      db.transaction(() async {
        // Las fotos anteriores del mismo producto ya no se usan.
        await (db.delete(
          db.productPhotosTable,
        )..where((t) => t.productId.equals(productId) & t.path.equals(path).not())).go();
        await db
            .into(db.productPhotosTable)
            .put(PhotoRow(path: path, productId: productId, bytes: bytes, uploaded: uploaded));
      });

  @override
  Future<void> setLogo(String? path, Uint8List? bytes) => db.transaction(() async {
    if (path != null && bytes != null) {
      await savePhoto(logoPhotoId, path, bytes);
    } else {
      await (db.delete(db.productPhotosTable)..where((t) => t.productId.equals(logoPhotoId))).go();
    }
    await _setMeta(_kLogo, path ?? '');
    await _enqueue([
      (table: 'businesses', rows: [logoToRemote(path)]),
    ]);
  });

  @override
  Future<List<PhotoRow>> pendingPhotos() =>
      (db.select(db.productPhotosTable)..where((t) => t.uploaded.equals(false))).get();

  @override
  Future<void> markPhotoUploaded(String path) => (db.update(
    db.productPhotosTable,
  )..where((t) => t.path.equals(path))).write(const ProductPhotosTableCompanion(uploaded: Value(true)));

  @override
  Future<Set<String>> photoPaths() async => {
    for (final r in await (db.selectOnly(db.productPhotosTable)..addColumns([db.productPhotosTable.path])).get())
      r.read(db.productPhotosTable.path)!,
  };

  @override
  Future<void> setKitchenPrint(bool on) => _setMeta(_kKitchenPrint, on ? '1' : '0');

  @override
  Future<void> setTicketPrint(bool on) => _setMeta(_kTicketPrint, on ? '1' : '0');

  @override
  Future<void> setPayMethods(Set<PayMethod> methods) => db.transaction(() async {
    await _setMeta(_kPayMethods, payMethodsToText(methods));
    await _enqueue([
      (table: 'businesses', rows: [payMethodsToRemote(methods)]),
    ]);
  });

  @override
  Future<void> setDefaultCreditLimit(int? cents) => db.transaction(() async {
    await _setMeta(_kCreditLimit, cents?.toString() ?? '');
    await _enqueue([
      (table: 'businesses', rows: [creditLimitToRemote(cents)]),
    ]);
  });

  @override
  Future<void> insertCredit(CreditEntry entry) => db.transaction(() async {
    await db.into(db.creditEntriesTable).put(_creditRow(entry));
    await _enqueue([
      (table: 'credit_entries', rows: [creditToRemote(entry)]),
    ]);
  });

  @override
  Future<void> upsertSession(CashSession session) => db.transaction(() async {
    await db.into(db.cashSessionsTable).put(_sessionRow(session));
    await _enqueue([
      (table: 'cash_sessions', rows: [sessionToRemote(session)]),
    ]);
  });

  @override
  Future<void> insertMovement(CashMovement movement) => db.transaction(() async {
    await db.into(db.cashMovementsTable).put(_movementRow(movement));
    await _enqueue([
      (table: 'cash_movements', rows: [movementToRemote(movement)]),
    ]);
  });

  @override
  Future<void> setClerks(List<Clerk> clerks, int? lockMinutes) async {
    await _setMeta(_kClerks, clerksToJson(clerks));
    await _setMeta(_kClerkLock, lockMinutes?.toString() ?? '');
  }

  @override
  Future<void> setBusinessSetup(BusinessType type, Set<Module> modules) => db.transaction(() async {
    await _setMeta(_kType, type.name);
    await _setMeta(_kModules, modulesToText(modules));
    await _enqueue([
      (table: 'businesses', rows: [businessSetupToRemote(type, modules)]),
    ]);
  });

  @override
  Future<void> setPlan(Plan plan) => _setMeta(_kPlan, plan.name);

  @override
  Future<void> upsertLot(Lot lot) => db.transaction(() async {
    await db.into(db.lotsTable).put(_lotRow(lot));
    await _enqueue([
      (table: 'lots', rows: [lotToRemote(lot)]),
    ]);
  });

  @override
  Future<void> insertLotSale(LotSale sale) => db.transaction(() async {
    await db.into(db.lotSalesTable).put(_lotSaleRow(sale));
    await _enqueue([
      (table: 'lot_sales', rows: [lotSaleToRemote(sale)]),
    ]);
  });

  @override
  Future<void> upsertLayaway(Layaway layaway) => db.transaction(() async {
    await db.into(db.layawaysTable).put(_layawayRow(layaway));
    await _enqueue([
      (table: 'layaways', rows: [layawayToRemote(layaway)]),
    ]);
  });

  @override
  Future<void> insertLayawayPayment(LayawayPayment payment) => db.transaction(() async {
    await db.into(db.layawayPaymentsTable).put(_layawayPaymentRow(payment));
    await _enqueue([
      (table: 'layaway_payments', rows: [layawayPaymentToRemote(payment)]),
    ]);
  });

  @override
  Future<void> upsertBatch(Tanda batch) => db.transaction(() async {
    await db.into(db.batchesTable).put(_batchRow(batch));
    await _enqueue([
      (table: 'batches', rows: [batchToRemote(batch)]),
    ]);
  });

  @override
  Future<void> upsertBatchOrder(BatchOrder order) => db.transaction(() async {
    await db.into(db.batchOrdersTable).put(_batchOrderRow(order));
    await _enqueue([
      (table: 'batch_orders', rows: [batchOrderToRemote(order)]),
    ]);
  });

  @override
  Future<void> upsertExtra(Extra extra) => db.transaction(() async {
    await db.into(db.extrasTable).put(_extraRow(extra));
    await _enqueue([
      (table: 'extras', rows: [extraToRemote(extra)]),
    ]);
  });

  @override
  Future<void> upsertTable(DiningTable table) => db.transaction(() async {
    await db.into(db.diningTablesTable).put(_tableRow(table));
    await _enqueue([
      (table: 'restaurant_tables', rows: [tableToRemote(table)]),
    ]);
  });

  @override
  Future<void> upsertFloorItem(FloorItem item) => db.transaction(() async {
    await db.into(db.floorItemsTable).put(_floorItemRow(item));
    await _enqueue([
      (table: 'floor_items', rows: [floorItemToRemote(item)]),
    ]);
  });

  @override
  Future<void> upsertOrder(RestaurantOrder order) => db.transaction(() async {
    await db.into(db.ordersTable).put(_orderRow(order));
    await _enqueue([
      (table: 'orders', rows: [orderToRemote(order)]),
    ]);
  });

  @override
  Future<void> upsertOrderItems(List<OrderItem> items) => db.transaction(() async {
    for (final i in items) {
      await db.into(db.orderItemsTable).put(_orderItemRow(i));
    }
    await _enqueue([(table: 'order_items', rows: items.map(orderItemToRemote).toList())]);
  });

  // ---------- Sincronización ----------

  @override
  Future<void> link(String businessId, {StoreState? uploadAll}) => db.transaction(() async {
    await _setMeta(_kLinked, businessId);
    await _setMeta(_kBusinessId, businessId);
    _linked = businessId;
    final s = uploadAll;
    if (s == null) return;
    if (s.businessType != null || s.modules != null) {
      await _enqueue([
        (table: 'businesses', rows: [businessSetupToRemote(s.businessType, s.modules)]),
      ]);
    }
    if (s.logoPath != null) {
      await _enqueue([
        (table: 'businesses', rows: [logoToRemote(s.logoPath)]),
      ]);
    }
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
    if (s.saleReturns.isNotEmpty) {
      await _enqueue([(table: 'sale_returns', rows: s.saleReturns.map(saleReturnToRemote).toList())]);
    }
    if (s.credit.isNotEmpty) {
      await _enqueue([(table: 'credit_entries', rows: s.credit.map(creditToRemote).toList())]);
    }
    if (s.movements.isNotEmpty) {
      await _enqueue([(table: 'cash_movements', rows: s.movements.map(movementToRemote).toList())]);
    }
    final modules = <RemoteChange>[
      if (s.lots.isNotEmpty) (table: 'lots', rows: s.lots.map(lotToRemote).toList()),
      if (s.lotSales.isNotEmpty) (table: 'lot_sales', rows: s.lotSales.map(lotSaleToRemote).toList()),
      if (s.layaways.isNotEmpty) (table: 'layaways', rows: s.layaways.map(layawayToRemote).toList()),
      if (s.layawayPayments.isNotEmpty)
        (table: 'layaway_payments', rows: s.layawayPayments.map(layawayPaymentToRemote).toList()),
      if (s.batches.isNotEmpty) (table: 'batches', rows: s.batches.map(batchToRemote).toList()),
      if (s.batchOrders.isNotEmpty) (table: 'batch_orders', rows: s.batchOrders.map(batchOrderToRemote).toList()),
      if (s.tables.isNotEmpty) (table: 'restaurant_tables', rows: s.tables.map(tableToRemote).toList()),
      if (s.floorItems.isNotEmpty) (table: 'floor_items', rows: s.floorItems.map(floorItemToRemote).toList()),
      if (s.extras.isNotEmpty) (table: 'extras', rows: s.extras.map(extraToRemote).toList()),
      if (s.orders.isNotEmpty) (table: 'orders', rows: s.orders.map(orderToRemote).toList()),
      if (s.orderItems.isNotEmpty) (table: 'order_items', rows: s.orderItems.map(orderItemToRemote).toList()),
    ];
    for (final change in modules) {
      await _enqueue([change]);
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
  Future<List<OutboxRow>> pending({int limit = 50, int afterId = 0}) =>
      (db.select(db.outboxTable)
            ..where((t) => t.id.isBiggerThanValue(afterId) & t.attempts.isSmallerThanValue(maxAutoRetries))
            ..orderBy([(t) => OrderingTerm.asc(t.id)])
            ..limit(limit))
          .get();

  @override
  Future<int> pendingCount() async {
    final count = db.outboxTable.id.count();
    final row =
        await (db.selectOnly(db.outboxTable)
              ..addColumns([count])
              ..where(db.outboxTable.lastError.isNull()))
            .getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<List<OutboxRow>> failed() =>
      (db.select(db.outboxTable)
            ..where((t) => t.lastError.isNotNull())
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  @override
  Future<int> failedCount() async {
    final count = db.outboxTable.id.count();
    final row =
        await (db.selectOnly(db.outboxTable)
              ..addColumns([count])
              ..where(db.outboxTable.lastError.isNotNull()))
            .getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<void> retryFailed() => db.customUpdate(
    'UPDATE outbox SET attempts = 0, last_error = NULL WHERE last_error IS NOT NULL',
    updates: {db.outboxTable},
  );

  @override
  Future<void> discardFailed(int outboxId) => db.transaction(() async {
    final row = await (db.select(db.outboxTable)..where((t) => t.id.equals(outboxId))).getSingleOrNull();
    if (row == null) return;
    for (final table in outboxTables(row.payload)) {
      await (db.delete(db.metaTable)..where((t) => t.key.equals(_kCursor(table)))).go();
    }
    await (db.delete(db.outboxTable)..where((t) => t.id.equals(outboxId))).go();
  });

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
          final type = BusinessType.fromName(r['business_type'] as String?);
          if (type != null) await _setMeta(_kType, type.name);
          final modules = modulesFromRemote(r['modules']);
          if (modules != null) await _setMeta(_kModules, modulesToText(modules));
          final methods = payMethodsFromRemote(r['pay_methods']);
          if (methods != null) await _setMeta(_kPayMethods, payMethodsToText(methods));
          if (r.containsKey('credit_limit')) {
            await _setMeta(_kCreditLimit, _centsText(r['credit_limit']));
          }
          // Con cuenta, el plan es el de la nube (lo cambia solo el cobro): la vista previa ya no aplica.
          final plan = PlanInfo.fromRemote(r['plan']);
          if (plan != null) await _setMeta(_kPlan, plan.name);
          if (r.containsKey('logo_path')) {
            final logo = (r['logo_path'] as String?) ?? '';
            await _setMeta(_kLogo, logo);
            if (logo.isEmpty) {
              await (db.delete(db.productPhotosTable)..where((t) => t.productId.equals(logoPhotoId))).go();
            }
          }
        case 'customers':
          await db.into(db.customersTable).put(customerFromRemote(r));
        case 'products':
          await db.into(db.productsTable).put(productFromRemote(r));
        case 'cash_sessions':
          await db.into(db.cashSessionsTable).put(sessionFromRemote(r));
        case 'sales':
          final sale = saleFromRemote(r);
          await db.into(db.salesTable).put(sale);
          // El siguiente folio de este teléfono nunca queda por debajo de lo que ya subió.
          if (sale.device == null || sale.device == deviceCode) {
            final folio = int.tryParse((await _meta())[_kFolio] ?? '') ?? 1;
            if (sale.folio >= folio) await _setMeta(_kFolio, '${sale.folio + 1}');
          }
        case 'sale_items':
          await db.into(db.saleLinesTable).put(saleLineFromRemote(r));
        case 'sale_payments':
          // El orden de los pagos sale de su hora (cada uno se sube con un milisegundo de diferencia).
          final row = salePaymentFromRemote(r);
          final at = DateTime.tryParse(r['created_at'] as String? ?? '');
          await db.into(db.salePaymentsTable).put(row.copyWith(position: (at?.millisecondsSinceEpoch ?? 0) % 1000));
        case 'sale_returns':
          await db.into(db.saleReturnsTable).put(saleReturnFromRemote(r));
        case 'credit_entries':
          await db.into(db.creditEntriesTable).put(creditFromRemote(r));
        case 'cash_movements':
          await db.into(db.cashMovementsTable).put(movementFromRemote(r));
        case 'lots':
          await db.into(db.lotsTable).put(lotFromRemote(r));
        case 'lot_sales':
          await db.into(db.lotSalesTable).put(lotSaleFromRemote(r));
        case 'layaways':
          await db.into(db.layawaysTable).put(layawayFromRemote(r));
        case 'layaway_payments':
          await db.into(db.layawayPaymentsTable).put(layawayPaymentFromRemote(r));
        case 'batches':
          await db.into(db.batchesTable).put(batchFromRemote(r));
        case 'batch_orders':
          await db.into(db.batchOrdersTable).put(batchOrderFromRemote(r));
        case 'restaurant_tables':
          await db.into(db.diningTablesTable).put(tableFromRemote(r));
        case 'floor_items':
          await db.into(db.floorItemsTable).put(floorItemFromRemote(r));
        case 'extras':
          await db.into(db.extrasTable).put(extraFromRemote(r));
        case 'orders':
          await db.into(db.ordersTable).put(orderFromRemote(r));
        case 'order_items':
          await db.into(db.orderItemsTable).put(orderItemFromRemote(r));
      }
    }
  });
}

/// Pesos de Supabase a centavos en texto para los datos sueltos ('' si no hay).
String _centsText(Object? pesos) => switch (pesos) {
  null => '',
  final num n => '${(n * 100).round()}',
  final String s => double.tryParse(s) == null ? '' : '${(double.parse(s) * 100).round()}',
  _ => '',
};

/// Guarda el renglón completo, también los campos vacíos. Con insertOnConflictUpdate un null se ignora y se
/// queda el valor viejo: quitar el código de barras, el mínimo o la foto no se guardaba.
extension _Put<T extends Table, D> on InsertStatement<T, D> {
  Future<int> put(Insertable<D> row) => insert(row, mode: InsertMode.insertOrReplace);
}
