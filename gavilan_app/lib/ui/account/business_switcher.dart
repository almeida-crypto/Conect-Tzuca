import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profiles.dart';
import '../../data/sync_remote.dart';
import '../../domain/team.dart';
import '../../state/profiles.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

/// "Mis negocios": cambiar de negocio, crear otro o unirse a uno con un código.
/// Para quien es mesero en un restaurante y además tiene su propio negocio.
Future<void> showBusinessSwitcher(BuildContext context) => showGSheet<void>(context, (_) => const _SwitcherSheet());

class _SwitcherSheet extends ConsumerStatefulWidget {
  const _SwitcherSheet();

  @override
  ConsumerState<_SwitcherSheet> createState() => _SwitcherSheetState();
}

class _SwitcherSheetState extends ConsumerState<_SwitcherSheet> {
  List<({String id, String name, MemberRole role})> _cloud = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Negocios de la cuenta que todavía no están en este teléfono.
    ref.read(syncProvider.notifier).accountBusinesses().then((list) {
      if (mounted) setState(() => _cloud = list);
    });
  }

  Future<void> _go(Future<void> Function(BusinessSwitcher s) action) async {
    final switcher = ref.read(businessSwitcherProvider);
    if (switcher == null || _busy) return;
    setState(() => _busy = true);
    await ref.read(storeProvider.notifier).flush(); // nada se queda sin guardar al cambiar
    if (mounted) Navigator.of(context).pop();
    await action(switcher);
  }

  Future<void> _join() async {
    final sync = ref.read(syncProvider);
    if (!sync.signedIn) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Primero entra con tu cuenta en Más → Respaldo en la nube')));
      return;
    }
    final code = await showDialog<String>(context: context, builder: (_) => const _CodeDialog());
    if (code == null || code.trim().isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final outcome = await ref.read(syncProvider.notifier).joinWithCode(code);
      if (!mounted) return;
      if (outcome.result == LinkResult.joinedOther) {
        final id = outcome.remoteId!, name = outcome.remoteName!;
        await _go((s) => s.openCloudBusiness(id: id, name: name));
      } else {
        Navigator.of(context).pop();
      }
    } on SyncException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _remove(DeviceProfile p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Quitar ${p.name} de este teléfono?'),
        content: Text(
          'Se borran sus datos de este teléfono. Lo que está respaldado en la nube no se borra y puedes '
          'volver a abrirlo cuando entres con tu cuenta.',
          style: GText.sans(size: 14, weight: FontWeight.w400),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Quitar',
              style: GText.sans(size: 14, weight: FontWeight.w800, color: GColors.rojo),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(businessSwitcherProvider)?.remove(p.key);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final switcher = ref.watch(businessSwitcherProvider);
    final profiles = switcher?.profiles ?? const <DeviceProfile>[];
    final active = switcher?.activeKey;
    final here = {for (final p in profiles) p.businessId};
    final elsewhere = [
      for (final b in _cloud)
        if (!here.contains(b.id)) b,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('Mis negocios', caption: 'Cada uno guarda sus datos aparte'),
        for (final p in profiles)
          _Row(
            title: p.name,
            subtitle: _roleLabel(p.role),
            current: p.key == active,
            onTap: p.key == active ? null : () => _go((s) => s.switchTo(p.key)),
            onRemove: p.key == active ? null : () => _remove(p),
          ),
        for (final b in elsewhere)
          _Row(
            title: b.name,
            subtitle: '${_roleLabel(b.role.name)} · en tu cuenta, se baja al abrirlo',
            current: false,
            cloud: true,
            onTap: () => _go((s) => s.openCloudBusiness(id: b.id, name: b.name, role: b.role.name)),
          ),
        const SizedBox(height: 14),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          GButton(
            label: 'Unirme a un negocio con código',
            icon: Icons.group_add_outlined,
            kind: GButtonKind.outline,
            expand: true,
            onPressed: _join,
          ),
          const SizedBox(height: 8),
          GButton(
            label: 'Crear otro negocio',
            icon: Icons.add_business_outlined,
            kind: GButtonKind.outline,
            expand: true,
            onPressed: () => _go((s) => s.createNew()),
          ),
        ],
      ],
    );
  }
}

String _roleLabel(String? role) => switch (MemberRole.fromRemote(role)) {
  MemberRole.owner => 'Dueño',
  MemberRole.admin => 'Administrador',
  MemberRole.cashier => 'Cajero',
  MemberRole.waiter => 'Mesero',
  MemberRole.kitchen => 'Cocina',
  null => 'En este teléfono',
};

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.subtitle,
    required this.current,
    this.onTap,
    this.onRemove,
    this.cloud = false,
  });

  final String title;
  final String subtitle;
  final bool current;
  final bool cloud;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: current ? GColors.cenoteSuave : GColors.fondo,
        borderRadius: BorderRadius.circular(GShape.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(GShape.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                Avatar(title),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GText.sans(size: 15, weight: FontWeight.w800)),
                      Text(subtitle, style: GText.muted(size: 12.5)),
                    ],
                  ),
                ),
                if (current)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'Abierto',
                      style: GText.sans(size: 12.5, weight: FontWeight.w800, color: GColors.cenote),
                    ),
                  )
                else if (cloud)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.cloud_download_outlined, color: GColors.tintaSuave),
                  )
                else if (onRemove != null)
                  PopupMenuButton<String>(
                    tooltip: 'Opciones',
                    onSelected: (_) => onRemove!(),
                    itemBuilder: (_) => [const PopupMenuItem(value: 'quitar', child: Text('Quitar de este teléfono'))],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Código de invitación'),
      content: TextField(
        controller: _code,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(hintText: 'ABCD-EFGH', helperText: 'Te lo da el dueño del negocio'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.of(context).pop(_code.text), child: const Text('Unirme')),
      ],
    );
  }
}
