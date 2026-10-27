import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ticket_text.dart';
import '../../data/sync_remote.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';

/// Cuenta y respaldo en la nube. Entrar es opcional: sin cuenta todo funciona en el teléfono.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _working = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  SyncController get _sync => ref.read(syncProvider.notifier);

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@') || email.length < 5) {
      setState(() => _error = 'Escribe tu correo');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
      _info = null;
    });
    try {
      if (_creating) {
        final signedIn = await _sync.signUp(email, _password.text);
        if (!signedIn) {
          setState(
            () => _info =
                'Te mandamos un correo a $email. Ábrelo para confirmar tu cuenta y luego entra aquí con tu contraseña.',
          );
          _creating = false;
          return;
        }
      } else {
        await _sync.signIn(email, _password.text);
      }
      _password.clear();
      await _link();
    } on SyncException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Enlaza el teléfono con la cuenta y explica qué pasó.
  Future<void> _link() async {
    setState(() => _working = true);
    try {
      final outcome = await _sync.ensureLinked();
      if (!mounted) return;
      final store = ref.read(storeProvider);
      switch (outcome.result) {
        case LinkResult.uploaded:
          _done('Listo: ${store.businessName} quedó respaldado en la nube.');
        case LinkResult.synced:
          _done('Listo: este teléfono está al día con tu cuenta.');
        case LinkResult.downloaded:
          _done('Bajamos ${outcome.remoteName} a este teléfono.');
        case LinkResult.needsBusiness:
          setState(
            () => _info = store.isDemo
                ? 'La tiendita de ejemplo no se sube a la nube. Bórrala desde Más y empieza tu negocio: se respaldará solo.'
                : 'Tu cuenta todavía no tiene negocio. Escribe su nombre en la bienvenida para empezar.',
          );
        case LinkResult.conflict:
          await _askReplace(outcome);
      }
    } on SyncException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _done(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).maybePop();
  }

  Future<void> _askReplace(LinkOutcome outcome) async {
    final local = ref.read(storeProvider).businessName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hay dos negocios distintos'),
        content: Text(
          'Tu cuenta tiene "${outcome.remoteName}" y este teléfono tiene "$local". '
          '¿Quieres reemplazar lo de este teléfono con lo de tu cuenta? Lo de "$local" que no esté en la nube se pierde.',
          style: GText.sans(size: 14, weight: FontWeight.w400),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Dejarlo así')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Reemplazar',
              style: GText.sans(size: 14, weight: FontWeight.w800, color: GColors.rojo),
            ),
          ),
        ],
      ),
    );
    if (ok != true) {
      setState(() => _info = 'Este teléfono sigue sin respaldo. Puedes cerrar sesión o reemplazarlo cuando quieras.');
      return;
    }
    await _sync.downloadBusiness(outcome.remoteId!, outcome.remoteName!);
    if (mounted) _done('Bajamos ${outcome.remoteName} a este teléfono.');
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: Text(
          'Tus datos se quedan en este teléfono. Lo que falte por subir se sube cuando vuelvas a entrar.',
          style: GText.sans(size: 14, weight: FontWeight.w400),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _sync.signOut();
    } on SyncException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.papel,
        surfaceTintColor: Colors.transparent,
        title: Text('Cuenta y respaldo', style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (!sync.configured)
              Text(
                'El respaldo en la nube funciona en la app del teléfono. Aquí todo se guarda solo mientras la página está abierta.',
                style: GText.sans(size: 14, weight: FontWeight.w400),
              )
            else if (!sync.signedIn)
              ..._loginForm()
            else
              ..._accountView(sync),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: GText.sans(size: 13.5, color: GColors.rojo)),
            ],
            if (_info != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GColors.papelClaro,
                  border: Border.all(color: GColors.linea),
                ),
                child: Text(_info!, style: GText.sans(size: 13.5, weight: FontWeight.w400)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _loginForm() => [
    Text(
      'Con una cuenta, tus ventas, fiados y cortes se respaldan en la nube y puedes usarlos en otro teléfono. '
      'Sin cuenta, todo sigue funcionando en este teléfono.',
      style: GText.sans(size: 14, weight: FontWeight.w400, color: GColors.tintaSuave),
    ),
    const SizedBox(height: 18),
    TextField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() => _error = null),
      decoration: const InputDecoration(labelText: 'Correo', hintText: 'tunegocio@gmail.com'),
    ),
    const SizedBox(height: 10),
    TextField(
      controller: _password,
      obscureText: true,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _working ? null : _submit(),
      onChanged: (_) => setState(() => _error = null),
      decoration: InputDecoration(labelText: 'Contraseña', helperText: _creating ? 'Al menos 6 caracteres' : null),
    ),
    const SizedBox(height: 16),
    GButton(
      label: _working ? 'Un momento…' : (_creating ? 'Crear cuenta' : 'Entrar'),
      expand: true,
      big: true,
      onPressed: _working ? null : _submit,
    ),
    const SizedBox(height: 8),
    TextButton(
      onPressed: _working
          ? null
          : () => setState(() {
              _creating = !_creating;
              _error = null;
              _info = null;
            }),
      child: Text(
        _creating ? 'Ya tengo cuenta: entrar' : 'No tengo cuenta: crear una',
        style: GText.sans(size: 14, weight: FontWeight.w800, color: GColors.oxido),
      ),
    ),
  ];

  List<Widget> _accountView(SyncStatus sync) {
    final (state, color) = switch (sync) {
      SyncStatus(linked: false) => ('Este teléfono todavía no está enlazado', GColors.tintaSuave),
      SyncStatus(online: false) => ('Sin internet: se sube al volver la señal', GColors.ocre),
      SyncStatus(problem: final p?) => (p, GColors.rojo),
      SyncStatus(pending: final n) when n > 0 => ('Faltan $n cambios por subir', GColors.ocre),
      _ => ('Todo respaldado', GColors.monte),
    };
    return [
      Text('Entraste como', style: GText.muted(size: 13)),
      Text(sync.email!, style: GText.sans(size: 17, weight: FontWeight.w800)),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GColors.papelClaro,
          border: Border.all(color: GColors.linea),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(state, style: GText.sans(size: 14, weight: FontWeight.w800)),
                ),
              ],
            ),
            if (sync.lastSync != null) ...[
              const SizedBox(height: 6),
              Text('Último respaldo: ${dateTimeLabel(sync.lastSync!)}', style: GText.muted()),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (!sync.linked)
        GButton(
          label: _working ? 'Un momento…' : 'Enlazar este teléfono',
          expand: true,
          onPressed: _working ? null : _link,
        )
      else
        GButton(
          label: sync.busy ? 'Respaldando…' : 'Respaldar ahora',
          kind: GButtonKind.money,
          icon: Icons.cloud_upload_outlined,
          expand: true,
          onPressed: sync.busy ? null : () => _sync.syncNow(),
        ),
      const SizedBox(height: 10),
      GButton(label: 'Cerrar sesión', kind: GButtonKind.outline, expand: true, onPressed: _signOut),
    ];
  }
}
