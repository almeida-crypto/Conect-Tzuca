import '../../core/limits.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/share.dart';
import '../../domain/models.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import 'module_widgets.dart';

/// Pedidos por tanda: la cochinita del domingo, las marquesitas del viernes.
class TandasScreen extends ConsumerWidget {
  const TandasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final tandas = [...store.batches]..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Pedidos por tanda', style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: GButton(
                label: 'Nueva tanda',
                icon: Icons.add,
                expand: true,
                onPressed: () async {
                  final t = await showGSheet<Tanda>(context, (_) => const _NewTandaSheet());
                  if (t != null && context.mounted) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TandaDetailScreen(tandaId: t.id)));
                  }
                },
              ),
            ),
            if (tandas.isEmpty)
              const EmptyInvite(
                title: 'Organiza tus pedidos',
                body:
                    'Crea una tanda (por ejemplo, "Cochinita del domingo"), anota los pedidos de tus clientes '
                    'y marca con dos toques quién ya recogió y quién ya pagó.',
              ),
            for (final t in tandas) _TandaRow(tanda: t, orders: store.ordersOfBatch(t.id)),
          ],
        ),
      ),
    );
  }
}

class _TandaRow extends StatelessWidget {
  const _TandaRow({required this.tanda, required this.orders});

  final Tanda tanda;
  final List<BatchOrder> orders;

  @override
  Widget build(BuildContext context) {
    final total = orders.fold(0, (a, o) => a + o.totalCents);
    final paid = orders.where((o) => o.paid).fold(0, (a, o) => a + o.totalCents);
    final delivered = orders.where((o) => o.delivery == DeliveryStatus.entregado).length;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TandaDetailScreen(tandaId: tanda.id))),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: GColors.linea)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tanda.name, style: GText.sans(size: 15, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    '${dayLabel(tanda.date)} · ${_orders(orders.length)} · $delivered ${delivered == 1 ? 'entregado' : 'entregados'}',
                    style: GText.muted(size: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(money(total, hideZeroCents: true), style: GText.amount(size: 16)),
                Text(
                  paid == total ? 'todo cobrado' : 'falta ${money(total - paid, hideZeroCents: true)}',
                  style: GText.sans(size: 11.5, color: paid == total ? GColors.cenote : GColors.marca),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewTandaSheet extends ConsumerStatefulWidget {
  const _NewTandaSheet();

  @override
  ConsumerState<_NewTandaSheet> createState() => _NewTandaSheetState();
}

class _NewTandaSheetState extends ConsumerState<_NewTandaSheet> {
  final _name = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('Nueva tanda'),
        TextField(
          controller: _name,
          inputFormatters: [maxChars(Limits.maxNameLength)],
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(labelText: 'Nombre', hintText: 'Cochinita del domingo', errorText: _error),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text('Día: ${dayLabel(_date)}', style: GText.sans(size: 14)),
          onTap: () async {
            final d = await pickDay(context, initial: _date);
            if (d != null) setState(() => _date = d);
          },
        ),
        const SizedBox(height: 8),
        GButton(
          label: 'Crear tanda',
          expand: true,
          big: true,
          onPressed: () {
            if (_name.text.trim().isEmpty) {
              setState(() => _error = 'Ponle un nombre');
              return;
            }
            Navigator.of(context).pop(ref.read(storeProvider.notifier).addBatch(_name.text, _date));
          },
        ),
      ],
    );
  }
}

/// Una tanda: resumen de lo vendido, cobrado, insumos y ganancia, y sus pedidos.
class TandaDetailScreen extends ConsumerWidget {
  const TandaDetailScreen({super.key, required this.tandaId});

  final String tandaId;

  Future<void> _editSupplies(BuildContext context, WidgetRef ref, Tanda tanda) async {
    final controller = TextEditingController(
      text: tanda.suppliesCents == 0 ? '' : (tanda.suppliesCents / 100).toStringAsFixed(2),
    );
    final cents = await showGSheet<int>(
      context,
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader('Insumos de la tanda', caption: 'Carne, tortillas, gas, empaques'),
          MoneyField(controller: controller, autofocus: true),
          const SizedBox(height: 12),
          GButton(
            label: 'Guardar',
            expand: true,
            onPressed: () => Navigator.of(ctx).pop(parseMoney(controller.text) ?? 0),
          ),
        ],
      ),
    );
    disposeAfterClose(controller);
    if (cents != null) ref.read(storeProvider.notifier).setBatchSupplies(tanda.id, cents);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final tanda = store.batchById(tandaId)!;
    final orders = store.ordersOfBatch(tandaId);
    final total = orders.fold(0, (a, o) => a + o.totalCents);
    final paid = orders.where((o) => o.paid).fold(0, (a, o) => a + o.totalCents);
    final profit = total - tanda.suppliesCents;

    Widget line(String label, int cents, {Color? color, VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: GText.sans(size: 13.5, weight: FontWeight.w400)),
            ),
            if (onTap != null) const Icon(Icons.edit_outlined, size: 15, color: GColors.tintaSuave),
            const SizedBox(width: 6),
            Text(money(cents), style: GText.figures(size: 13, color: color ?? GColors.tinta)),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text(tanda.name, style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GColors.superficie,
                border: Border.all(color: GColors.linea),
                borderRadius: BorderRadius.circular(GShape.radiusSmall),
              ),
              child: Column(
                children: [
                  line('Vendido (${_orders(orders.length)})', total),
                  line('Cobrado', paid, color: GColors.cenote),
                  line('Por cobrar', total - paid, color: total == paid ? GColors.tintaSuave : GColors.marca),
                  line(
                    'Insumos',
                    tanda.suppliesCents,
                    color: GColors.rojo,
                    onTap: () => _editSupplies(context, ref, tanda),
                  ),
                  const Divider(color: GColors.tinta, thickness: 1.5),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Ganancia', style: GText.sans(size: 15, weight: FontWeight.w800)),
                      ),
                      Text(
                        money(profit),
                        style: GText.amount(size: 22, color: profit >= 0 ? GColors.cenote : GColors.rojo),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GButton(
              label: 'Agregar pedido',
              icon: Icons.add,
              expand: true,
              onPressed: () => showGSheet(context, (_) => _NewOrderSheet(tandaId: tandaId)),
            ),
            const SizedBox(height: 10),
            if (orders.isEmpty) Text('Todavía no hay pedidos en esta tanda.', style: GText.muted(size: 14)),
            for (final o in orders) _OrderRow(order: o, business: store.businessName, tanda: tanda),
          ],
        ),
      ),
    );
  }
}

/// Un pedido: dos toques, uno para la entrega y otro para el pago.
class _OrderRow extends ConsumerWidget {
  const _OrderRow({required this.order, required this.business, required this.tanda});

  final BatchOrder order;
  final String business;
  final Tanda tanda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(storeProvider.notifier);
    final (deliveryLabel, deliveryColor) = switch (order.delivery) {
      DeliveryStatus.pendiente => ('Pendiente', GColors.tintaSuave),
      DeliveryStatus.listo => ('Listo', GColors.izamal),
      DeliveryStatus.entregado => ('Entregado', GColors.cenote),
    };
    final next = switch (order.delivery) {
      DeliveryStatus.pendiente => DeliveryStatus.listo,
      DeliveryStatus.listo => DeliveryStatus.entregado,
      DeliveryStatus.entregado => DeliveryStatus.pendiente,
    };

    Widget toggle(String label, Color color, bool filled, VoidCallback onTap) => Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GShape.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(GShape.radiusSmall),
          ),
          child: Text(
            label,
            style: GText.sans(size: 12.5, weight: FontWeight.w800, color: filled ? GColors.fondo : color),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GColors.linea)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(order.customerName, style: GText.sans(size: 14.5, weight: FontWeight.w800)),
              ),
              Text(money(order.totalCents, hideZeroCents: true), style: GText.amount(size: 15)),
            ],
          ),
          if (order.detail != null) Text(order.detail!, style: GText.muted(size: 12.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              toggle(
                deliveryLabel,
                deliveryColor,
                order.delivery != DeliveryStatus.pendiente,
                () => notifier.updateBatchOrder(order.copyWith(delivery: next)),
              ),
              const SizedBox(width: 8),
              toggle(
                order.paid ? 'Pagado' : 'Por pagar',
                order.paid ? GColors.cenote : GColors.marca,
                order.paid,
                () => notifier.updateBatchOrder(order.copyWith(paid: !order.paid)),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Avisar por WhatsApp',
                icon: const Icon(Icons.chat_outlined, color: GColors.cenote),
                onPressed: () => shareText(
                  context,
                  'Hola, ${order.customerName}. Le saluda $business. '
                  'Su pedido de ${tanda.name.toLowerCase()}${order.detail == null ? '' : ' (${order.detail})'} '
                  '${order.delivery == DeliveryStatus.pendiente ? 'está anotado' : 'ya está listo'}. '
                  'Total: ${money(order.totalCents)}${order.paid ? ' (pagado)' : ''}. ¡Gracias!',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewOrderSheet extends ConsumerStatefulWidget {
  const _NewOrderSheet({required this.tandaId});

  final String tandaId;

  @override
  ConsumerState<_NewOrderSheet> createState() => _NewOrderSheetState();
}

class _NewOrderSheetState extends ConsumerState<_NewOrderSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _detail = TextEditingController();
  final _total = TextEditingController();
  final _errors = <String, String>{};

  @override
  void dispose() {
    for (final c in [_name, _phone, _detail, _total]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final total = parseMoney(_total.text);
    setState(() {
      _errors.clear();
      if (_name.text.trim().isEmpty) _errors['name'] = 'Escribe el nombre';
      if (total == null || total == 0) _errors['total'] = 'Escribe el total';
    });
    if (_errors.isNotEmpty) return;
    ref
        .read(storeProvider.notifier)
        .addBatchOrder(
          batchId: widget.tandaId,
          customerName: _name.text,
          totalCents: total!,
          phone: _phone.text,
          detail: _detail.text,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('Nuevo pedido'),
        TextField(
          controller: _name,
          inputFormatters: [maxChars(Limits.maxNameLength)],
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Cliente', hintText: 'Doña Lupe', errorText: _errors['name']),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _detail,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Pedido (opcional)',
            hintText: '1 kg de cochinita y 10 tortillas',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MoneyField(controller: _total, label: 'Total', error: _errors['total']),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'WhatsApp (opcional)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GButton(label: 'Guardar pedido', expand: true, big: true, onPressed: _save),
      ],
    );
  }
}

String _orders(int n) => n == 1 ? '1 pedido' : '$n pedidos';
