import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../state/store.dart';
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
