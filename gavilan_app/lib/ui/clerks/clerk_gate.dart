import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/clerk_session.dart';
import '../../state/store.dart';
import 'lock_screen.dart';

/// Cuando el negocio usa PIN: tapa la app con "¿Quién atiende?" mientras nadie ha entrado, bloquea con F4
/// y, si así se eligió, después de unos minutos sin tocar nada.
class ClerkGate extends ConsumerStatefulWidget {
  const ClerkGate({super.key, required this.child, DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  final Widget child;
  final DateTime Function() clock;

  @override
  ConsumerState<ClerkGate> createState() => _ClerkGateState();
}

class _ClerkGateState extends ConsumerState<ClerkGate> {
  Route<void>? _route;
  late DateTime _last = widget.clock();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _checkIdle());
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _timer?.cancel();
    super.dispose();
  }

  bool get _usesPins => ref.read(storeProvider).usesPins;
  bool get _locked => ref.read(clerkSessionProvider).locked;

  void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent) _last = widget.clock();
  }

  bool _onKey(KeyEvent e) {
    _last = widget.clock();
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.f4 && mounted && _usesPins && !_locked) {
      ref.read(clerkSessionProvider.notifier).lock();
      return true;
    }
    return false;
  }

  void _checkIdle() {
    if (!mounted || !_usesPins || _locked) return;
    final minutes = ref.read(storeProvider).lockMinutes;
    if (minutes == null) return;
    if (widget.clock().difference(_last) >= Duration(minutes: minutes)) {
      ref.read(clerkSessionProvider.notifier).lock();
    }
  }

  /// Muestra u oculta la pantalla del PIN según toque.
  void _sync() {
    if (!mounted) return;
    final mustLock = _usesPins && _locked;
    if (mustLock && _route == null) {
      final route = PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'quien-atiende'),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => const LockScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      );
      _route = route;
      Navigator.of(context).push(route).then((_) {
        if (_route == route) _route = null;
        _last = widget.clock();
        // Si se cerró sin que nadie entrara, se vuelve a pedir.
        WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
      });
    } else if (!mustLock && _route != null) {
      final route = _route!;
      _route = null;
      if (route.isActive) Navigator.of(context).removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(storeProvider.select((s) => s.usesPins), (_, _) => _scheduleSync());
    ref.listen(clerkSessionProvider.select((s) => s.locked), (_, locked) {
      if (!locked) _last = widget.clock();
      _scheduleSync();
    });
    return widget.child;
  }

  void _scheduleSync() => WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
}
