import 'package:flutter/material.dart';

import 'theme/theme.dart';
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
            : const HomeShell(key: ValueKey('home')),
      ),
    );
  }
}
