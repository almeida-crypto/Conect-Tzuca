import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/restaurant.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../cobrar/pay_sheet.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/product_icons.dart';
import 'restaurant_screen.dart';

/// La cuenta de una mesa (o un pedido para llevar): anotar, mandar a cocina, servir y cobrar.
/// La comanda se crea hasta que se anota el primer platillo, así una mesa no queda ocupada en vano.
class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key, this.orderId, this.tableId, this.takeoutLabel});

  final String? orderId;
  final String? tableId;
  final String? takeoutLabel;

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  late String? _orderId = widget.orderId;

  StoreNotifier get _store => ref.read(storeProvider.notifier);

  String _ensureOrder() => _orderId ??= _store.openOrder(tableId: widget.tableId, label: widget.takeoutLabel).id;

  Future<void> _add() async {
    final picked = await showGSheet<Map<Product, int>>(context, (_) => const _ProductPicker());
    if (picked == null || picked.isEmpty || !mounted) return;
    final orderId = _ensureOrder();
    for (final e in picked.entries) {
      for (var i = 0; i < e.value; i++) {
        _store.addOrderItem(orderId, e.key);
      }
    }
    setState(() {});
  }

  void _send() {
    final n = _store.sendToKitchen(_orderId!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(n == 1 ? 'Se mandó 1 platillo a cocina' : 'Se mandaron $n platillos a cocina')),
    );
  }

  Future<void> _editNotes(OrderItem item) async {
    final notes = TextEditingController(text: item.notes ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.name),
        content: TextField(
          controller: notes,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Indicaciones para cocina', hintText: 'Sin cebolla'),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true) _store.setItemNotes(item.id, notes.text);
    notes.dispose();
  }

  Future<void> _charge() async {
    final route = ModalRoute.of(context);
    await showPaySheet(context, orderId: _orderId);
    if (!mounted || route == null) return;
    // Ya cobrada, la cuenta se quita de en medio y queda el ticket encima de las mesas.
    if (ref.read(storeProvider).orderById(_orderId!)?.isOpen == false) Navigator.of(context).removeRoute(route);
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar la cuenta?'),
        content: Text(
          'Lo que no se ha servido se cancela en cocina y la mesa queda libre. No se registra ninguna venta.',
          style: GText.sans(size: 14, weight: FontWeight.w400),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Cancelar cuenta',
              style: GText.sans(size: 14, weight: FontWeight.w800, color: GColors.rojo),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _store.cancelOrder(_orderId!);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final can = ref.watch(permissionsProvider);
    final order = _orderId == null ? null : store.orderById(_orderId!);
    final title = order != null
        ? store.orderTitle(order)
        : widget.tableId != null
        ? (store.tableById(widget.tableId!)?.name ?? 'Mesa')
        : (widget.takeoutLabel?.isNotEmpty ?? false)
        ? 'Para llevar · ${widget.takeoutLabel}'
        : 'Para llevar';
    final items = order == null ? <OrderItem>[] : store.itemsOfOrder(order.id).where((i) => !i.cancelled).toList();
    final unsent = items.where((i) => !i.sent).toList();
    final sent = items.where((i) => i.sent).toList();
    final total = order == null ? 0 : store.totalOfOrder(order.id);
    final closed = order != null && !order.isOpen;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text(title, style: GText.sans(size: 17, weight: FontWeight.w800)),
        actions: [
          if (order != null && order.isOpen)
            PopupMenuButton<String>(
              onSelected: (_) => _cancel(),
              itemBuilder: (_) => [const PopupMenuItem(value: 'cancel', child: Text('Cancelar cuenta'))],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OfflineNote(),
            if (closed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: GColors.hundido,
                child: Text(
                  order.status == OrderStatus.cerrada ? 'Esta cuenta ya se cobró.' : 'Esta cuenta se canceló.',
                  style: GText.sans(size: 14, weight: FontWeight.w800),
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 48, 28, 0),
                          child: Text(
                            'Toca "Agregar" para anotar lo que piden.',
                            textAlign: TextAlign.center,
                            style: GText.muted(size: 14),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        if (unsent.isNotEmpty) ...[
                          _Section('Por mandar a cocina'),
                          GCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            child: Column(
                              children: [
                                for (final (n, i) in unsent.indexed) ...[
                                  if (n > 0) const Divider(height: 1, color: GColors.linea),
                                  _UnsentRow(
                                    item: i,
                                    onNotes: () => _editNotes(i),
                                    onQty: (q) => _store.setItemQty(i.id, q),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (sent.isNotEmpty) ...[
                          _Section('En cocina y servido'),
                          GCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            child: Column(
                              children: [
                                for (final (n, i) in sent.indexed) ...[
                                  if (n > 0) const Divider(height: 1, color: GColors.linea),
                                  _SentRow(
                                    item: i,
                                    onServed: i.status == KitchenStatus.listo
                                        ? () => _store.setItemStatus(i.id, KitchenStatus.servido)
                                        : null,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            if (!closed)
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                decoration: const BoxDecoration(
                  color: GColors.superficie,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(GShape.radiusSheet)),
                  boxShadow: [BoxShadow(color: Color(0x1A1B1A19), blurRadius: 24, offset: Offset(0, -4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('Total', style: GText.sans(size: 15, weight: FontWeight.w800)),
                        const Spacer(),
                        Text(money(total), style: GText.amount(size: 22)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GButton(
                            label: 'Agregar',
                            icon: Icons.add,
                            kind: GButtonKind.outline,
                            expand: true,
                            onPressed: _add,
                          ),
                        ),
                        if (unsent.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: GButton(
                              label: 'A cocina (${unsent.length})',
                              icon: Icons.send_outlined,
                              expand: true,
                              onPressed: _send,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (can.charge && items.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GButton(
                        label: 'Cobrar ${money(total)}',
                        kind: GButtonKind.money,
                        expand: true,
                        big: true,
                        onPressed: _charge,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(text, style: GText.label()),
  );
}

class _UnsentRow extends StatelessWidget {
  const _UnsentRow({required this.item, required this.onNotes, required this.onQty});

  final OrderItem item;
  final VoidCallback onNotes;
  final ValueChanged<double> onQty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onNotes,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: GText.sans(size: 15, weight: FontWeight.w800)),
                  Text(
                    item.notes ?? 'Toca para agregar indicaciones',
                    style: item.notes == null
                        ? GText.muted(size: 12.5)
                        : GText.sans(size: 13, color: GColors.marca).copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Uno menos',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => onQty(item.qty - 1),
          ),
          Text(qtyLabel(item.qty), style: GText.sans(size: 16, weight: FontWeight.w800)),
          IconButton(
            tooltip: 'Uno más',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => onQty(item.qty + 1),
          ),
          SizedBox(
            width: 72,
            child: Text(money(item.totalCents), textAlign: TextAlign.right, style: GText.figures(size: 13)),
          ),
        ],
      ),
    );
  }
}

class _SentRow extends StatelessWidget {
  const _SentRow({required this.item, this.onServed});

  final OrderItem item;
  final VoidCallback? onServed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('${qtyLabel(item.qty)}×', style: GText.sans(size: 15, weight: FontWeight.w800)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: GText.sans(size: 15)),
                if (item.notes != null)
                  Text(
                    item.notes!,
                    style: GText.sans(size: 13, color: GColors.marca).copyWith(fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
          if (onServed != null)
            TextButton.icon(
              onPressed: onServed,
              icon: const Icon(Icons.room_service_outlined, size: 18, color: GColors.cenote),
              label: Text(
                'Servir',
                style: GText.sans(size: 13.5, weight: FontWeight.w800, color: GColors.cenote),
              ),
            )
          else
            KitchenStatusPill(item.status),
          SizedBox(
            width: 72,
            child: Text(money(item.totalCents), textAlign: TextAlign.right, style: GText.figures(size: 13)),
          ),
        ],
      ),
    );
  }
}

/// Elegir platillos: cada toque suma uno; al final se agregan todos juntos.
class _ProductPicker extends ConsumerStatefulWidget {
  const _ProductPicker();

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker> {
  final _picked = <Product, int>{};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final products =
        ref.watch(storeProvider).activeProducts.where((p) => q.isEmpty || p.name.toLowerCase().contains(q)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final count = _picked.values.fold(0, (a, n) => a + n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('¿Qué piden?'),
        TextField(
          autofocus: false,
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar platillo o bebida'),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: MediaQuery.sizeOf(context).height * .45,
          child: ListView(
            children: [
              for (final p in products)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ProductBadge(p.iconId, size: 42),
                  title: Text(p.name, style: GText.sans(size: 15)),
                  subtitle: Text(money(p.priceCents), style: GText.muted()),
                  trailing: (_picked[p] ?? 0) == 0
                      ? const Icon(Icons.add)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Uno menos',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => setState(() {
                                final n = (_picked[p] ?? 0) - 1;
                                n <= 0 ? _picked.remove(p) : _picked[p] = n;
                              }),
                            ),
                            Text('${_picked[p]}', style: GText.sans(size: 16, weight: FontWeight.w800)),
                          ],
                        ),
                  onTap: () => setState(() => _picked[p] = (_picked[p] ?? 0) + 1),
                ),
              if (products.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No hay productos con ese nombre. Dalos de alta en Inventario.',
                    textAlign: TextAlign.center,
                    style: GText.muted(size: 13.5),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GButton(
          label: count == 0 ? 'Elige lo que piden' : 'Agregar $count a la cuenta',
          expand: true,
          big: true,
          onPressed: count == 0 ? null : () => Navigator.of(context).pop(Map.of(_picked)),
        ),
      ],
    );
  }
}
