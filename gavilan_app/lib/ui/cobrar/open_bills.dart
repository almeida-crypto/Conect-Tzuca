import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/restaurant.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../caja/cash_dialogs.dart';
import '../widgets/buttons.dart';
import '../widgets/product_icons.dart';
import '../restaurant/restaurant_screen.dart' show elapsedLabel;
import 'pay_sheet.dart';

/// Cuentas abiertas con algo por cobrar (mesas y para llevar), la más vieja primero.
List<RestaurantOrder> billsToCharge(StoreState store) => [
  for (final o in store.openOrders)
    if (store.totalOfOrder(o.id) > 0) o,
];

/// Cobra una cuenta del restaurante desde la pestaña Cobrar: abre la caja si hace falta y luego el cobro.
Future<void> chargeBill(BuildContext context, WidgetRef ref, RestaurantOrder order) async {
  if (ref.read(storeProvider).openSession == null) {
    final opened = await showOpenCashDialog(context, ref);
    if (!opened || !context.mounted) return;
  }
  await showPaySheet(context, orderId: order.id);
}

/// "3 platillos · 12 min".
String billDetail(StoreState store, RestaurantOrder o) {
  final count = store
      .itemsOfOrder(o.id)
      .where((i) => i.status != KitchenStatus.cancelado)
      .fold(0.0, (a, i) => a + i.qty);
  return '${qtyLabel(count)} ${count == 1 ? 'platillo' : 'platillos'} · ${elapsedLabel(o.createdAt)}';
}

/// En el celular: las cuentas por cobrar en una fila que se desliza, arriba del menú.
class OpenBillsStrip extends ConsumerWidget {
  const OpenBillsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final bills = billsToCharge(store);
    if (bills.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 16, 8),
          child: Text('Cuentas por cobrar · ${bills.length}', style: GText.sans(size: 14, weight: FontWeight.w800)),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: bills.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(width: 168, child: BillCard(order: bills[i])),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

/// En la computadora: columna de cuentas por cobrar a la izquierda del menú.
class OpenBillsColumn extends ConsumerWidget {
  const OpenBillsColumn({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final bills = billsToCharge(store);
    final due = bills.fold(0, (a, o) => a + store.totalOfOrder(o.id));
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: GColors.linea)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text('Cuentas por cobrar', style: GText.sans(size: 18, weight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              bills.isEmpty ? 'Ninguna mesa tiene cuenta abierta' : '${bills.length} abiertas · ${money(due)}',
              style: GText.muted(size: 13),
            ),
          ),
          Expanded(
            child: bills.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.table_restaurant_outlined, size: 34, color: GColors.tintaTenue),
                        const SizedBox(height: 8),
                        Text(
                          'Las cuentas de las mesas y para llevar aparecen aquí para cobrarlas.',
                          textAlign: TextAlign.center,
                          style: GText.muted(size: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: bills.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => SizedBox(height: 92, child: BillCard(order: bills[i])),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Una cuenta abierta: de quién es, cuánto lleva y cuánto debe. Al tocarla se cobra.
class BillCard extends ConsumerWidget {
  const BillCard({super.key, required this.order});

  final RestaurantOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final o = order;
    final ready = store.itemsOfOrder(o.id).any((i) => i.status == KitchenStatus.listo);
    return Semantics(
      button: true,
      label: 'Cobrar ${store.orderTitle(o)}, ${money(store.totalOfOrder(o.id))}',
      excludeSemantics: true,
      child: Pressable(
        onTap: () => chargeBill(context, ref, o),
        scale: 0.96,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: GColors.marcaSuave,
            borderRadius: BorderRadius.circular(GShape.radius),
            border: Border.all(color: GColors.marca.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    o.takeout ? Icons.takeout_dining_rounded : Icons.table_restaurant_rounded,
                    size: 16,
                    color: GColors.marca,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      store.orderTitle(o),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GText.sans(size: 14, weight: FontWeight.w800),
                    ),
                  ),
                  if (ready)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: GColors.cenote, borderRadius: BorderRadius.circular(99)),
                      child: Text(
                        'listo',
                        style: GText.sans(size: 10.5, weight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                ],
              ),
              Text(billDetail(store, o), maxLines: 1, style: GText.muted(size: 12)),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(money(store.totalOfOrder(o.id)), style: GText.amount(size: 19)),
                    ),
                  ),
                  Text(
                    'Cobrar',
                    style: GText.sans(size: 12.5, weight: FontWeight.w800, color: GColors.cenote),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: GColors.cenote),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grupo del menú según el icono del producto, para acomodar el mostrador de un restaurante.
enum MenuGroup {
  platillos('Platillos'),
  bebidas('Bebidas'),
  postres('Postres'),
  otros('Otros');

  const MenuGroup(this.label);
  final String label;

  static MenuGroup of(Product p) => switch (p.iconId) {
    'refresco' || 'agua' || 'cafe' => MenuGroup.bebidas,
    'helado' || 'dulce' => MenuGroup.postres,
    'taco' || 'carne' || 'pan' || 'tortilla' || 'huevo' || 'fruta' => MenuGroup.platillos,
    _ => MenuGroup.otros,
  };
}

/// Icono del título de cada grupo del menú.
IconData menuGroupIcon(MenuGroup g) => switch (g) {
  MenuGroup.platillos => productIcon('taco'),
  MenuGroup.bebidas => productIcon('refresco'),
  MenuGroup.postres => productIcon('helado'),
  MenuGroup.otros => productIcon('otro'),
};
