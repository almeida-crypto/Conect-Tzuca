import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../data/repository.dart';
import '../data/sync_remote.dart';
import '../domain/team.dart';
import 'store.dart';

/// Conexión con Supabase. main() la configura; en pruebas y en web sin internet queda en null.
final syncRemoteProvider = Provider<SyncRemote?>((ref) => null);

/// Si es false, no se vigila la red (pruebas sin plugins de plataforma).
final watchConnectivityProvider = Provider<bool>((ref) => true);

class SyncStatus {
  const SyncStatus({
    this.configured = false,
    this.online = true,
    this.email,
    this.linked = false,
    this.pending = 0,
    this.busy = false,
    this.lastSync,
    this.problem,
    this.role,
  });

  final bool configured;
  final bool online;
  final String? email;
  final bool linked;
  final int pending;
  final bool busy;
  final DateTime? lastSync;

  /// Último error que el usuario debe ver (null = todo bien).
  final String? problem;

  /// Rol de la cuenta en el negocio enlazado (null = teléfono sin cuenta, es del dueño).
  final MemberRole? role;

  bool get signedIn => email != null;

  SyncStatus copyWith({
    bool? online,
    String? email,
    bool clearEmail = false,
    bool? linked,
    int? pending,
    bool? busy,
    DateTime? lastSync,
    String? problem,
    bool clearProblem = false,
    MemberRole? role,
  }) => SyncStatus(
    configured: configured,
    online: online ?? this.online,
    email: clearEmail ? null : (email ?? this.email),
    linked: linked ?? this.linked,
    pending: pending ?? this.pending,
    busy: busy ?? this.busy,
    lastSync: lastSync ?? this.lastSync,
    problem: clearProblem ? null : (problem ?? this.problem),
    role: role ?? this.role,
  );
}

/// Resultado de enlazar el teléfono con la cuenta.
enum LinkResult {
  /// El negocio del teléfono se subió a la nube.
  uploaded,

  /// Ya estaban enlazados; se sincronizó.
  synced,

  /// El teléfono estaba vacío y se bajó el negocio de la cuenta.
  downloaded,

  /// La cuenta no tiene negocio y el teléfono tampoco: hay que darlo de alta.
  needsBusiness,

  /// La cuenta tiene otro negocio distinto al de este teléfono.
  conflict,
}

/// Qué traía un enlace de los correos de la cuenta.
enum AuthLink {
  /// Correo confirmado y sesión abierta.
  confirmed,

  /// Correo confirmado, pero el enlace se abrió en otro celular: falta entrar con la contraseña.
  confirmedSignIn,

  /// Sesión abierta para elegir una contraseña nueva.
  newPassword,

  /// El enlace para cambiar la contraseña se abrió en otro celular.
  otherDevice,
}

class LinkOutcome {
  const LinkOutcome(this.result, {this.remoteId, this.remoteName});

  final LinkResult result;
  final String? remoteId;
  final String? remoteName;
}

/// Sincroniza el teléfono con Supabase: sube la fila de pendientes y baja lo que
/// cambió en otros dispositivos. Todo funciona igual sin internet; esto solo respalda.
class SyncController extends Notifier<SyncStatus> {
  static const _overlap = Duration(minutes: 5);
  static const _page = 500;

  Timer? _timer;
  Timer? _debounce;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  StreamSubscription<void>? _auth;
  StreamSubscription<void>? _live;
  String? _liveBusiness;
  Timer? _liveDebounce;
  bool _running = false;
  bool _again = false;

  /// El sistema dice que no hay ninguna red (ni Wi-Fi ni datos). Solo así se evita intentar:
  /// con red pero sin salida a internet se sigue intentando cada minuto.
  bool _noNetwork = false;

  SyncRemote? get _remote => ref.read(syncRemoteProvider);
  SyncStore? get _store => ref.read(repositoryProvider).sync;

  @override
  SyncStatus build() {
    final remote = ref.watch(syncRemoteProvider);
    if (remote == null || ref.read(repositoryProvider).sync == null) return const SyncStatus();
    ref.onDispose(() {
      _timer?.cancel();
      _debounce?.cancel();
      _connectivity?.cancel();
      _auth?.cancel();
      _live?.cancel();
      _liveDebounce?.cancel();
    });
    Future.microtask(_start);
    return SyncStatus(
      configured: true,
      email: remote.email,
      linked: _store?.linkedBusinessId != null,
      role: _store?.role,
    );
  }

  void _start() {
    final remote = _remote;
    if (remote == null) return;
    _auth = remote.authChanges.listen((_) {
      if (remote.email != state.email) {
        state = remote.email == null ? state.copyWith(clearEmail: true) : state.copyWith(email: remote.email);
      }
    });
    if (ref.read(watchConnectivityProvider)) {
      final connectivity = Connectivity();
      connectivity.checkConnectivity().then(_onConnectivity);
      _connectivity = connectivity.onConnectivityChanged.listen(_onConnectivity);
    }
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => syncNow());
    syncNow();
    _refreshRole();
  }

  /// El dueño pudo cambiar o quitar a esta cuenta desde otro teléfono.
  Future<void> _refreshRole() async {
    final remote = _remote;
    final store = _store;
    if (remote == null || store == null || remote.userId == null || store.linkedBusinessId == null) return;
    try {
      final mine = await remote.myBusiness();
      if (!ref.mounted) return;
      if (mine == null || mine.id != store.linkedBusinessId) {
        state = state.copyWith(problem: 'Tu cuenta ya no pertenece a este negocio. Pregúntale al dueño.');
      } else if (mine.role != store.role) {
        await _setRole(mine.role);
      }
    } on SyncException {
      // Sin internet: se revisa la próxima vez que abra.
    }
  }

  Future<void> _setRole(MemberRole role) async {
    await _store!.setRole(role);
    state = state.copyWith(role: role);
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final hadNone = _noNetwork;
    _noNetwork = results.isNotEmpty && results.every((r) => r == ConnectivityResult.none);
    if (_noNetwork) {
      state = state.copyWith(online: false);
    } else if (hadNone) {
      syncNow();
    }
  }

  /// Un cambio local se guardó: sincroniza en unos segundos (agrupa ventas seguidas).
  /// Lo del restaurante ([urgent]) sale casi al momento.
  void nudge({bool urgent = false}) {
    if (!state.configured) return;
    _debounce?.cancel();
    _debounce = Timer(urgent ? const Duration(milliseconds: 300) : const Duration(seconds: 2), syncNow);
    _refreshPending();
  }

  Future<void> _refreshPending() async {
    final store = _store;
    if (store == null) return;
    final pending = await store.pendingCount();
    if (!ref.mounted) return; // la app se cerró mientras contaba
    if (pending != state.pending) state = state.copyWith(pending: pending);
  }

  /// Sube y baja ahora, si se puede. Nunca lanza errores: los deja en [SyncStatus.problem].
  Future<void> syncNow({Set<String>? only}) async {
    final remote = _remote;
    final store = _store;
    final businessId = store?.linkedBusinessId;
    if (remote == null || store == null || businessId == null || remote.userId == null || _noNetwork) {
      await _refreshPending();
      return;
    }
    _listenLive(remote, businessId);
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    state = state.copyWith(busy: true);
    try {
      await _push(remote, store, businessId);
      if (await store.pendingCount() == 0) await _pull(remote, store, businessId, only: only);
      state = state.copyWith(lastSync: DateTime.now(), clearProblem: true, online: true);
    } on SyncException catch (e) {
      state = switch (e.kind) {
        SyncFailure.network => state.copyWith(online: false, clearProblem: true),
        SyncFailure.auth => state.copyWith(problem: 'Tu sesión venció. Vuelve a entrar para respaldar.'),
        SyncFailure.rejected => state.copyWith(problem: 'Un cambio no se pudo subir: ${e.message}'),
      };
    } finally {
      _running = false;
      state = state.copyWith(busy: false, pending: await store.pendingCount());
      if (_again) {
        _again = false;
        unawaited(syncNow());
      }
    }
  }

  /// Escucha a los otros teléfonos del negocio: si alguien manda una comanda o la cocina
  /// avanza un platillo, se baja solo lo del restaurante casi al momento.
  void _listenLive(SyncRemote remote, String businessId) {
    if (_liveBusiness == businessId) return;
    _live?.cancel();
    _liveBusiness = businessId;
    _live = remote.live(businessId).listen((_) {
      _liveDebounce?.cancel();
      _liveDebounce = Timer(const Duration(milliseconds: 400), () => syncNow(only: restaurantTables));
    });
  }

  /// Sube la fila de pendientes en orden. Si una falla, se detiene ahí: lo que sigue
  /// puede depender de ella (un renglón necesita su venta).
  Future<void> _push(SyncRemote remote, SyncStore store, String businessId) async {
    while (true) {
      final batch = await store.pending();
      if (batch.isEmpty) return;
      for (final entry in batch) {
        final changes = (jsonDecode(entry.payload) as List).cast<Map<String, dynamic>>();
        try {
          for (final c in changes) {
            final rows = [for (final r in (c['rows'] as List)) Map<String, Object?>.from(r as Map)];
            await remote.upsert(c['table'] as String, businessId, rows);
          }
        } on SyncException catch (e) {
          if (e.kind == SyncFailure.rejected) await store.markFailed(entry.id, e.message);
          rethrow;
        }
        await store.markSent(entry.id);
      }
    }
  }

  /// Baja lo que cambió desde la última vez. Repasa los últimos minutos por si una
  /// escritura de otro teléfono llegó con un poco de retraso; aplicarla dos veces no daña.
  Future<bool> _pull(
    SyncRemote remote,
    SyncStore store,
    String businessId, {
    bool everything = false,
    Set<String>? only,
  }) async {
    var changed = false;
    for (final table in pullTables) {
      if (only != null && !only.contains(table)) continue;
      final cursor = everything ? null : await store.cursor(table);
      final since = cursor == null ? DateTime.utc(2000) : cursor.subtract(_overlap);
      var newest = cursor;
      var offset = 0;
      while (true) {
        final rows = await remote.changes(table, businessId, since, offset: offset, limit: _page);
        if (rows.isEmpty) break;
        await store.applyRemote(table, rows);
        for (final r in rows) {
          final at = DateTime.parse(r['synced_at']! as String);
          if (newest == null || at.isAfter(newest)) {
            newest = at;
            changed = true;
          }
        }
        offset += rows.length;
        if (rows.length < _page) break;
      }
      if (newest != null && newest != cursor) await store.setCursor(table, newest);
    }
    if (changed || everything) await ref.read(storeProvider.notifier).reloadFromStorage();
    return changed;
  }

  // ---------- Cuenta ----------

  Future<void> signIn(String email, String password) async {
    final remote = _remote!;
    await remote.signIn(email, password);
    state = state.copyWith(email: remote.email, clearProblem: true);
  }

  /// true si ya entró; false si falta confirmar el correo.
  Future<bool> signUp(String email, String password) async {
    final remote = _remote!;
    final signedIn = await remote.signUp(email, password);
    if (signedIn) state = state.copyWith(email: remote.email, clearProblem: true);
    return signedIn;
  }

  /// Abre un enlace de los correos de la cuenta. null si el enlace no es de la cuenta.
  Future<AuthLink?> openLink(Uri uri) async {
    final remote = _remote;
    if (remote == null || uri.scheme != AuthLinks.scheme || uri.host != AuthLinks.host) return null;
    final recovery = uri.path.contains('nueva-clave');
    final opened = await remote.openAuthLink(uri);
    if (!opened) return recovery ? AuthLink.otherDevice : AuthLink.confirmedSignIn;
    state = state.copyWith(email: remote.email, clearProblem: true);
    return recovery ? AuthLink.newPassword : AuthLink.confirmed;
  }

  Future<void> sendPasswordReset(String email) => _remote!.sendPasswordReset(email);

  Future<void> updatePassword(String password) => _remote!.updatePassword(password);

  /// Cierra la sesión. Los datos se quedan en el teléfono y lo pendiente sube al volver a entrar.
  Future<void> signOut() async {
    await _remote!.signOut();
    state = state.copyWith(clearEmail: true, clearProblem: true);
  }

  /// Enlaza este teléfono con la cuenta que inició sesión.
  Future<LinkOutcome> ensureLinked() async {
    final remote = _remote!;
    final store = _store!;
    final notifier = ref.read(storeProvider.notifier);
    await notifier.flush();
    final local = ref.read(storeProvider);
    final mine = await remote.myBusiness();

    if (mine == null) {
      if (!local.hasBusiness || local.isDemo) return const LinkOutcome(LinkResult.needsBusiness);
      await remote.createBusiness(id: local.businessId, name: local.businessName);
      await store.link(local.businessId, uploadAll: local);
      await _setRole(MemberRole.owner);
      state = state.copyWith(linked: true);
      await syncNow();
      return const LinkOutcome(LinkResult.uploaded);
    }

    if (local.hasBusiness && !local.isDemo && local.businessId == mine.id) {
      if (store.linkedBusinessId != mine.id) await store.link(mine.id);
      await _setRole(mine.role);
      state = state.copyWith(linked: true);
      await syncNow();
      return LinkOutcome(LinkResult.synced, remoteId: mine.id, remoteName: mine.name);
    }

    if (!local.hasBusiness || local.isDemo) {
      await downloadBusiness(mine.id, mine.name);
      return LinkOutcome(LinkResult.downloaded, remoteId: mine.id, remoteName: mine.name);
    }
    return LinkOutcome(LinkResult.conflict, remoteId: mine.id, remoteName: mine.name);
  }

  // ---------- Equipo ----------

  /// Código de invitación que se escribió antes de confirmar el correo; se usa al volver.
  String? pendingInvite;

  /// Se une al negocio de un código de invitación y lo baja a este teléfono.
  Future<LinkOutcome> joinWithCode(String code) async {
    await _remote!.acceptInvite(code);
    pendingInvite = null;
    return ensureLinked();
  }

  String? get myUserId => _remote?.userId;

  String get _business => _store!.linkedBusinessId!;

  Future<String> createInvite(MemberRole role, String name) => _remote!.createInvite(_business, role, name);
  Future<List<TeamMember>> members() => _remote!.members(_business);
  Future<List<TeamInvite>> invites() => _remote!.invites(_business);
  Future<void> revokeInvite(String id) => _remote!.revokeInvite(id);
  Future<void> removeMember(String id) => _remote!.removeMember(id);

  /// Borra lo de este teléfono y baja el negocio de la cuenta.
  Future<void> downloadBusiness(String businessId, String name) async {
    final remote = _remote!;
    final store = _store!;
    await ref.read(storeProvider.notifier).flush();
    await store.prepareDownload(businessId, name);
    state = state.copyWith(linked: true, busy: true);
    try {
      await _pull(remote, store, businessId, everything: true);
      _listenLive(remote, businessId);
      state = state.copyWith(lastSync: DateTime.now(), clearProblem: true);
    } finally {
      state = state.copyWith(busy: false);
    }
    // El rol se borró junto con lo demás; se vuelve a pedir.
    await _refreshRole();
  }
}

final syncProvider = NotifierProvider<SyncController, SyncStatus>(SyncController.new);

/// Qué puede hacer quien usa este teléfono, según su rol en el negocio.
final permissionsProvider = Provider<Permissions>((ref) => Permissions(ref.watch(syncProvider.select((s) => s.role))));
