import '../../core/limits.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync_remote.dart';
import '../../domain/business.dart';
import '../../state/profiles.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../account/account_screen.dart';
import 'business_type_screen.dart';
import '../account/business_switcher.dart';
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

  Future<void> _start() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el nombre de tu negocio');
      return;
    }
    // Segundo paso: qué tipo de negocio es, para mostrar solo lo que va a usar.
    final type = await Navigator.of(context)
        .push<BusinessType>(MaterialPageRoute(builder: (_) => const BusinessTypeScreen()));
    if (type == null || !mounted) return;
    ref.read(storeProvider.notifier).startBusiness(_name.text, type: type);
    // Con sesión iniciada, el negocio nuevo se da de alta también en la nube.
    final sync = ref.read(syncProvider);
    if (sync.configured && sync.signedIn) {
      final messenger = ScaffoldMessenger.of(context);
      final notifier = ref.read(syncProvider.notifier);
      unawaited(() async {
        try {
          // Recién creado a propósito: si la cuenta ya tiene otros negocios, este se sube como uno más.
          await notifier.ensureLinked(createIfNew: true);
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
                  Center(child: Image.asset('assets/hawk/gavilan.png', width: 180, semanticLabel: 'Gavilán')),
                  const SizedBox(height: 18),
                  Semantics(header: true, child: Text('Bienvenido a Gavilán', style: GText.title())),
                  const SizedBox(height: 6),
                  Text(
                    'Tu caja, tus fiados y tu inventario en el celular o la computadora. Funciona sin internet.',
                    style: GText.sans(size: 14, weight: FontWeight.w400, color: GColors.tintaSuave),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _name,
                    inputFormatters: [maxChars(Limits.maxPersonLength)],
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
                  // Abrió "Crear otro negocio" y se arrepintió: puede regresar a los que ya tiene.
                  if ((ref.watch(businessSwitcherProvider)?.profiles.length ?? 0) > 1)
                    TextButton.icon(
                      onPressed: () => showBusinessSwitcher(context),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Volver a mis negocios'),
                    ),
                  if (ref.watch(syncProvider).configured) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
                      child: Text(
                        ref.watch(syncProvider).signedIn
                            ? 'Ver mi cuenta'
                            : '¿Ya tienes cuenta? Entra y baja tu negocio',
                        style: GText.sans(size: 14, weight: FontWeight.w800, color: GColors.marca),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => const AccountScreen(join: true))),
                      child: Text(
                        'Me invitaron a un negocio',
                        style: GText.sans(size: 14, weight: FontWeight.w800, color: GColors.cenote),
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
