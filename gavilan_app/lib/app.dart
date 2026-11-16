import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/sync_remote.dart';
import 'state/profiles.dart';
import 'state/store.dart';
import 'state/sync.dart';
import 'theme/colors.dart';
import 'theme/theme.dart';
import 'ui/account/auth_link_listener.dart';
import 'ui/account/business_switcher.dart';
import 'ui/onboarding/welcome_screen.dart';
import 'ui/shell/home_shell.dart';
import 'ui/splash/splash_screen.dart';
import 'ui/widgets/buttons.dart';

class GavilanApp extends StatefulWidget {
  const GavilanApp({super.key, this.showSplash = true});

  /// Las pruebas lo apagan para ir directo a la caja.
  final bool showSplash;

  @override
  State<GavilanApp> createState() => _GavilanAppState();
}

class _GavilanAppState extends State<GavilanApp> {
  late bool _splash = widget.showSplash;
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return AuthLinkListener(
      navigatorKey: _navigator,
      child: MaterialApp(
        navigatorKey: _navigator,
        title: 'Gavilán',
        debugShowCheckedModeBanner: false,
        theme: buildGavilanTheme(),
        // Español de México en fechas, diálogos y textos internos de Flutter.
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: _splash
              ? SplashScreen(key: const ValueKey('splash'), onDone: () => setState(() => _splash = false))
              : const _Root(key: ValueKey('root')),
        ),
      ),
    );
  }
}

/// Sin negocio guardado: bienvenida (o se baja de la nube, si se abrió uno de la cuenta). Con negocio: la caja.
class _Root extends ConsumerWidget {
  const _Root({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La lista de "Mis negocios" sigue el nombre, el id y el puesto del negocio abierto.
    final switcher = ref.watch(businessSwitcherProvider);
    if (switcher != null) {
      ref.listen(storeProvider.select((s) => (s.hasBusiness, s.businessId, s.businessName)), (_, v) {
        if (v.$1) switcher.updateActive(businessId: v.$2, name: v.$3);
      });
      ref.listen(syncProvider.select((s) => s.role), (_, role) {
        if (role != null) switcher.updateActive(role: role.name);
      });
    }
    final hasBusiness = ref.watch(storeProvider.select((s) => s.hasBusiness));
    final pending = ref.watch(pendingDownloadProvider);
    if (switcher != null && hasBusiness) {
      // Al abrir, también lo de ahora (solo escribe si cambió algo).
      final store = ref.read(storeProvider);
      final role = ref.read(syncProvider).role;
      Future.microtask(
        () => switcher.updateActive(businessId: store.businessId, name: store.businessName, role: role?.name),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: hasBusiness
          ? const HomeShell(key: ValueKey('home'))
          : pending != null
          ? _Downloading(key: const ValueKey('bajando'), id: pending.id, name: pending.name)
          : const WelcomeScreen(key: ValueKey('welcome')),
    );
  }
}

/// Un negocio de la cuenta que se abrió por primera vez en este teléfono: se baja de la nube.
class _Downloading extends ConsumerStatefulWidget {
  const _Downloading({super.key, required this.id, required this.name});

  final String id;
  final String name;

  @override
  ConsumerState<_Downloading> createState() => _DownloadingState();
}

class _DownloadingState extends ConsumerState<_Downloading> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _download());
  }

  Future<void> _download() async {
    setState(() => _error = null);
    final sync = ref.read(syncProvider);
    if (!sync.configured || !sync.signedIn) {
      setState(() => _error = 'Entra con tu cuenta para bajar este negocio.');
      return;
    }
    try {
      await ref.read(syncProvider.notifier).downloadBusiness(widget.id, widget.name);
    } on SyncException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error == null) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                  Text(
                    'Bajando ${widget.name}…',
                    textAlign: TextAlign.center,
                    style: GText.sans(size: 17, weight: FontWeight.w800),
                  ),
                ] else ...[
                  const Icon(Icons.cloud_off_rounded, size: 40, color: GColors.tintaTenue),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: GText.sans(size: 15, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  GButton(label: 'Intentar otra vez', icon: Icons.refresh_rounded, onPressed: _download),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => showBusinessSwitcher(context), child: const Text('Mis negocios')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
