import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
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
        for (final l in cart) CartLineRow(line: l),
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

/// Un renglón de la cuenta: nombre, precio unitario, cantidad con − y +, e importe.
class CartLineRow extends ConsumerWidget {
  const CartLineRow({super.key, required this.line});

  final SaleLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = line;
    final notifier = ref.read(cartProvider.notifier);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GColors.linea)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GText.sans(size: 14, weight: FontWeight.w700),
                ),
                Text('${money(l.unitCents)} c/u', style: GText.muted()),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Quitar uno',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            onPressed: () => notifier.setQty(l.key, l.qty - 1),
          ),
          SizedBox(
            width: 30,
            child: Text(qtyLabel(l.qty), textAlign: TextAlign.center, style: GText.amount(size: 16)),
          ),
          IconButton(
            tooltip: 'Agregar uno',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => notifier.setQty(l.key, l.qty + 1),
          ),
          SizedBox(
            width: 76,
            child: Text(
              money(l.totalCents),
              textAlign: TextAlign.right,
              style: GText.figures(size: 13.5, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// En la computadora la cuenta queda siempre a la derecha, como en una caja registradora.
class CartPanel extends ConsumerWidget {
  const CartPanel({super.key, required this.onPay});

  final VoidCallback onPay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final count = cart.fold(0.0, (a, l) => a + l.qty);
    return Container(
      decoration: const BoxDecoration(
        color: GColors.superficie,
        border: Border(left: BorderSide(color: GColors.linea)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Cuenta', style: GText.sans(size: 20, weight: FontWeight.w800)),
              const SizedBox(width: 8),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: GColors.marcaSuave, borderRadius: BorderRadius.circular(99)),
                  child: Text(
                    qtyLabel(count),
                    style: GText.sans(size: 12.5, weight: FontWeight.w800, color: GColors.marca),
                  ),
                ),
              const Spacer(),
              if (cart.isNotEmpty)
                TextButton(
                  onPressed: () => ref.read(cartProvider.notifier).clear(),
                  child: Text(
                    'Vaciar',
                    style: GText.sans(size: 13.5, weight: FontWeight.w700, color: GColors.tintaSuave),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded, size: 40, color: GColors.tintaTenue),
                        const SizedBox(height: 10),
                        Text(
                          'Toca un producto o pasa el lector de códigos.',
                          textAlign: TextAlign.center,
                          style: GText.muted(size: 14),
                        ),
                      ],
                    ),
                  )
                : ListView(children: [for (final l in cart.reversed) CartLineRow(line: l)]),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('TOTAL', style: GText.label()),
              const Spacer(),
              Text(money(total), style: GText.amount(size: 32)),
            ],
          ),
          const SizedBox(height: 14),
          GButton(
            label: 'Cobrar',
            icon: Icons.arrow_forward_rounded,
            kind: GButtonKind.money,
            big: true,
            expand: true,
            onPressed: onPay,
          ),
        ],
      ),
    );
  }
}
