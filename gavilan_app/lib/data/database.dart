import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/models.dart';
import '../domain/restaurant.dart';

part 'database.g.dart';

// Tablas locales (SQLite en el teléfono). Nombres y columnas siguen a las de
// Supabase (proyecto-Gavilan) para que la sincronización sea directa.

@DataClassName('ProductRow')
class ProductsTable extends Table {
  @override
  String get tableName => 'products';

  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get priceCents => integer()();
  IntColumn get costCents => integer().withDefault(const Constant(0))();
  TextColumn get barcode => text().nullable()();
  TextColumn get iconId => text().withDefault(const Constant('otro'))();
  BoolColumn get trackStock => boolean().withDefault(const Constant(false))();
  RealColumn get stock => real().withDefault(const Constant(0))();
  RealColumn get minStock => real().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get photoPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CustomerRow')
class CustomersTable extends Table {
  @override
  String get tableName => 'customers';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  IntColumn get creditLimitCents => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SaleRow')
class SalesTable extends Table {
  @override
  String get tableName => 'sales';

  TextColumn get id => text()();
  IntColumn get folio => integer()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get kind => textEnum<SaleKind>()();
  TextColumn get sessionId => text().nullable()();
  TextColumn get method => textEnum<PayMethod>().nullable()();
  IntColumn get receivedCents => integer().nullable()();
  TextColumn get customerId => text().nullable()();
  TextColumn get device => text().nullable()();
  TextColumn get orderId => text().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get cancelReason => text().nullable()();
  TextColumn get cancelledInSession => text().nullable()();
  IntColumn get discountCents => integer().withDefault(const Constant(0))();
  TextColumn get clerkName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Fotos de producto: los bytes (ya chicos, 600×600) para verlas sin internet y si ya se subieron.
/// Devoluciones de ventas de cortes ya cerrados. [lines] es JSON (lista de [ReturnedLine]).
@DataClassName('SaleReturnRow')
class SaleReturnsTable extends Table {
  @override
  String get tableName => 'sale_returns';

  TextColumn get id => text()();
  TextColumn get saleId => text()();
  TextColumn get sessionId => text()();
  TextColumn get lines => text()();
  IntColumn get amountCents => integer()();
  IntColumn get cashCents => integer().withDefault(const Constant(0))();
  TextColumn get reason => text().nullable()();
  TextColumn get clerk => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PhotoRow')
class ProductPhotosTable extends Table {
  @override
  String get tableName => 'product_photos';

  TextColumn get path => text()();
  TextColumn get productId => text()();
  BlobColumn get bytes => blob()();
  BoolColumn get uploaded => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {path};
}

/// Pagos de una venta pagada en partes o con varios métodos.
@DataClassName('SalePaymentRow')
class SalePaymentsTable extends Table {
  @override
  String get tableName => 'sale_payments';

  TextColumn get id => text()();
  TextColumn get saleId => text()();
  TextColumn get method => textEnum<PayMethod>()();
  IntColumn get amountCents => integer()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SaleLineRow')
class SaleLinesTable extends Table {
  @override
  String get tableName => 'sale_items';

  TextColumn get saleId => text()();
  IntColumn get position => integer()();
  TextColumn get lineKey => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get name => text()();
  IntColumn get unitCents => integer()();
  IntColumn get unitCostCents => integer().withDefault(const Constant(0))();
  RealColumn get qty => real()();

  @override
  Set<Column> get primaryKey => {saleId, position};
}

@DataClassName('CreditRow')
class CreditEntriesTable extends Table {
  @override
  String get tableName => 'credit_entries';

  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get type => textEnum<CreditType>()();
  IntColumn get amountCents => integer()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get saleId => text().nullable()();
  TextColumn get method => textEnum<PayMethod>().nullable()();
  TextColumn get sessionId => text().nullable()();
  TextColumn get clerkName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SessionRow')
class CashSessionsTable extends Table {
  @override
  String get tableName => 'cash_sessions';

  TextColumn get id => text()();
  DateTimeColumn get openedAt => dateTime()();
  IntColumn get openingCents => integer()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  IntColumn get expectedCents => integer().nullable()();
  IntColumn get countedCents => integer().nullable()();
  TextColumn get device => text().nullable()();
  TextColumn get name => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MovementRow')
class CashMovementsTable extends Table {
  @override
  String get tableName => 'cash_movements';

  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get kind => textEnum<CashKind>()();
  IntColumn get amountCents => integer()();
  TextColumn get concept => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get clerkName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Datos sueltos del negocio: nombre, siguiente folio, plan.
@DataClassName('MetaRow')
class MetaTable extends Table {
  @override
  String get tableName => 'meta';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ---------- Pacas y lotes ----------

@DataClassName('LotRow')
class LotsTable extends Table {
  @override
  String get tableName => 'lots';

  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get investmentCents => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LotSaleRow')
class LotSalesTable extends Table {
  @override
  String get tableName => 'lot_sales';

  TextColumn get id => text()();
  TextColumn get lotId => text()();
  IntColumn get amountCents => integer()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get sessionId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------- Apartados ----------

@DataClassName('LayawayRow')
class LayawaysTable extends Table {
  @override
  String get tableName => 'layaways';

  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get description => text()();
  IntColumn get totalCents => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => textEnum<LayawayStatus>()();
  TextColumn get photoPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LayawayPaymentRow')
class LayawayPaymentsTable extends Table {
  @override
  String get tableName => 'layaway_payments';

  TextColumn get id => text()();
  TextColumn get layawayId => text()();
  IntColumn get amountCents => integer()();
  TextColumn get method => textEnum<PayMethod>()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get sessionId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------- Pedidos por tanda ----------

@DataClassName('BatchRow')
class BatchesTable extends Table {
  @override
  String get tableName => 'batches';

  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get suppliesCents => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BatchOrderRow')
class BatchOrdersTable extends Table {
  @override
  String get tableName => 'batch_orders';

  TextColumn get id => text()();
  TextColumn get batchId => text()();
  TextColumn get customerName => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get detail => text().nullable()();
  IntColumn get totalCents => integer()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get delivery => textEnum<DeliveryStatus>()();
  BoolColumn get paid => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Fila de pendientes: cambios hechos en el teléfono que faltan por subir a Supabase.
/// Cada renglón trae las filas ya con forma de Supabase (sin business_id).
@DataClassName('OutboxRow')
class OutboxTable extends Table {
  @override
  String get tableName => 'outbox';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

@DataClassName('DiningTableRow')
class DiningTablesTable extends Table {
  @override
  String get tableName => 'restaurant_tables';

  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get zone => text().nullable()();

  /// Plano: posición, forma y sillas (v17). null = como antes (se acomoda sola, cuadrada, 4 sillas).
  IntColumn get posX => integer().nullable()();
  IntColumn get posY => integer().nullable()();
  TextColumn get shape => text().nullable()();
  IntColumn get seats => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('OrderRow')
class OrdersTable extends Table {
  @override
  String get tableName => 'orders';

  TextColumn get id => text()();
  TextColumn get tableId => text().nullable()();
  TextColumn get label => text().nullable()();
  TextColumn get status => textEnum<OrderStatus>()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('OrderItemRow')
class OrderItemsTable extends Table {
  @override
  String get tableName => 'order_items';

  TextColumn get id => text()();
  TextColumn get orderId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get name => text()();
  RealColumn get qty => real()();
  IntColumn get unitCents => integer()();
  TextColumn get notes => text().nullable()();

  /// Extras del platillo en JSON: [{"name": "Extra queso", "cents": 1000}].
  TextColumn get extras => text().nullable()();
  TextColumn get status => textEnum<KitchenStatus>()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get sentAt => dateTime().nullable()();
  DateTimeColumn get readyAt => dateTime().nullable()();
  DateTimeColumn get servedAt => dateTime().nullable()();

  /// Piezas ya cobradas al dividir la cuenta por platillos.
  RealColumn get paidQty => real().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Extras con precio del restaurante.
@DataClassName('ExtraRow')
class ExtrasTable extends Table {
  @override
  String get tableName => 'extras';

  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get priceCents => integer()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    ExtrasTable,
    OutboxTable,
    DiningTablesTable,
    OrdersTable,
    OrderItemsTable,
    LotsTable,
    LotSalesTable,
    LayawaysTable,
    LayawayPaymentsTable,
    BatchesTable,
    BatchOrdersTable,
    ProductsTable,
    CustomersTable,
    SalesTable,
    SaleLinesTable,
    SalePaymentsTable,
    ProductPhotosTable,
    SaleReturnsTable,
    CreditEntriesTable,
    CashSessionsTable,
    CashMovementsTable,
    MetaTable,
  ],
)
class GavilanDb extends _$GavilanDb {
  GavilanDb(super.executor);

  /// Base guardada en el teléfono (carpeta de documentos de la app).
  /// En el navegador usa sqlite3.wasm y drift_worker.js (en web/) y guarda en OPFS o IndexedDB.
  /// [name]: cada negocio de este teléfono tiene su propio archivo ("gavilan" es el primero).
  factory GavilanDb.onDevice({String name = 'gavilan'}) => GavilanDb(
    driftDatabase(
      name: name,
      web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js')),
    ),
  );

  @override
  int get schemaVersion => 17;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // v2: fila de pendientes para la sincronización.
      if (from < 2) await m.createTable(outboxTable);
      // v3: pacas y lotes, apartados y pedidos por tanda.
      if (from < 3) {
        for (final table in <TableInfo>[
          lotsTable,
          lotSalesTable,
          layawaysTable,
          layawayPaymentsTable,
          batchesTable,
          batchOrdersTable,
        ]) {
          await m.createTable(table);
        }
      }
      // v4: clave del teléfono en cada venta (folios que no chocan).
      if (from < 4) await m.addColumn(salesTable, salesTable.device);
      // v5: restaurante (mesas, comandas y cocina) y la comanda que se cobró en cada venta.
      if (from < 5) {
        for (final table in <TableInfo>[diningTablesTable, ordersTable, orderItemsTable]) {
          await m.createTable(table);
        }
        await m.addColumn(salesTable, salesTable.orderId);
      }
      // v6: zonas de mesas.
      if (from < 6 && from >= 5) await m.addColumn(diningTablesTable, diningTablesTable.zone);
      if (from < 7) {
        await m.addColumn(salesTable, salesTable.cancelledAt);
        await m.addColumn(salesTable, salesTable.cancelReason);
      }
      if (from < 8) await m.addColumn(salesTable, salesTable.discountCents);
      if (from < 9) {
        await m.createTable(extrasTable);
        // Antes de la versión 5 la tabla de platillos se crea completa (ya con extras).
        if (from >= 5) await m.addColumn(orderItemsTable, orderItemsTable.extras);
      }
      if (from < 10) {
        await m.addColumn(salesTable, salesTable.clerkName);
        await m.addColumn(creditEntriesTable, creditEntriesTable.clerkName);
        await m.addColumn(cashMovementsTable, cashMovementsTable.clerkName);
      }
      if (from < 11) await m.addColumn(customersTable, customersTable.creditLimitCents);
      if (from < 12) {
        await m.createTable(salePaymentsTable);
        if (from >= 5) await m.addColumn(orderItemsTable, orderItemsTable.paidQty);
      }
      if (from < 13) await m.addColumn(cashSessionsTable, cashSessionsTable.device);
      if (from < 14) {
        await m.addColumn(cashSessionsTable, cashSessionsTable.name);
        await m.addColumn(salesTable, salesTable.cancelledInSession);
      }
      if (from < 15) {
        await m.addColumn(productsTable, productsTable.photoPath);
        await m.createTable(productPhotosTable);
      }
      if (from < 16) {
        await m.addColumn(layawaysTable, layawaysTable.photoPath);
        await m.createTable(saleReturnsTable);
      }
      // v17: plano de mesas (antes de la 5 la tabla de mesas se crea completa).
      if (from < 17 && from >= 5) {
        await m.addColumn(diningTablesTable, diningTablesTable.posX);
        await m.addColumn(diningTablesTable, diningTablesTable.posY);
        await m.addColumn(diningTablesTable, diningTablesTable.shape);
        await m.addColumn(diningTablesTable, diningTablesTable.seats);
      }
    },
  );
}
