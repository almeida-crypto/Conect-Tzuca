import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

Future<void> showQuickSaleSheet(BuildContext context) => showGSheet(context, (_) => const _QuickSaleSheet());

/// Venta rápida: cobrar un monto sin buscar productos (calculadora de mostrador).
class _QuickSaleSheet extends ConsumerStatefulWidget {
  const _QuickSaleSheet();

  @override
  ConsumerState<_QuickSaleSheet> createState() => _QuickSaleSheetState();
}

class _QuickSaleSheetState extends ConsumerState<_QuickSaleSheet> {
  String _digits = '';
  final _concept = TextEditingController();
  String? _error;

  int get _cents => _digits.isEmpty ? 0 : int.parse(_digits);

  @override
  void dispose() {
    _concept.dispose();
    super.dispose();
  }

  void _press(String key) {
    setState(() {
      _error = null;
      if (key == '⌫') {
        if (_digits.isNotEmpty) _digits = _digits.substring(0, _digits.length - 1);
      } else if (_digits.length < 8) {
        _digits = (_digits + key).replaceFirst(RegExp(r'^0+'), '');
      }
    });
  }

  void _add() {
    if (_cents <= 0) {
      setState(() => _error = 'Escribe un monto');
      return;
    }
    final name = _concept.text.trim().isEmpty ? 'Varios' : _concept.text.trim();
    ref.read(cartProvider.notifier).addQuick(newId(), name, _cents);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('Venta rápida', caption: 'Cobra un monto sin buscar el producto'),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: GColors.papelClaro,
            border: Border.all(color: GColors.tinta, width: 1.5),
          ),
          child: Text(money(_cents), textAlign: TextAlign.right, style: GText.amount(size: 34)),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!, style: GText.sans(size: 13, color: GColors.rojo)),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _concept,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Concepto (opcional): bolsa de hielo'),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 2.4,
          children: [
            for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0', '⌫'])
              Material(
                color: GColors.papel2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                child: InkWell(
                  onTap: () => _press(k),
                  borderRadius: BorderRadius.circular(4),
                  child: Center(
                    child: k == '⌫'
                        ? const Icon(Icons.backspace_outlined, semanticLabel: 'Borrar')
                        : Text(k, style: GText.amount(size: 22)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GButton(label: 'Agregar a la cuenta', expand: true, big: true, onPressed: _add),
      ],
    );
  }
}
