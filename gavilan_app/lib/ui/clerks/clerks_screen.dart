import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/limits.dart';
import '../../domain/clerk.dart';
import '../../state/clerk_session.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import 'pin_pad.dart';

/// Minutos para bloquear solo (null = nunca).
const lockOptions = <int?>[null, 1, 3, 5, 10, 30];

String lockLabel(int? m) => m == null ? 'Nunca' : '$m min';

/// "Personas del mostrador": quién usa este aparato, con qué permisos y su PIN.
class ClerksScreen extends ConsumerWidget {
  const ClerksScreen({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final clerk = await showGSheet<Clerk>(context, (_) => const ClerkSheet(first: true));
    if (clerk == null) return;
    final store = ref.read(storeProvider.notifier);
    store.saveClerk(clerk);
    store.setLockMinutes(5);
    // Quien lo activa (el dueño) se queda atendiendo.
    ref.read(clerkSessionProvider.notifier).enterWithoutPin(clerk.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Listo. Atiende ${clerk.name}. Ahora agrega a quien te ayuda en la caja.')));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, [Clerk? clerk]) async {
    final saved = await showGSheet<Clerk>(context, (_) => ClerkSheet(clerk: clerk));
    if (saved != null) ref.read(storeProvider.notifier).saveClerk(saved);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Clerk clerk) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Quitar a ${clerk.name}?'),
        content: const Text('Ya no podrá entrar en este aparato. Sus ventas de antes se quedan a su nombre.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Quitar', style: TextStyle(color: GColors.rojo)),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(storeProvider.notifier).removeClerk(clerk.id);
  }

  Future<void> _disable(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Dejar de pedir PIN?'),
        content: const Text(
          'Se borran las personas y sus PIN de este aparato. Las ventas de antes se quedan con el nombre de '
          'quien atendió.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Dejar de pedir', style: TextStyle(color: GColors.rojo)),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(storeProvider.notifier).disablePins();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final active = ref.watch(activeClerkProvider);
    final clerks = store.clerks;
    final owners = clerks.where((c) => c.role == ClerkRole.dueno).length;

    return Scaffold(
      appBar: AppBar(backgroundColor: GColors.fondo, surfaceTintColor: Colors.transparent),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                const ScreenTitle('Personas del mostrador', subtitle: 'Para cuando varias personas usan la misma caja'),
                if (!store.usesPins) ...[
                  GCard(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (icon, text) in const [
                          (Icons.pin_outlined, 'Cada quien entra con su nombre y un PIN de 4 cifras.'),
                          (Icons.receipt_long_outlined, 'Cada venta, gasto y abono queda a nombre de quien atendió.'),
                          (Icons.bar_chart_rounded, 'En el corte ves cuánto vendió cada quien.'),
                          (Icons.lock_outline_rounded, 'Los cajeros no cancelan ventas ni ven tus ganancias.'),
                          (Icons.swap_horiz_rounded, 'Para cambiar de persona: toca su nombre arriba o F4.'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, size: 20, color: GColors.cenote),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(text, style: GText.sans(size: 14, weight: FontWeight.w500)),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Los PIN se guardan solo en este aparato. Si tienes otra caja, se configura allá también.',
                          style: GText.muted(size: 12.5),
                        ),
                        if (!ref.watch(syncProvider).signedIn) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Anota tu PIN: sin una cuenta abierta en este aparato no hay forma de recuperarlo.',
                            style: GText.sans(size: 12.5, weight: FontWeight.w700, color: GColors.cafe),
                          ),
                        ],
                        const SizedBox(height: 14),
                        GButton(
                          label: 'Empezar con mi PIN',
                          icon: Icons.pin_outlined,
                          kind: GButtonKind.money,
                          expand: true,
                          onPressed: () => _start(context, ref),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  SectionTitle(
                    clerks.length == 1 ? '1 persona' : '${clerks.length} personas',
                    trailing: TextButton.icon(
                      onPressed: () => _edit(context, ref),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                      label: const Text('Agregar'),
                    ),
                  ),
                  GCard(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (i, c) in clerks.indexed) ...[
                          if (i > 0) const Divider(height: 1, indent: 70, color: GColors.linea),
                          _ClerkRow(
                            clerk: c,
                            here: c.id == active?.id,
                            onTap: () => _edit(context, ref, c),
                            onRemove: c.id == active?.id || (c.role == ClerkRole.dueno && owners == 1)
                                ? null
                                : () => _remove(context, ref, c),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SectionTitle('Bloquear solo'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Si nadie toca la caja ese tiempo, pide el PIN otra vez.', style: GText.muted(size: 13)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final m in lockOptions)
                              SizedBox(
                                width: 84,
                                child: GChip(
                                  label: lockLabel(m),
                                  selected: store.lockMinutes == m,
                                  onTap: () => ref.read(storeProvider.notifier).setLockMinutes(m),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _disable(context, ref),
                      icon: const Icon(Icons.lock_open_rounded, size: 18, color: GColors.rojo),
                      label: Text(
                        'Dejar de pedir PIN en este aparato',
                        style: GText.sans(size: 13.5, weight: FontWeight.w700, color: GColors.rojo),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClerkRow extends StatelessWidget {
  const _ClerkRow({required this.clerk, required this.here, required this.onTap, this.onRemove});

  final Clerk clerk;
  final bool here;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              ClerkAvatar(clerk: clerk, size: 42),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clerk.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GText.sans(size: 15, weight: FontWeight.w700),
                    ),
                    Text(
                      here ? '${clerk.role.label} · atiende ahora' : clerk.role.label,
                      style: GText.sans(
                        size: 12.5,
                        weight: here ? FontWeight.w700 : FontWeight.w500,
                        color: here ? GColors.cenote : GColors.tintaSuave,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Quitar',
                  onPressed: onRemove,
                  icon: const Icon(Icons.person_remove_outlined, size: 21, color: GColors.tintaTenue),
                ),
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.chevron_right_rounded, color: GColors.tintaTenue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alta o cambio de una persona: nombre, qué puede hacer y su PIN (dos veces).
class ClerkSheet extends ConsumerStatefulWidget {
  const ClerkSheet({super.key, this.clerk, this.first = false});

  /// null = persona nueva.
  final Clerk? clerk;

  /// La primera persona es el dueño, que activa los PIN.
  final bool first;

  @override
  ConsumerState<ClerkSheet> createState() => _ClerkSheetState();
}

class _ClerkSheetState extends ConsumerState<ClerkSheet> {
  late final _name = TextEditingController(text: widget.clerk?.name ?? (widget.first ? 'Dueño' : ''));
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  late ClerkRole _role = widget.clerk?.role ?? (widget.first ? ClerkRole.dueno : ClerkRole.cajero);
  String? _nameError;
  String? _pinError;

  bool get _isNew => widget.clerk == null;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _pin2.dispose();
    super.dispose();
  }

  void _save() {
    final store = ref.read(storeProvider);
    final name = _name.text.trim();
    final taken = store.clerks.any((c) => c.id != widget.clerk?.id && c.name.toLowerCase() == name.toLowerCase());
    final pin = _pin.text;
    final changingPin = _isNew || pin.isNotEmpty || _pin2.text.isNotEmpty;
    setState(() {
      _nameError = name.isEmpty
          ? 'Pon su nombre'
          : taken
          ? 'Ya hay alguien con ese nombre'
          : null;
      _pinError = !changingPin
          ? null
          : !isValidPin(pin)
          ? 'El PIN son 4 números'
          : pin != _pin2.text
          ? 'Los dos PIN no son iguales'
          : null;
    });
    if (_nameError != null || _pinError != null) return;
    final base = widget.clerk;
    final clerk = base == null
        ? Clerk.create(name: name, role: _role, pin: pin)
        : (changingPin ? base.withPin(pin) : base).copyWith(name: name, role: _role);
    Navigator.of(context).pop(clerk);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    // El último dueño no puede dejar de serlo (alguien tiene que poder manejar a las personas).
    final lastOwner =
        widget.first ||
        (widget.clerk?.role == ClerkRole.dueno && store.clerks.where((c) => c.role == ClerkRole.dueno).length == 1);
    Widget pinField(TextEditingController c, String label) => TextField(
      controller: c,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
      decoration: InputDecoration(labelText: label, counterText: ''),
      onSubmitted: (_) => _save(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          widget.first
              ? 'Tu nombre y tu PIN'
              : _isNew
              ? 'Agregar persona'
              : widget.clerk!.name,
          caption: widget.first ? 'Tú eres el dueño' : 'Personas del mostrador',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          autofocus: _isNew && !widget.first,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [maxChars(Limits.maxPersonLength)],
          decoration: InputDecoration(labelText: 'Nombre', hintText: 'Ej. Doña Mari', errorText: _nameError),
        ),
        if (!lastOwner) ...[
          const SizedBox(height: 16),
          Text('Qué puede hacer', style: GText.sans(size: 14, weight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, r) in ClerkRole.values.reversed.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: GChip(label: r.label, selected: _role == r, onTap: () => setState(() => _role = r)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(switch (_role) {
            ClerkRole.cajero => 'Cobra, fía, recibe abonos y anota gastos. No cancela ventas ni ve ganancias.',
            ClerkRole.encargado => 'Lo del cajero, y además cancela ventas, ve ganancias y cambia productos.',
            ClerkRole.dueno => 'Todo, también agregar personas y cambiar sus PIN.',
          }, style: GText.muted(size: 12.5)),
        ],
        const SizedBox(height: 16),
        Text(
          _isNew ? 'PIN de 4 números' : 'Cambiar PIN (déjalo vacío para no cambiarlo)',
          style: GText.sans(size: 14, weight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: pinField(_pin, 'PIN')),
            const SizedBox(width: 12),
            Expanded(child: pinField(_pin2, 'Otra vez')),
          ],
        ),
        if (_pinError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _pinError!,
              style: GText.sans(size: 12.5, weight: FontWeight.w700, color: GColors.rojo),
            ),
          ),
        const SizedBox(height: 18),
        GButton(label: 'Guardar', expand: true, kind: GButtonKind.money, onPressed: _save),
      ],
    );
  }
}
