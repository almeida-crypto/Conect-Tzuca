import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/models.dart';

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

@DriftDatabase(
  tables: [
    OutboxTable,
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
    CreditEntriesTable,
    CashSessionsTable,
    CashMovementsTable,
    MetaTable,
  ],
)
class GavilanDb extends _$GavilanDb {
  GavilanDb(super.executor);

  /// Base guardada en el teléfono (carpeta de documentos de la app).
  factory GavilanDb.onDevice() => GavilanDb(driftDatabase(name: 'gavilan'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // v2: fila de pendientes para la sincronización.
      if (from < 2) await m.createTable(outboxTable);
      // v3: pacas y lotes, apartados y pedidos por tanda.
      if (from < 4) await m.addColumn(salesTable, salesTable.device);
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
    },
  );
}
