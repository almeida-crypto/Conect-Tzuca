import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync_remote.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import 'account_screen.dart';

/// Se abre desde el correo de "olvidé mi contraseña", ya con la sesión abierta.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (_password.text != _repeat.text) {
      setState(() => _error = 'Las dos contraseñas no son iguales');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await ref.read(syncProvider.notifier).updatePassword(_password.text);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const AccountScreen(notice: 'Listo: tu contraseña cambió.', autoLink: true),
        ),
      );
    } on SyncException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(syncProvider.select((s) => s.email));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Contraseña nueva', style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              email == null ? 'Elige tu contraseña nueva.' : 'Elige la contraseña nueva de $email.',
              style: GText.sans(size: 14, weight: FontWeight.w400, color: GColors.tintaSuave),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _password,
              obscureText: true,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(labelText: 'Contraseña nueva', helperText: 'Al menos 6 caracteres'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _repeat,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _working ? null : _save(),
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(labelText: 'Repítela'),
            ),
            const SizedBox(height: 16),
            GButton(
              label: _working ? 'Un momento…' : 'Guardar contraseña',
              expand: true,
              big: true,
              onPressed: _working ? null : _save,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: GText.sans(size: 13.5, color: GColors.rojo)),
            ],
          ],
        ),
      ),
    );
  }
}
