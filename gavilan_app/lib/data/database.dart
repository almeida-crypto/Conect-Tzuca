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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // v2: fila de pendientes para la sincronización.
      if (from < 2) await m.createTable(outboxTable);
    },
  );
}
