import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'remote_mapping.dart';

enum SyncFailure { network, auth, rejected }

class SyncException implements Exception {
  const SyncException(this.kind, this.message);

  final SyncFailure kind;
  final String message;

  @override
  String toString() => message;
}

/// Lo que el motor necesita del servidor. Hay una versión real (Supabase) y una
/// simulada para las pruebas.
abstract class SyncRemote {
  String? get userId;
  String? get email;
  Stream<void> get authChanges;

  Future<void> signIn(String email, String password);

  /// true si la cuenta quedó con sesión; false si falta confirmar el correo.
  Future<bool> signUp(String email, String password);
  Future<void> signOut();

  /// El negocio al que pertenece el usuario, si tiene.
  Future<({String id, String name})?> myBusiness();
  Future<void> createBusiness({required String id, required String name});

  Future<void> upsert(String table, String businessId, List<RemoteRow> rows);
  Future<List<RemoteRow>> changes(
    String table,
    String businessId,
    DateTime since, {
    required int offset,
    required int limit,
  });
}

class SupabaseRemote implements SyncRemote {
  SupabaseRemote(this.client);

  final SupabaseClient client;

  @override
  String? get userId => client.auth.currentUser?.id;

  @override
  String? get email => client.auth.currentUser?.email;

  @override
  Stream<void> get authChanges => client.auth.onAuthStateChange.map((_) {});

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AuthException catch (e) {
      throw SyncException(SyncFailure.auth, _authMessage(e));
    } on PostgrestException catch (e) {
      final expired = e.code == 'PGRST301' || e.code == '401' || e.message.contains('JWT');
      throw SyncException(expired ? SyncFailure.auth : SyncFailure.rejected, e.message);
    } catch (e) {
      final text = e.toString();
      final network =
          e is TimeoutException ||
          text.contains('SocketException') ||
          text.contains('ClientException') ||
          text.contains('Failed host lookup') ||
          text.contains('Connection');
      if (network) {
        throw const SyncException(SyncFailure.network, 'Sin conexión con el servidor');
      }
      throw SyncException(SyncFailure.rejected, text);
    }
  }

  static String _authMessage(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Correo o contraseña incorrectos';
    if (m.contains('not confirmed')) return 'Falta confirmar tu correo: abre el mensaje que te mandamos';
    if (m.contains('already registered')) return 'Ese correo ya tiene cuenta. Entra con tu contraseña';
    if (m.contains('password') && m.contains('6')) return 'La contraseña debe tener al menos 6 caracteres';
    if (m.contains('rate limit')) return 'Demasiados intentos. Espera unos minutos';
    if (m.contains('socket') || m.contains('network') || m.contains('host lookup')) {
      return 'Sin conexión con el servidor';
    }
    return e.message;
  }

  @override
  Future<void> signIn(String email, String password) =>
      _guard(() => client.auth.signInWithPassword(email: email.trim(), password: password));

  @override
  Future<bool> signUp(String email, String password) =>
      _guard(() async => (await client.auth.signUp(email: email.trim(), password: password)).session != null);

  @override
  Future<void> signOut() => _guard(() => client.auth.signOut());

  @override
  Future<({String id, String name})?> myBusiness() => _guard(() async {
    final uid = userId;
    if (uid == null) return null;
    final rows = await client
        .from('business_members')
        .select('business_id, businesses(name)')
        .eq('user_id', uid)
        .isFilter('deleted_at', null)
        .order('created_at')
        .limit(1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final business = row['businesses'] as Map<String, dynamic>?;
    return (id: row['business_id'] as String, name: (business?['name'] as String?) ?? 'Mi negocio');
  });

  @override
  Future<void> createBusiness({required String id, required String name}) =>
      _guard(() => client.rpc('create_business', params: {'p_name': name, 'p_id': id}));

  @override
  Future<void> upsert(String table, String businessId, List<RemoteRow> rows) => _guard(() async {
    if (rows.isEmpty) return;
    await client.from(table).upsert([
      for (final r in rows) {...r, 'business_id': businessId},
    ], onConflict: 'id');
  });

  @override
  Future<List<RemoteRow>> changes(
    String table,
    String businessId,
    DateTime since, {
    required int offset,
    required int limit,
  }) => _guard(() async {
    final base = client.from(table).select();
    final filtered = table == 'businesses' ? base.eq('id', businessId) : base.eq('business_id', businessId);
    final rows = await filtered
        .gt('synced_at', since.toUtc().toIso8601String())
        .order('synced_at')
        .range(offset, offset + limit - 1);
    return [for (final r in rows) Map<String, Object?>.from(r)];
  });
}
