import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/sync_remote.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../account/account_screen.dart';
import '../widgets/buttons.dart';

/// Primer arranque: nombre del negocio, o probar con la tiendita de ejemplo.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _start() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el nombre de tu negocio');
      return;
    }
    ref.read(storeProvider.notifier).startBusiness(_name.text);
    // Con sesión iniciada, el negocio nuevo se da de alta también en la nube.
    final sync = ref.read(syncProvider);
    if (sync.configured && sync.signedIn) {
      final messenger = ScaffoldMessenger.of(context);
      final notifier = ref.read(syncProvider.notifier);
      unawaited(() async {
        try {
          await notifier.ensureLinked();
        } on SyncException catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('Todavía no se respaldó: ${e.message}')));
        }
      }());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: SvgPicture.asset('assets/hawk/gavilan.svg', width: 150, semanticsLabel: 'Gavilán')),
                  const SizedBox(height: 18),
                  Semantics(header: true, child: Text('Bienvenido a Gavilán', style: GText.title())),
                  const SizedBox(height: 6),
                  Text(
                    'Tu caja, tus fiados y tu inventario en el celular. Funciona sin internet.',
                    style: GText.sans(size: 14, weight: FontWeight.w400, color: GColors.tintaSuave),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _start(),
                    onChanged: (_) => setState(() => _error = null),
                    style: GText.sans(size: 17, weight: FontWeight.w800),
                    decoration: InputDecoration(
                      labelText: '¿Cómo se llama tu negocio?',
                      hintText: 'Abarrotes La Esperanza',
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GButton(label: 'Empezar', expand: true, big: true, onPressed: _start),
                  if (ref.watch(syncProvider).configured) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
                      child: Text(
                        ref.watch(syncProvider).signedIn
                            ? 'Ver mi cuenta'
                            : '¿Ya tienes cuenta? Entra y baja tu negocio',
                        style: GText.sans(size: 14, weight: FontWeight.w800, color: GColors.oxido),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  const Divider(color: GColors.linea),
                  const SizedBox(height: 10),
                  Text('¿Solo quieres conocerla?', style: GText.sans(size: 13)),
                  const SizedBox(height: 8),
                  GButton(
                    label: 'Probar con una tiendita de ejemplo',
                    kind: GButtonKind.outline,
                    expand: true,
                    onPressed: () => ref.read(storeProvider.notifier).loadDemo(),
                  ),
                  const SizedBox(height: 6),
                  Text('Después puedes borrar el ejemplo desde Más y empezar con tu negocio.', style: GText.muted()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
