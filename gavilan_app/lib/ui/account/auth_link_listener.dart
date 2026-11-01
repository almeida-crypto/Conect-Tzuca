import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync_remote.dart';
import '../../state/sync.dart';
import 'account_screen.dart';
import 'new_password_screen.dart';

/// Recibe los enlaces de los correos de la cuenta (`mx.gavilan.gavilan://auth/...`)
/// y abre la pantalla que toca: confirmar la cuenta o elegir una contraseña nueva.
class AuthLinkListener extends ConsumerStatefulWidget {
  const AuthLinkListener({super.key, required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<AuthLinkListener> createState() => _AuthLinkListenerState();
}

class _AuthLinkListenerState extends ConsumerState<AuthLinkListener> {
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    // Sin respaldo configurado (navegador o pruebas) no hay cuenta que abrir.
    if (kIsWeb || ref.read(syncRemoteProvider) == null) return;
    // Incluye el enlace con el que se abrió la app.
    _links = AppLinks().uriLinkStream.listen(_open);
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  Future<void> _open(Uri uri) async {
    try {
      final kind = await ref.read(syncProvider.notifier).openLink(uri);
      final nav = widget.navigatorKey.currentState;
      if (kind == null || nav == null) return;
      final Widget screen = switch (kind) {
        AuthLink.confirmed => const AccountScreen(notice: 'Tu correo quedó confirmado.', autoLink: true),
        AuthLink.confirmedSignIn => const AccountScreen(
          notice: 'Tu correo quedó confirmado. Entra con tu correo y tu contraseña.',
        ),
        AuthLink.newPassword => const NewPasswordScreen(),
        AuthLink.otherDevice => const AccountScreen(
          notice: 'Ese enlace se pidió desde otro celular. Escribe tu correo y toca "Olvidé mi contraseña" para recibir uno nuevo aquí.',
        ),
      };
      await nav.push(MaterialPageRoute<void>(builder: (_) => screen));
    } on SyncException catch (e) {
      final context = widget.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
