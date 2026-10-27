import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

Future<void> showCartSheet(BuildContext context) => showGSheet(context, (_) => const _CartSheet());

/// Editar la cuenta: cambiar cantidades o quitar renglones.
class _CartSheet extends ConsumerWidget {
  const _CartSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final notifier = ref.read(cartProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('Cuenta en curso'),
        if (cart.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('La cuenta está vacía.', style: GText.muted(size: 14)),
          ),
        for (final l in cart)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: GColors.linea)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.name, style: GText.sans(size: 14, weight: FontWeight.w800)),
                      Text('${money(l.unitCents)} c/u', style: GText.muted()),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar uno',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => notifier.setQty(l.key, l.qty - 1),
                ),
                SizedBox(
                  width: 34,
                  child: Text(qtyLabel(l.qty), textAlign: TextAlign.center, style: GText.amount(size: 16)),
                ),
                IconButton(
                  tooltip: 'Agregar uno',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => notifier.setQty(l.key, l.qty + 1),
                ),
                SizedBox(
                  width: 78,
                  child: Text(money(l.totalCents), textAlign: TextAlign.right, style: GText.mono(size: 12.5)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Total', style: GText.sans(size: 15)),
            const Spacer(),
            Text(money(total), style: GText.amount(size: 24)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            GButton(
              label: 'Vaciar',
              kind: GButtonKind.outline,
              onPressed: cart.isEmpty
                  ? null
                  : () {
                      notifier.clear();
                      Navigator.of(context).pop();
                    },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GButton(label: 'Listo', expand: true, onPressed: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ],
    );
  }
}
