import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/store.dart';
import 'theme/theme.dart';
import 'ui/onboarding/welcome_screen.dart';
import 'ui/shell/home_shell.dart';
import 'ui/splash/splash_screen.dart';

class GavilanApp extends StatefulWidget {
  const GavilanApp({super.key, this.showSplash = true});

  /// Las pruebas lo apagan para ir directo a la caja.
  final bool showSplash;

  @override
  State<GavilanApp> createState() => _GavilanAppState();
}

class _GavilanAppState extends State<GavilanApp> {
  late bool _splash = widget.showSplash;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gavilán',
      debugShowCheckedModeBanner: false,
      theme: buildGavilanTheme(),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _splash
            ? SplashScreen(key: const ValueKey('splash'), onDone: () => setState(() => _splash = false))
            : const _Root(key: ValueKey('root')),
      ),
    );
  }
}

/// Sin negocio guardado: bienvenida. Con negocio: la caja.
class _Root extends ConsumerWidget {
  const _Root({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasBusiness = ref.watch(storeProvider.select((s) => s.hasBusiness));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: hasBusiness ? const HomeShell(key: ValueKey('home')) : const WelcomeScreen(key: ValueKey('welcome')),
    );
  }
}
