import 'dart:async';

import 'package:gavilan/data/remote_mapping.dart';
import 'package:gavilan/data/sync_remote.dart';

/// Servidor simulado que se comporta como el Supabase del proyecto:
/// - guarda filas por negocio y marca synced_at con la hora del servidor;
/// - un upsert solo cambia las columnas que se mandan;
/// - un movimiento de inventario nuevo suma a products.stock_qty (como el trigger).
class FakeServer {
  final Map<String, Map<String, Map<String, Object?>>> tables = {};
  final Map<String, String> membership = {}; // usuario -> negocio
  final Set<String> rejectTables = {};
  DateTime _clock = DateTime.utc(2026, 10, 26, 12);
  int writes = 0;

  DateTime _tick() => _clock = _clock.add(const Duration(milliseconds: 1));

  Map<String, Map<String, Object?>> table(String name) => tables.putIfAbsent(name, () => {});

  List<Map<String, Object?>> rows(String name) => table(name).values.toList();

  void _write(String name, Map<String, Object?> row) {
    writes++;
    final t = table(name);
    final id = row['id']! as String;
    final isNew = !t.containsKey(id);
    t[id] = {...?t[id], ...row, 'synced_at': _tick().toIso8601String()};
    if (name == 'inventory_movements' && isNew) {
      final product = table('products')[row['product_id']];
      if (product != null) {
        final stock = ((product['stock_qty'] as num?) ?? 0) + (row['qty_change']! as num);
        table('products')[product['id']! as String] = {
          ...product,
          'stock_qty': stock,
          'synced_at': _tick().toIso8601String(),
        };
      }
    }
  }
}

/// La sesión de un teléfono contra el servidor simulado.
class FakeRemote implements SyncRemote {
  FakeRemote(this.server);

  final FakeServer server;
  final _auth = StreamController<void>.broadcast();
  String? _user;
  bool offline = false;

  void _check() {
    if (offline) throw const SyncException(SyncFailure.network, 'Sin conexión con el servidor');
  }

  @override
  String? get userId => _user;

  @override
  String? get email => _user;

  @override
  Stream<void> get authChanges => _auth.stream;

  @override
  Future<void> signIn(String email, String password) async {
    _check();
    _user = email;
    _auth.add(null);
  }

  @override
  Future<bool> signUp(String email, String password) async {
    await signIn(email, password);
    return true;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _auth.add(null);
  }

  @override
  Future<({String id, String name})?> myBusiness() async {
    _check();
    final id = server.membership[_user];
    if (id == null) return null;
    return (id: id, name: server.table('businesses')[id]!['name']! as String);
  }

  @override
  Future<void> createBusiness({required String id, required String name}) async {
    _check();
    server._write('businesses', {'id': id, 'name': name});
    server.membership[_user!] = id;
  }

  @override
  Future<void> upsert(String table, String businessId, List<RemoteRow> rows) async {
    _check();
    if (server.rejectTables.contains(table)) {
      throw SyncException(SyncFailure.rejected, 'rechazado: $table');
    }
    if (server.membership[_user] != businessId) throw const SyncException(SyncFailure.rejected, 'RLS');
    for (final r in rows) {
      server._write(table, {...r, 'business_id': businessId});
    }
  }

  @override
  Future<List<RemoteRow>> changes(
    String table,
    String businessId,
    DateTime since, {
    required int offset,
    required int limit,
  }) async {
    _check();
    final all =
        server
            .rows(table)
            .where((r) => (table == 'businesses' ? r['id'] : r['business_id']) == businessId)
            .where((r) => DateTime.parse(r['synced_at']! as String).isAfter(since))
            .toList()
          ..sort((a, b) => (a['synced_at']! as String).compareTo(b['synced_at']! as String));
    return all.skip(offset).take(limit).map((r) => Map<String, Object?>.from(r)).toList();
  }
}
