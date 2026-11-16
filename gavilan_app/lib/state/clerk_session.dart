import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/clerk.dart';
import 'store.dart';

/// Quién atiende ahora en este aparato. Vive en memoria: al abrir la app empieza bloqueada y pide PIN.
class ClerkSession {
  const ClerkSession({this.activeId, this.lastId, this.failures = 0, this.blockedUntil});

  final String? activeId;

  /// Quién atendía antes de bloquear (la pantalla del PIN lo deja elegido).
  final String? lastId;

  /// PIN equivocados seguidos.
  final int failures;

  /// Tras 5 errores se espera un minuto antes de volver a intentar.
  final DateTime? blockedUntil;

  bool get locked => activeId == null;
}

enum UnlockResult { ok, wrongPin, blocked }

class ClerkSessionNotifier extends Notifier<ClerkSession> {
  ClerkSessionNotifier({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const maxFailures = 5;
  static const blockFor = Duration(minutes: 1);

  @override
  ClerkSession build() => const ClerkSession();

  /// Revisa el PIN de [clerk] sin cambiar quién atiende (para que el dueño autorice algo).
  UnlockResult check(Clerk clerk, String pin) {
    final until = state.blockedUntil;
    if (until != null && _clock().isBefore(until)) return UnlockResult.blocked;
    if (clerk.checkPin(pin)) {
      state = ClerkSession(activeId: state.activeId, lastId: state.lastId);
      return UnlockResult.ok;
    }
    final failures = state.failures + 1;
    final block = failures >= maxFailures;
    state = ClerkSession(
      activeId: state.activeId,
      lastId: state.lastId,
      failures: block ? 0 : failures,
      blockedUntil: block ? _clock().add(blockFor) : null,
    );
    return block ? UnlockResult.blocked : UnlockResult.wrongPin;
  }

  /// Entra [clerk] con su [pin].
  UnlockResult unlock(Clerk clerk, String pin) {
    final result = check(clerk, pin);
    if (result == UnlockResult.ok) state = ClerkSession(activeId: clerk.id);
    return result;
  }

  /// Entra sin PIN: al activar los PIN, quien los activa (el dueño) queda atendiendo.
  void enterAs(String clerkId) => state = ClerkSession(activeId: clerkId);

  /// Bloquea: el siguiente pone su PIN.
  void lock() => state = ClerkSession(lastId: state.activeId ?? state.lastId, blockedUntil: state.blockedUntil);

  /// Segundos que faltan para volver a intentar (0 si ya se puede).
  int secondsBlocked() {
    final until = state.blockedUntil;
    if (until == null) return 0;
    final left = until.difference(_clock()).inSeconds;
    return left > 0 ? left : 0;
  }
}

final clerkSessionProvider = NotifierProvider<ClerkSessionNotifier, ClerkSession>(ClerkSessionNotifier.new);

/// La persona que atiende ahora (null si no se usan PIN o está bloqueado).
final activeClerkProvider = Provider<Clerk?>((ref) {
  final id = ref.watch(clerkSessionProvider).activeId;
  if (id == null) return null;
  return ref.watch(storeProvider.select((s) => s.clerks)).where((c) => c.id == id).firstOrNull;
});
