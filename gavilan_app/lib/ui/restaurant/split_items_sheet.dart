import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/restaurant.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../cobrar/pay_sheet.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

/// "Por platillos": se eligen los platillos que paga una persona y se cobran aparte, con su ticket.
/// La cuenta sigue abierta con lo demás hasta que se cobra todo.
Future<void> showSplitByItemsSheet(BuildContext context, {required String orderId}) async {
  final picked = await showGSheet<Map<String, double>>(context, (_) => _SplitItemsSheet(orderId: orderId));
  if (picked == null || picked.isEmpty || !context.mounted) return;
  await showPaySheet(context, orderId: orderId, items: picked);
}

class _SplitItemsSheet extends ConsumerStatefulWidget {
  const _SplitItemsSheet({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_SplitItemsSheet> createState() => _SplitItemsSheetState();
}

class _SplitItemsSheetState extends ConsumerState<_SplitItemsSheet> {
  final Map<String, double> _qty = {};

  void _set(OrderItem item, double qty) => setState(() => _qty[item.id] = qty.clamp(0, item.dueQty).toDouble());

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final order = store.orderById(widget.orderId);
    final items = [
      for (final i in store.itemsOfOrder(widget.orderId))
        if (!i.cancelled && !i.fullyPaid) i,
    ];
    final selected = items.fold(0, (a, i) => a + (i.unitWithExtrasCents * (_qty[i.id] ?? 0)).round());
    final all = items.every((i) => (_qty[i.id] ?? 0) >= i.dueQty - 0.0001);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader('¿Qué paga esta persona?', caption: order == null ? 'Por platillos' : store.orderTitle(order)),
        Text('Toca los platillos que va a pagar. Lo demás se queda en la cuenta.', style: GText.muted(size: 13)),
        const SizedBox(height: 8),
        for (final i in items)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: GColors.linea)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _set(i, (_qty[i.id] ?? 0) >= i.dueQty ? 0 : i.dueQty),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.fullName, style: GText.sans(size: 14.5, weight: FontWeight.w600)),
                        Text(
                          '${qtyLabel(i.dueQty)} por pagar · ${money(i.unitWithExtrasCents)} c/u',
                          style: GText.muted(size: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Uno menos',
                  onPressed: (_qty[i.id] ?? 0) > 0 ? () => _set(i, (_qty[i.id] ?? 0) - 1) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    qtyLabel(_qty[i.id] ?? 0),
                    textAlign: TextAlign.center,
                    style: GText.sans(size: 16, weight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Uno más',
                  onPressed: (_qty[i.id] ?? 0) < i.dueQty ? () => _set(i, (_qty[i.id] ?? 0) + 1) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() {
              for (final i in items) {
                _qty[i.id] = all ? 0 : i.dueQty;
              }
            }),
            child: Text(all ? 'Quitar todo' : 'Todo lo que falta'),
          ),
        ),
        const SizedBox(height: 6),
        GButton(
          label: selected == 0 ? 'Elige sus platillos' : 'Cobrar ${money(selected)}',
          kind: GButtonKind.money,
          expand: true,
          big: true,
          onPressed: selected == 0
              ? null
              : () => Navigator.of(context).pop({
                  for (final e in _qty.entries)
                    if (e.value > 0) e.key: e.value,
                }),
        ),
      ],
    );
  }
}
