import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/data/database.dart';
import 'package:gavilan/data/repository.dart';
import 'package:gavilan/domain/models.dart';
import 'package:gavilan/domain/plan.dart';
import 'package:gavilan/domain/restaurant.dart';

import 'generated_migrations/schema.dart';

/// Un celular con una versión vieja de la app se actualiza: su base sube a la versión de hoy sin perder nada.
///
/// Las fotos del esquema de cada versión que se repartió en APK están en `drift_schemas/` (se sacan del
/// historial con `drift_dev schema dump`). Al cambiar la base: subir `schemaVersion`, agregar el paso en
/// `onUpgrade`, guardar el esquema nuevo (`dart run drift_dev schema dump lib/data/database.dart
/// drift_schemas/drift_schema_vN.json`), regenerar (`dart run drift_dev schema generate --data-classes
/// --companions drift_schemas/ test/generated_migrations/`) y agregar N a [current] aquí.
void main() {
  /// Versiones de la base que salieron en un APK (1.1.1, 1.6.1, 1.8.0, 1.9.0, 1.10.0/1.11.0, 1.12.0 y 1.13.0).
  const released = [7, 10, 14, 15, 16, 19, 21];
  const current = 22;

  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('la base de hoy es la que dice el último esquema guardado', () {
    expect(GavilanDb(DatabaseConnection(NativeDatabase.memory())).schemaVersion, current);
  });

  for (final from in released) {
    test('de la versión $from a la $current: queda igual que una base nueva', () async {
      final connection = await verifier.startAt(from);
      final db = GavilanDb(connection);
      await verifier.migrateAndValidate(db, current);
      await db.close();
    });

    test('de la versión $from a la $current: no se pierde el negocio, ventas, fiados ni mesas', () async {
      final schema = await verifier.schemaAt(from);
      // Lo que tenía el celular viejo, con las columnas que ya existían desde la versión 7.
      final old = schema.rawDatabase;
      final statements = [
        "insert into meta (key, value) values ('business_id', 'b1'), ('business_name', 'Fonda Doña Mary'), "
            "('next_folio', '3'), ('plan', 'negocio'), ('business_type', 'restaurante')",
        "insert into products (id, name, price_cents, cost_cents, icon_id, track_stock, stock, active) "
            "values ('p1', 'Tacos de pastor', 2000, 1200, 'taco', 1, 40, 1)",
        "insert into customers (id, name, phone) values ('c1', 'Don Pepe', '9991234567')",
        "insert into cash_sessions (id, opened_at, opening_cents) values ('s1', '2026-11-01T08:00:00.000', 50000)",
        "insert into sales (id, folio, created_at, kind, session_id, method, received_cents) "
            "values ('v1', 1, '2026-11-01T09:00:00.000', 'pagada', 's1', 'efectivo', 5000)",
        "insert into sale_items (sale_id, position, line_key, product_id, name, unit_cents, unit_cost_cents, qty) "
            "values ('v1', 0, 'p1', 'p1', 'Tacos de pastor', 2000, 1200, 2)",
        "insert into sales (id, folio, created_at, kind, session_id, customer_id) "
            "values ('v2', 2, '2026-11-01T10:00:00.000', 'fiada', 's1', 'c1')",
        "insert into sale_items (sale_id, position, line_key, product_id, name, unit_cents, unit_cost_cents, qty) "
            "values ('v2', 0, 'p1', 'p1', 'Tacos de pastor', 2000, 1200, 1)",
        "insert into credit_entries (id, customer_id, type, amount_cents, created_at, sale_id) "
            "values ('e1', 'c1', 'cargo', 2000, '2026-11-01T10:00:00.000', 'v2')",
        "insert into cash_movements (id, session_id, kind, amount_cents, concept, created_at) "
            "values ('m1', 's1', 'gasto', 3000, 'Hielo', '2026-11-01T11:00:00.000')",
        "insert into restaurant_tables (id, name, position, active, zone) values ('t1', 'Mesa 1', 1, 1, 'Terraza')",
        "insert into orders (id, table_id, status, created_at) values ('o1', 't1', 'abierta', '2026-11-01T12:00:00.000')",
        "insert into order_items (id, order_id, product_id, name, qty, unit_cents, status, created_at) "
            "values ('i1', 'o1', 'p1', 'Tacos de pastor', 3, 2000, 'pendiente', '2026-11-01T12:01:00.000')",
        "insert into outbox (payload, created_at, attempts) values ('[]', '2026-11-01T12:02:00.000', 0)",
        "insert into layaways (id, customer_id, description, total_cents, created_at, status) "
            "values ('l1', 'c1', 'Vestido azul', 50000, '2026-11-01T13:00:00.000', 'activo')",
        "insert into layaway_payments (id, layaway_id, amount_cents, method, created_at, session_id) "
            "values ('a1', 'l1', 10000, 'efectivo', '2026-11-01T13:00:00.000', 's1')",
      ];
      for (final sql in statements) {
        old.execute(sql);
      }

      final db = GavilanDb(schema.newConnection());
      await verifier.migrateAndValidate(db, current);
      final loaded = (await DriftRepository(db).load())!;
      final s = loaded.store;

      expect(s.businessName, 'Fonda Doña Mary');
      expect(loaded.plan, Plan.negocio);
      expect(s.nextFolio, 3);
      expect(s.products.single.name, 'Tacos de pastor');
      expect(s.products.single.stock, 40);
      // Lo nuevo de las versiones de después viene con su valor de siempre.
      expect(s.products.single.place, ProductPlace.todos);
      expect(s.products.single.photoPath, isNull);

      expect(s.sales.map((v) => v.folio), [1, 2]);
      final paid = s.sales.first;
      expect((paid.totalCents, paid.tipCents, paid.discountCents, paid.cancelled), (4000, 0, 0, false));
      expect(s.sales.last.kind, SaleKind.fiada);
      expect(s.balanceOf('c1'), 2000);

      final cut = s.summaryFor(s.sessions.single);
      expect(cut.expectedCashCents, 50000 + 4000 - 3000 + 10000);
      expect(cut.tipsCents, 0);

      final table = s.tables.single;
      expect(
        (table.name, table.zone, table.placed, table.shape, table.seats),
        ('Mesa 1', 'Terraza', false, TableShape.cuadrada, 4),
      );
      expect(s.openOrderOfTable('t1')!.id, 'o1');
      expect(s.itemsOfOrder('o1').single.qty, 3);
      expect(s.floorItems, isEmpty);
      expect(s.products.single.parentId, isNull);
      expect(s.isModel(s.products.single), isFalse);

      // El apartado de antes sigue activo, sin piezas del inventario y con su anticipo.
      final layaway = s.layaways.single;
      expect((layaway.description, layaway.kept, layaway.delivered), ('Vestido azul', true, false));
      expect((layaway.refundCents, layaway.creditCents, layaway.payEveryDays), (0, 0, null));
      expect(s.itemsOfLayaway('l1'), isEmpty);
      expect(s.pendingOfLayaway('l1'), 40000);
      expect(s.paymentsOfLayaway('l1').single.fromCredit, isFalse);
      expect(s.saleReturns, isEmpty);

      // Lo que faltaba por subir a la nube sigue pendiente.
      expect(await db.select(db.outboxTable).get(), hasLength(1));
      await db.close();
    });
  }
}
