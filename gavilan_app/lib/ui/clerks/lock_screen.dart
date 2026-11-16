import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/clerk.dart';
import '../../domain/team.dart';
import '../../state/clerk_session.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import 'clerks_screen.dart';
import 'pin_pad.dart';

/// "¿Quién atiende?": se elige el nombre y se pone el PIN. Tapa todo lo demás hasta que alguien entra.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String? _selected;
  String? _error;
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Mientras está bloqueado por intentos, se redibuja cada segundo para la cuenta regresiva.
  void _watchBlock() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      final left = ref.read(clerkSessionProvider.notifier).secondsBlocked();
      setState(() {});
      if (left == 0) {
        t.cancel();
        setState(() => _error = null);
      }
    });
  }

  bool _try(Clerk clerk, String pin) {
    final notifier = ref.read(clerkSessionProvider.notifier);
    switch (notifier.unlock(clerk, pin)) {
      case UnlockResult.ok:
        Navigator.of(context).pop();
        return true;
      case UnlockResult.wrongPin:
        final left = ClerkSessionNotifier.maxFailures - ref.read(clerkSessionProvider).failures;
        setState(
          () =>
              _error = left == 1 ? 'PIN equivocado. Te queda 1 intento.' : 'PIN equivocado. Te quedan $left intentos.',
        );
        return false;
      case UnlockResult.blocked:
        setState(() => _error = 'Demasiados intentos.');
        _watchBlock();
        return false;
    }
  }

  Future<void> _forgot(List<Clerk> clerks) async {
    final sync = ref.read(syncProvider);
    final owner = clerks.where((c) => c.role == ClerkRole.dueno).firstOrNull;
    final canRecover =
        owner != null &&
        sync.signedIn &&
        sync.email != null &&
        (sync.role == null || sync.role == MemberRole.owner || sync.role == MemberRole.admin);
    if (!canRecover) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Se te olvidó el PIN?'),
          content: const Text(
            'Si eres cajero o encargado, el dueño te pone uno nuevo en Más › Personas del mostrador.\n\n'
            'Si eres el dueño, entra con la cuenta del negocio para recuperarlo. Este aparato no tiene una '
            'cuenta de dueño abierta.',
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Entendido'))],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _RecoverDialog(email: sync.email!),
    );
    if (ok != true || !mounted) return;
    ref.read(clerkSessionProvider.notifier).enterAs(owner.id);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    nav.pop();
    nav.push(MaterialPageRoute<void>(builder: (_) => const ClerksScreen()));
    messenger.showSnackBar(SnackBar(content: Text('Entraste como ${owner.name}. Ponte un PIN nuevo aquí.')));
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final session = ref.watch(clerkSessionProvider);
    final clerks = store.clerks;
    final selectedId =
        _selected ??
        (clerks.any((c) => c.id == session.lastId) ? session.lastId : (clerks.length == 1 ? clerks.first.id : null));
    final selected = clerks.where((c) => c.id == selectedId).firstOrNull;
    final blockedFor = ref.read(clerkSessionProvider.notifier).secondsBlocked();
    if (blockedFor > 0 && (_tick == null || !_tick!.isActive)) _watchBlock();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: GColors.fondo,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    Image.asset('assets/hawk/gavilan.png', width: 58, semanticLabel: 'Gavilán'),
                    const SizedBox(height: 8),
                    Text(store.businessName, style: GText.muted(size: 14)),
                    const SizedBox(height: 2),
                    Semantics(
                      header: true,
                      child: Text('¿Quién atiende?', style: GText.title(), textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final c in clerks)
                          _ClerkChip(
                            clerk: c,
                            selected: c.id == selectedId,
                            onTap: () => setState(() {
                              _selected = c.id;
                              if (blockedFor == 0) _error = null;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    if (selected == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Text('Toca tu nombre', style: GText.muted(size: 15)),
                      )
                    else ...[
                      Text('PIN de ${selected.name}', style: GText.sans(size: 15, weight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      PinPad(
                        key: ValueKey(selected.id),
                        enabled: blockedFor == 0,
                        onComplete: (pin) => _try(selected, pin),
                      ),
                    ],
                    SizedBox(
                      height: 40,
                      child: Center(
                        child: Text(
                          blockedFor > 0 ? 'Demasiados intentos. Espera $blockedFor s.' : (_error ?? ''),
                          textAlign: TextAlign.center,
                          style: GText.sans(size: 13.5, weight: FontWeight.w700, color: GColors.rojo),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _forgot(clerks),
                      child: Text(
                        '¿Se te olvidó el PIN?',
                        style: GText.sans(size: 13.5, weight: FontWeight.w700, color: GColors.tintaSuave),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClerkChip extends StatelessWidget {
  const _ClerkChip({required this.clerk, required this.selected, required this.onTap});

  final Clerk clerk;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${clerk.name}, ${clerk.role.label}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 136,
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          decoration: BoxDecoration(
            color: selected ? GColors.cenoteSuave : GColors.superficie,
            borderRadius: BorderRadius.circular(GShape.radius),
            border: Border.all(color: selected ? GColors.cenote : GColors.linea, width: selected ? 2 : 1),
          ),
          child: Column(
            children: [
              ClerkAvatar(clerk: clerk, size: 40),
              const SizedBox(height: 6),
              Text(
                clerk.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GText.sans(size: 14, weight: FontWeight.w800),
              ),
              Text(clerk.role.label, style: GText.muted(size: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// El dueño vuelve a poner la contraseña de su cuenta para entrar sin PIN.
class _RecoverDialog extends ConsumerStatefulWidget {
  const _RecoverDialog({required this.email});

  final String email;

  @override
  ConsumerState<_RecoverDialog> createState() => _RecoverDialogState();
}

class _RecoverDialogState extends ConsumerState<_RecoverDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(syncProvider.notifier).signIn(widget.email, _password.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'No se pudo entrar. Revisa la contraseña y el internet.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Entra con tu cuenta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pon la contraseña de ${widget.email} y luego te pones un PIN nuevo.', style: GText.muted(size: 13.5)),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            enabled: !_busy,
            decoration: InputDecoration(labelText: 'Contraseña', errorText: _error),
            onSubmitted: (_) => _go(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        FilledButton(onPressed: _busy ? null : _go, child: const Text('Entrar')),
      ],
    );
  }
}

/// Algo que la persona que atiende no puede hacer (cancelar una venta, por ejemplo): si se usan PIN,
/// el dueño o un encargado lo autoriza con su PIN sin cambiar quién atiende. true si se puede seguir.
Future<bool> allowOrAskPin(
  BuildContext context,
  WidgetRef ref, {
  required bool Function(Permissions can) allowed,
  required String action,
}) async {
  if (allowed(ref.read(permissionsProvider))) return true;
  final store = ref.read(storeProvider);
  if (!store.usesPins) return false;
  // Quién puede autorizarlo: lo que podría hacer esa persona si estuviera atendiendo.
  final role = ref.read(syncProvider).role;
  final managers = [
    for (final c in store.clerks)
      if (allowed(Permissions(role, clerk: c.role))) c,
  ];
  if (managers.isEmpty) return false;
  final ok = await showGSheet<bool>(context, (_) => _AuthorizeSheet(managers: managers, action: action));
  return ok ?? false;
}

class _AuthorizeSheet extends ConsumerStatefulWidget {
  const _AuthorizeSheet({required this.managers, required this.action});

  final List<Clerk> managers;
  final String action;

  @override
  ConsumerState<_AuthorizeSheet> createState() => _AuthorizeSheetState();
}

class _AuthorizeSheetState extends ConsumerState<_AuthorizeSheet> {
  late String _selected = widget.managers.first.id;
  String? _error;

  bool _try(String pin) {
    final clerk = widget.managers.firstWhere((c) => c.id == _selected);
    switch (ref.read(clerkSessionProvider.notifier).check(clerk, pin)) {
      case UnlockResult.ok:
        Navigator.of(context).pop(true);
        return true;
      case UnlockResult.wrongPin:
        setState(() => _error = 'PIN equivocado');
        return false;
      case UnlockResult.blocked:
        setState(() => _error = 'Demasiados intentos. Espera un minuto.');
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(widget.action, caption: 'Hace falta el PIN del dueño o un encargado'),
        const SizedBox(height: 14),
        if (widget.managers.length > 1)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in widget.managers)
                _ClerkChip(
                  clerk: c,
                  selected: c.id == _selected,
                  onTap: () => setState(() {
                    _selected = c.id;
                    _error = null;
                  }),
                ),
            ],
          )
        else
          Text('PIN de ${widget.managers.first.name}', style: GText.sans(size: 15, weight: FontWeight.w700)),
        const SizedBox(height: 18),
        PinPad(key: ValueKey(_selected), onComplete: _try),
        SizedBox(
          height: 30,
          child: Text(
            _error ?? '',
            style: GText.sans(size: 13.5, weight: FontWeight.w700, color: GColors.rojo),
          ),
        ),
      ],
    );
  }
}
