import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/share.dart';
import '../../data/sync_remote.dart';
import '../../domain/team.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../account/account_screen.dart';
import '../modules/module_widgets.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

/// Equipo del negocio: quién usa la app y códigos para invitar a alguien más.
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  List<TeamMember>? _members;
  List<TeamInvite> _invites = const [];
  String? _error;

  SyncController get _sync => ref.read(syncProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final sync = ref.read(syncProvider);
    if (!sync.signedIn || !sync.linked) return;
    try {
      final members = await _sync.members();
      final invites = await _sync.invites();
      if (mounted) {
        setState(() {
          _members = members;
          _invites = invites;
          _error = null;
        });
      }
    } on SyncException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _invite() async {
    final created = await showGSheet<({String code, String name, MemberRole role})>(
      context,
      (_) => _InviteSheet(canInviteAdmins: ref.read(permissionsProvider).inviteAdmins),
    );
    if (created == null || !mounted) return;
    await _load();
    if (mounted) await _showCode(created.code, created.name, created.role);
  }

  Future<void> _showCode(String code, String name, MemberRole role) {
    final business = ref.read(storeProvider).businessName;
    final pretty = formatInviteCode(code);
    final message =
        'Hola${name.isEmpty ? '' : ' $name'}, te invito a usar Gavilán en $business como ${role.label.toLowerCase()}.\n\n'
        '1. Instala Gavilán en tu celular.\n'
        '2. Toca "Me invitaron a un negocio".\n'
        '3. Crea tu cuenta y escribe este código: *$pretty*\n\n'
        'El código sirve una sola vez y vence en 7 días.';
    return showGSheet<void>(
      context,
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader('Código para ${name.isEmpty ? role.label.toLowerCase() : name}', caption: role.label),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: GColors.superficie,
              border: Border.all(color: GColors.linea, width: 1.5),
              borderRadius: BorderRadius.circular(GShape.radiusSmall),
            ),
            child: SelectableText(
              pretty,
              textAlign: TextAlign.center,
              style: GText.figures(size: 30, weight: FontWeight.w700).copyWith(letterSpacing: 3),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sirve una sola vez y vence en 7 días. Quien lo use entra con su propia cuenta.',
            style: GText.muted(size: 13),
          ),
          const SizedBox(height: 14),
          GButton(
            label: 'Mandar por WhatsApp',
            icon: Icons.send_outlined,
            kind: GButtonKind.money,
            expand: true,
            big: true,
            onPressed: () => shareText(ctx, message),
          ),
          const SizedBox(height: 8),
          GButton(
            label: 'Copiar código',
            icon: Icons.copy_outlined,
            kind: GButtonKind.outline,
            expand: true,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: pretty));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Código copiado')));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _remove(TeamMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Quitar a ${m.name ?? m.role.label.toLowerCase()}?'),
        content: Text(
          'Ya no podrá ver ni respaldar las ventas del negocio. Lo que ya vendió se queda.',
          style: GText.sans(size: 14, weight: FontWeight.w400),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
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
    await _run(() => _sync.removeMember(m.id));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } on SyncException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncProvider);
    final can = ref.watch(permissionsProvider);
    final me = _sync.myUserId;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Equipo y roles', style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: !sync.signedIn || !sync.linked
            ? _NeedsAccount(onDone: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text(
                        'Cada quien entra con su propia cuenta. Los cajeros venden, cobran fiados y hacen el corte; '
                        'el catálogo y el equipo solo los cambian el dueño y los administradores.',
                        style: GText.muted(size: 13),
                      ),
                    ),
                    if (can.manageTeam)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: GButton(
                          label: 'Invitar a alguien',
                          icon: Icons.person_add_alt_1_outlined,
                          expand: true,
                          onPressed: _invite,
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(_error!, style: GText.sans(size: 13.5, color: GColors.rojo)),
                      ),
                    _SectionLabel('Quiénes usan la app'),
                    if (_members == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator(color: GColors.marca)),
                      )
                    else
                      for (final m in _members!)
                        _MemberTile(
                          member: m,
                          isMe: m.userId == me,
                          onRemove: can.manageTeam && m.role != MemberRole.owner && m.userId != me
                              ? () => _remove(m)
                              : null,
                        ),
                    if (_invites.isNotEmpty) ...[
                      _SectionLabel('Códigos sin usar'),
                      for (final i in _invites)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          leading: const Icon(Icons.vpn_key_outlined, color: GColors.cafe),
                          title: Text(i.prettyCode, style: GText.figures(size: 15, weight: FontWeight.w700)),
                          subtitle: Text(
                            '${i.name ?? i.role.label} · ${i.role.label} · vence ${dayLabel(i.expiresAt)}',
                            style: GText.muted(),
                          ),
                          onTap: () => _showCode(i.code, i.name ?? '', i.role),
                          trailing: IconButton(
                            tooltip: 'Cancelar código',
                            icon: const Icon(Icons.close, color: GColors.tintaSuave),
                            onPressed: () => _run(() => _sync.revokeInvite(i.id)),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
    child: Text(text, style: GText.sans(size: 15, weight: FontWeight.w800)),
  );
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.isMe, this.onRemove});

  final TeamMember member;
  final bool isMe;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final name = isMe ? 'Tú' : (member.name ?? (member.role == MemberRole.owner ? 'Dueño' : 'Sin nombre'));
    final color = switch (member.role) {
      MemberRole.owner => GColors.marca,
      MemberRole.admin => GColors.cenote,
      _ => GColors.cafe,
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: CircleAvatar(
        backgroundColor: color,
        foregroundColor: GColors.fondo,
        child: Text(
          name.characters.first.toUpperCase(),
          style: GText.sans(weight: FontWeight.w800, color: GColors.fondo),
        ),
      ),
      title: Text(name, style: GText.sans(size: 15, weight: FontWeight.w800)),
      subtitle: Text(member.role.label, style: GText.muted()),
      trailing: onRemove == null
          ? null
          : IconButton(
              tooltip: 'Quitar del equipo',
              icon: const Icon(Icons.person_remove_outlined, color: GColors.rojo),
              onPressed: onRemove,
            ),
    );
  }
}

/// El equipo vive en la nube: sin cuenta no hay a quién invitar.
class _NeedsAccount extends StatelessWidget {
  const _NeedsAccount({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const EmptyInvite(
          title: 'Primero respalda tu negocio',
          body: 'Para invitar cajeros, tu negocio tiene que estar en la nube. Entra o crea tu cuenta y vuelve aquí.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GButton(
            label: 'Entrar o crear cuenta',
            expand: true,
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen()));
              onDone();
            },
          ),
        ),
      ],
    );
  }
}

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({required this.canInviteAdmins});

  final bool canInviteAdmins;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _name = TextEditingController();
  MemberRole _role = MemberRole.cashier;
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final code = await ref.read(syncProvider.notifier).createInvite(_role, _name.text.trim());
      if (mounted) Navigator.of(context).pop((code: code, name: _name.text.trim(), role: _role));
    } on SyncException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = [
      MemberRole.cashier,
      MemberRole.waiter,
      MemberRole.kitchen,
      if (widget.canInviteAdmins) MemberRole.admin,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('Invitar a alguien'),
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: '¿Cómo se llama?', hintText: 'Juan'),
        ),
        const SizedBox(height: 12),
        // Dos por renglón: "Administrador" no cabe en cuatro columnas.
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in roles)
                SizedBox(
                  width: (box.maxWidth - 8) / 2,
                  child: GChip(label: r.label, selected: _role == r, onTap: () => setState(() => _role = r)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(switch (_role) {
          MemberRole.admin => 'Un administrador hace todo lo que tú, menos invitar o quitar administradores.',
          MemberRole.waiter => 'Un mesero abre cuentas en las mesas y manda comandas a cocina. No cobra.',
          MemberRole.kitchen => 'Cocina ve las comandas al instante y avisa cuando un platillo está listo.',
          _ => 'Un cajero vende, cobra fiados y apartados y hace el corte. No cambia precios ni productos.',
        }, style: GText.muted(size: 13)),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: GText.sans(size: 13.5, color: GColors.rojo)),
        ],
        const SizedBox(height: 14),
        GButton(
          label: _working ? 'Un momento…' : 'Crear código',
          expand: true,
          big: true,
          onPressed: _working ? null : _create,
        ),
      ],
    );
  }
}
