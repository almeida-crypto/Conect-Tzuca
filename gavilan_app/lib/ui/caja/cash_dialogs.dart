import '../../core/limits.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../state/clerk_session.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

/// Abrir caja con el fondo inicial. Devuelve true si se abrió.
Future<bool> showOpenCashDialog(BuildContext context, WidgetRef ref) async {
  final ok = await showGSheet<bool>(context, (_) => const _OpenCashSheet());
  return ok ?? false;
}

class _OpenCashSheet extends ConsumerStatefulWidget {
  const _OpenCashSheet();

  @override
  ConsumerState<_OpenCashSheet> createState() => _OpenCashSheetState();
}

class _OpenCashSheetState extends ConsumerState<_OpenCashSheet> {
  final _amount = TextEditingController(text: '500');
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _open() {
    final cents = parseMoney(_amount.text);
    if (cents == null) {
      setState(() => _error = 'Escribe el fondo con el que abres (puede ser 0)');
      return;
    }
    ref.read(storeProvider.notifier).openCash(cents);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('Abrir caja', caption: 'Empieza el turno'),
        Text('¿Con cuánto cambio empiezas en el cajón?', style: GText.sans(size: 14, weight: FontWeight.w400)),
        const SizedBox(height: 10),
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [MoneyInputFormatter()],
          onChanged: (_) => setState(() => _error = null),
          style: GText.amount(size: 24),
          decoration: InputDecoration(prefixText: '\$ ', errorText: _error),
        ),
        const SizedBox(height: 14),
        GButton(label: 'Abrir caja', expand: true, big: true, onPressed: _open),
      ],
    );
  }
}

/// Registrar un gasto (hielo, gas, insumos) o una entrada de efectivo.
Future<void> showMovementSheet(BuildContext context, CashKind kind) =>
    showGSheet(context, (_) => _MovementSheet(kind: kind));

class _MovementSheet extends ConsumerStatefulWidget {
  const _MovementSheet({required this.kind});

  final CashKind kind;

  @override
  ConsumerState<_MovementSheet> createState() => _MovementSheetState();
}

class _MovementSheetState extends ConsumerState<_MovementSheet> {
  final _amount = TextEditingController();
  final _concept = TextEditingController();
  String? _amountError;
  String? _conceptError;

  bool get _isGasto => widget.kind == CashKind.gasto;

  @override
  void dispose() {
    _amount.dispose();
    _concept.dispose();
    super.dispose();
  }

  void _save() {
    final cents = parseMoney(_amount.text);
    setState(() {
      _amountError = (cents == null || cents == 0) ? 'Escribe el monto' : null;
      _conceptError = _concept.text.trim().isEmpty ? 'Escribe en qué fue' : null;
    });
    if (_amountError != null || _conceptError != null) return;
    ref.read(storeProvider.notifier).addMovement(widget.kind, cents!, _concept.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          _isGasto ? 'Registrar gasto' : 'Registrar entrada',
          caption: _isGasto ? 'Dinero que sale del cajón' : 'Dinero que entra al cajón',
        ),
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [MoneyInputFormatter()],
          style: GText.amount(size: 22),
          onChanged: (_) => setState(() => _amountError = null),
          decoration: InputDecoration(prefixText: '\$ ', hintText: '0.00', errorText: _amountError),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _concept,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() => _conceptError = null),
          decoration: InputDecoration(
            labelText: 'Concepto',
            hintText: _isGasto ? 'Hielo, gas, insumos' : 'Cambio que trajo el dueño',
            errorText: _conceptError,
          ),
        ),
        const SizedBox(height: 14),
        GButton(
          label: _isGasto ? 'Guardar gasto' : 'Guardar entrada',
          kind: _isGasto ? GButtonKind.primary : GButtonKind.money,
          expand: true,
          onPressed: _save,
        ),
      ],
    );
  }
}

/// "Entregar caja": quien se va cuenta el cajón y se lo pasa a otra persona, que luego pone su PIN.
/// Queda anotado cuánto había y cuánto debía haber; no cierra el turno.
Future<void> showHandOverSheet(BuildContext context) => showGSheet<void>(context, (_) => const _HandOverSheet());

class _HandOverSheet extends ConsumerStatefulWidget {
  const _HandOverSheet();

  @override
  ConsumerState<_HandOverSheet> createState() => _HandOverSheetState();
}

class _HandOverSheetState extends ConsumerState<_HandOverSheet> {
  final _counted = TextEditingController();
  String? _to;
  String? _error;

  @override
  void dispose() {
    _counted.dispose();
    super.dispose();
  }

  void _save() {
    final counted = parseMoney(_counted.text);
    if (_to == null) {
      setState(() => _error = '¿A quién le entregas?');
      return;
    }
    if (counted == null) {
      setState(() => _error = 'Escribe cuánto efectivo contaste');
      return;
    }
    final to = _to!;
    final diff = ref.read(storeProvider.notifier).handOverCash(counted, to: to);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    ref.read(clerkSessionProvider.notifier).lock();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          diff == null || diff == 0
              ? 'Caja entregada. Que $to ponga su PIN.'
              : diff > 0
              ? 'Caja entregada con ${money(diff)} de más. Que $to ponga su PIN.'
              : 'Caja entregada con ${money(-diff)} de menos. Que $to ponga su PIN.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final me = ref.watch(activeClerkProvider);
    final session = store.openSession;
    final expected = session == null ? 0 : store.summaryFor(session).expectedCashCents;
    final others = [
      for (final c in store.clerks)
        if (c.id != me?.id) c,
    ];
    final counted = parseMoney(_counted.text);
    final diff = counted == null ? null : counted - expected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader('Entregar caja', caption: me == null ? 'Cambio de turno' : 'Te vas, ${me.name}'),
        Text(
          'Cuenta el efectivo del cajón. Se anota cuánto había y la otra persona sigue con la misma caja.',
          style: GText.sans(size: 14, weight: FontWeight.w400),
        ),
        const SizedBox(height: 14),
        Text('¿A quién se la entregas?', style: GText.sans(size: 14, weight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (others.isEmpty)
          Text('Primero agrega a otra persona en Más › Personas del mostrador.', style: GText.muted(size: 13))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in others)
                SizedBox(
                  width: 130,
                  child: GChip(
                    label: c.name,
                    selected: _to == c.name,
                    onTap: () => setState(() {
                      _to = c.name;
                      _error = null;
                    }),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text('Debe haber', style: GText.sans(size: 14, weight: FontWeight.w600)),
            ),
            Text(money(expected), style: GText.figures(size: 15, weight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _counted,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [MoneyInputFormatter()],
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _save(),
          style: GText.amount(size: 24),
          decoration: InputDecoration(labelText: 'Efectivo que contaste', prefixText: '\$ ', errorText: _error),
        ),
        if (diff != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              diff == 0
                  ? 'Cuadra al peso'
                  : diff > 0
                  ? 'Sobran ${money(diff)}'
                  : 'Faltan ${money(-diff)}',
              style: GText.sans(size: 14, weight: FontWeight.w800, color: diff < 0 ? GColors.rojo : GColors.cenote),
            ),
          ),
        const SizedBox(height: 16),
        GButton(
          label: 'Entregar y bloquear',
          icon: Icons.handshake_outlined,
          expand: true,
          big: true,
          kind: GButtonKind.money,
          onPressed: others.isEmpty ? null : _save,
        ),
      ],
    );
  }
}
