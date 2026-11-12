import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../domain/team.dart';
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

  /// Manda el correo para elegir una contraseña nueva.
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String password);

  /// Abre la sesión que trae un enlace de los correos de la cuenta. false si el enlace sirvió
  /// pero se abrió en otro celular: el correo queda confirmado y solo falta entrar.
  Future<bool> openAuthLink(Uri uri);

  /// El negocio al que pertenece el usuario, si tiene, y su rol en él.
  Future<({String id, String name, MemberRole role})?> myBusiness();
  Future<void> createBusiness({required String id, required String name});

  // Equipo
  Future<void> acceptInvite(String code);
  Future<String> createInvite(String businessId, MemberRole role, String name);
  Future<List<TeamMember>> members(String businessId);
  Future<List<TeamInvite>> invites(String businessId);
  Future<void> revokeInvite(String inviteId);
  Future<void> removeMember(String memberId);

  /// Avisa cuando otro teléfono cambia comandas o platillos (Supabase Realtime).
  Stream<void> live(String businessId);

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
      throw SyncException(expired ? SyncFailure.auth : SyncFailure.rejected, _teamMessage(e.message));
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

  /// Errores de las funciones del equipo (0005_team.sql), en palabras del usuario.
  static String _teamMessage(String m) => switch (m) {
    'invalid_invite' => 'Ese código no existe, ya se usó o ya venció. Pide otro',
    'already_member' => 'Tu cuenta ya pertenece a un negocio. Para unirte a otro, usa otra cuenta',
    'not_allowed' => 'Solo el dueño o un administrador pueden hacer esto',
    _ => m,
  };

  static String _authMessage(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Correo o contraseña incorrectos';
    if (m.contains('not confirmed')) return 'Falta confirmar tu correo: abre el mensaje que te mandamos';
    if (m.contains('already registered')) return 'Ese correo ya tiene cuenta. Entra con tu contraseña';
    if (m.contains('password') && m.contains('6')) return 'La contraseña debe tener al menos 6 caracteres';
    if (m.contains('rate limit')) return 'Demasiados intentos. Espera unos minutos';
    if (m.contains('expired') || m.contains('invalid flow state')) return 'El enlace ya venció o ya se usó. Pide otro';
    if (m.contains('different from the old')) return 'La contraseña nueva debe ser distinta a la anterior';
    if (m.contains('no code detected')) return 'Ese enlace no está completo. Pide otro correo';
    if (m.contains('socket') || m.contains('network') || m.contains('host lookup')) {
      return 'Sin conexión con el servidor';
    }
    return e.message;
  }

  @override
  Future<void> signIn(String email, String password) =>
      _guard(() => client.auth.signInWithPassword(email: email.trim(), password: password));

  @override
  Future<bool> signUp(String email, String password) => _guard(() async {
    final res = await client.auth.signUp(email: email.trim(), password: password, emailRedirectTo: AuthLinks.confirmed);
    return res.session != null;
  });

  @override
  Future<void> signOut() => _guard(() => client.auth.signOut());

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => client.auth.resetPasswordForEmail(email.trim(), redirectTo: AuthLinks.newPassword));

  @override
  Future<void> updatePassword(String password) =>
      _guard(() => client.auth.updateUser(UserAttributes(password: password)));

  @override
  Future<bool> openAuthLink(Uri uri) => _guard(() async {
    try {
      await client.auth.getSessionFromUrl(uri);
      return true;
    } on AuthException catch (e) {
      // La clave para abrir la sesión se guarda en el celular que pidió el correo.
      if (e.message.toLowerCase().contains('code verifier')) return false;
      rethrow;
    }
  });

  @override
  Future<({String id, String name, MemberRole role})?> myBusiness() => _guard(() async {
    final uid = userId;
    if (uid == null) return null;
    final rows = await client
        .from('business_members')
        .select('business_id, role, businesses(name)')
        .eq('user_id', uid)
        .isFilter('deleted_at', null)
        .order('created_at')
        .limit(1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final business = row['businesses'] as Map<String, dynamic>?;
    return (
      id: row['business_id'] as String,
      name: (business?['name'] as String?) ?? 'Mi negocio',
      role: MemberRole.fromRemote(row['role'] as String?) ?? MemberRole.cashier,
    );
  });

  @override
  Future<void> acceptInvite(String code) => _guard(() => client.rpc('accept_invite', params: {'p_code': code}));

  @override
  Future<String> createInvite(String businessId, MemberRole role, String name) => _guard(
    () async =>
        await client.rpc('create_invite', params: {'p_business': businessId, 'p_role': role.name, 'p_name': name})
            as String,
  );

  @override
  Future<List<TeamMember>> members(String businessId) => _guard(() async {
    final rows = await client
        .from('business_members')
        .select('id, user_id, role, display_name')
        .eq('business_id', businessId)
        .isFilter('deleted_at', null)
        .order('created_at');
    return [
      for (final r in rows)
        TeamMember(
          id: r['id'] as String,
          userId: r['user_id'] as String,
          role: MemberRole.fromRemote(r['role'] as String?) ?? MemberRole.cashier,
          name: r['display_name'] as String?,
        ),
    ];
  });

  @override
  Future<List<TeamInvite>> invites(String businessId) => _guard(() async {
    final rows = await client
        .from('business_invites')
        .select('id, code, role, display_name, expires_at')
        .eq('business_id', businessId)
        .isFilter('used_at', null)
        .isFilter('revoked_at', null)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at');
    return [
      for (final r in rows)
        TeamInvite(
          id: r['id'] as String,
          code: r['code'] as String,
          role: MemberRole.fromRemote(r['role'] as String?) ?? MemberRole.cashier,
          name: r['display_name'] as String?,
          expiresAt: DateTime.parse(r['expires_at'] as String).toLocal(),
        ),
    ];
  });

  @override
  Future<void> revokeInvite(String inviteId) =>
      _guard(() => client.rpc('revoke_invite', params: {'p_invite': inviteId}));

  @override
  Future<void> removeMember(String memberId) =>
      _guard(() => client.rpc('remove_member', params: {'p_member': memberId}));

  @override
  Future<void> createBusiness({required String id, required String name}) =>
      _guard(() => client.rpc('create_business', params: {'p_name': name, 'p_id': id}));

  @override
  Stream<void> live(String businessId) {
    late final RealtimeChannel channel;
    final controller = StreamController<void>(onCancel: () => client.removeChannel(channel));
    channel = client.channel('negocio-$businessId');
    for (final table in ['orders', 'order_items']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'business_id', value: businessId),
        callback: (_) => controller.add(null),
      );
    }
    channel.subscribe();
    return controller.stream;
  }

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
    // Los productos bajan por una función que les quita el costo a meseros y cocina (ver 0008_hide_cost.sql).
    if (table == 'products') {
      final rows = await client.rpc<List<dynamic>>(
        'pull_products',
        params: {
          'p_business_id': businessId,
          'p_since': since.toUtc().toIso8601String(),
          'p_offset': offset,
          'p_limit': limit,
        },
      );
      return [for (final r in rows) Map<String, Object?>.from(r as Map)];
    }
    final base = client.from(table).select();
    final filtered = table == 'businesses' ? base.eq('id', businessId) : base.eq('business_id', businessId);
    final rows = await filtered
        .gt('synced_at', since.toUtc().toIso8601String())
        .order('synced_at')
        .range(offset, offset + limit - 1);
    return [for (final r in rows) Map<String, Object?>.from(r)];
  });
}
