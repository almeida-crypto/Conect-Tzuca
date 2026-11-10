import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/restaurant.dart';
import '../../domain/team.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../account/account_screen.dart';
import '../modules/module_widgets.dart' show EmptyInvite;
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import 'order_screen.dart';

/// Minutos desde [since], para "hace 12 min".
int minutesSince(DateTime since) => DateTime.now().difference(since).inMinutes;

/// Mesas y cocina: los meseros abren cuentas y mandan comandas; la cocina las ve al instante.
class RestaurantScreen extends ConsumerStatefulWidget {
  const RestaurantScreen({super.key, this.kitchen = false, this.embedded = false});

  /// Abre en la pestaña de cocina.
  final bool kitchen;

  /// Es la pantalla principal (meseros y cocina): sin flecha de regreso.
  final bool embedded;

  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen> {
  late bool _kitchen = widget.kitchen;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Los minutos de espera avanzan solos.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final can = ref.watch(permissionsProvider);
    final role = ref.watch(syncProvider.select((s) => s.role));
    final inKitchen = ref.watch(storeProvider.select((s) => s.kitchenOrders.length));

    // En cocina, cada comanda nueva suena y vibra.
    ref.listen(storeProvider.select((s) => s.kitchenOrders.map((o) => o.id).toSet()), (before, now) {
      if (_kitchen && before != null && now.difference(before).isNotEmpty) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.papel,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: !widget.embedded,
        title: Text(
          widget.embedded ? ref.watch(storeProvider.select((s) => s.businessName)) : 'Mesas y cocina',
          style: GText.sans(size: 17, weight: FontWeight.w800),
        ),
        actions: [
          if (can.manageTables && !_kitchen)
            IconButton(
              tooltip: 'Acomodar mesas',
              icon: const Icon(Icons.tune),
              onPressed: () => showGSheet<void>(context, (_) => const _TablesSheet()),
            ),
          if (widget.embedded)
            IconButton(
              tooltip: 'Mi cuenta',
              icon: const Icon(Icons.person_outline),
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen())),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OfflineNote(),
            if (role != MemberRole.kitchen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: GChip(label: 'Mesas', selected: !_kitchen, onTap: () => setState(() => _kitchen = false)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GChip(
                        label: inKitchen == 0 ? 'Cocina' : 'Cocina ($inKitchen)',
                        selected: _kitchen,
                        onTap: () => setState(() => _kitchen = true),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: _kitchen ? const _KitchenView() : const _TablesView()),
          ],
        ),
      ),
    );
  }
}

// ---------- Mesas ----------

class _TablesView extends ConsumerWidget {
  const _TablesView();

  Future<void> _takeout(BuildContext context) async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Para llevar'),
        content: TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: '¿A nombre de quién?', hintText: 'Juan (opcional)'),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Abrir')),
        ],
      ),
    );
    final label = name.text;
    name.dispose();
    if (ok == true && context.mounted) {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => OrderScreen(takeoutLabel: label.trim())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final can = ref.watch(permissionsProvider);
    final tables = store.activeTables;
    final takeouts = store.openOrders.where((o) => o.takeout).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (tables.isEmpty)
          const EmptyInvite(
            title: 'Arma tu salón',
            body: 'Agrega tus mesas para abrir cuentas y mandar las comandas a la cocina al instante.',
          ),
        if (tables.isEmpty && can.manageTables)
          GButton(
            label: 'Agregar mesas',
            icon: Icons.add,
            expand: true,
            onPressed: () => showGSheet<void>(context, (_) => const _TablesSheet()),
          ),
        if (tables.isNotEmpty)
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1,
            children: [for (final t in tables) _TableCard(table: t, order: store.openOrderOfTable(t.id))],
          ),
        const SizedBox(height: 14),
        GButton(
          label: 'Para llevar',
          icon: Icons.takeout_dining_outlined,
          kind: GButtonKind.outline,
          expand: true,
          onPressed: () => _takeout(context),
        ),
        if (takeouts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Para llevar', style: GText.sans(size: 15, weight: FontWeight.w800)),
          for (final o in takeouts)
            _OrderTile(order: o, title: store.orderTitle(o), totalCents: store.totalOfOrder(o.id)),
        ],
      ],
    );
  }
}

class _TableCard extends ConsumerWidget {
  const _TableCard({required this.table, this.order});

  final DiningTable table;
  final RestaurantOrder? order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final o = order;
    final busy = o != null;
    final ready = busy ? store.itemsOfOrder(o.id).where((i) => i.status == KitchenStatus.listo).length : 0;
    return Material(
      color: busy ? GColors.ocre.withValues(alpha: .16) : GColors.papelClaro,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: busy ? GColors.ocre : GColors.linea, width: busy ? 1.5 : 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => busy ? OrderScreen(orderId: o.id) : OrderScreen(tableId: table.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                table.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GText.sans(size: 15, weight: FontWeight.w800),
              ),
              const Spacer(),
              if (!busy)
                Text('Libre', style: GText.muted(size: 12.5))
              else ...[
                Text(money(store.totalOfOrder(o.id)), style: GText.amount(size: 16)),
                Text('${minutesSince(o.createdAt)} min', style: GText.muted(size: 12)),
              ],
              if (ready > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: GColors.monte,
                  child: Text(
                    ready == 1 ? '1 listo' : '$ready listos',
                    style: GText.sans(size: 11.5, weight: FontWeight.w800, color: GColors.papel),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.title, required this.totalCents});

  final RestaurantOrder order;
  final String title;
  final int totalCents;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.takeout_dining_outlined, color: GColors.pardo),
    title: Text(title, style: GText.sans(size: 14.5, weight: FontWeight.w800)),
    subtitle: Text('hace ${minutesSince(order.createdAt)} min', style: GText.muted()),
    trailing: Text(money(totalCents), style: GText.amount(size: 15)),
    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OrderScreen(orderId: order.id))),
  );
}

/// Agregar, renombrar y quitar mesas.
class _TablesSheet extends ConsumerWidget {
  const _TablesSheet();

  Future<void> _rename(BuildContext context, WidgetRef ref, DiningTable t) async {
    final name = TextEditingController(text: t.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de la mesa'),
        content: TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Terraza 2'),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) ref.read(storeProvider.notifier).renameTable(t.id, name.text);
    name.dispose();
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, DiningTable t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Quitar ${t.name}?'),
        content: Text(
          'Ya no aparecerá en las mesas. Lo que se vendió en ella se queda.',
          style: GText.sans(size: 14, weight: FontWeight.w400),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Quitar',
              style: GText.sans(size: 14, weight: FontWeight.w800, color: GColors.rojo),
            ),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(storeProvider.notifier).removeTable(t.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('Mesas'),
        Text('Agregar', style: GText.label()),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final n in [1, 2, 4, 6]) ...[
              Expanded(
                child: GChip(label: '+$n', selected: false, onTap: () => ref.read(storeProvider.notifier).addTables(n)),
              ),
              if (n != 6) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 12),
        for (final t in store.activeTables)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.name, style: GText.sans(size: 15)),
            onTap: () => _rename(context, ref, t),
            trailing: IconButton(
              tooltip: 'Quitar mesa',
              icon: const Icon(Icons.delete_outline),
              color: GColors.rojo,
              // Con la cuenta abierta no se puede quitar.
              onPressed: store.openOrderOfTable(t.id) == null ? () => _remove(context, ref, t) : null,
            ),
          ),
        if (store.activeTables.isNotEmpty)
          Text('Toca una mesa para cambiarle el nombre.', style: GText.muted(size: 12.5)),
      ],
    );
  }
}

// ---------- Cocina ----------

class _KitchenView extends ConsumerWidget {
  const _KitchenView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final orders = store.kitchenOrders;
    if (orders.isEmpty) {
      return ListView(
        children: const [
          EmptyInvite(
            title: 'Cocina al día',
            body: 'Aquí aparecen las comandas en cuanto el mesero las manda. Toca un platillo para avanzarlo.',
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [for (final o in orders) _KitchenTicket(order: o)],
    );
  }
}

class _KitchenTicket extends ConsumerWidget {
  const _KitchenTicket({required this.order});

  final RestaurantOrder order;

  static KitchenStatus? _next(KitchenStatus s) => switch (s) {
    KitchenStatus.pendiente => KitchenStatus.preparando,
    KitchenStatus.preparando => KitchenStatus.listo,
    _ => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final items = store.kitchenItemsOf(order.id);
    final firstSent = items.map((i) => i.sentAt!).reduce((a, b) => a.isBefore(b) ? a : b);
    final waited = minutesSince(firstSent);
    final allReady = items.every((i) => i.status == KitchenStatus.listo);
    final waitColor = waited >= 15 ? GColors.rojo : (waited >= 8 ? GColors.ocre : GColors.tintaSuave);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: GColors.papelClaro,
        border: Border(
          top: BorderSide(color: allReady ? GColors.monte : GColors.tinta, width: 3),
          left: const BorderSide(color: GColors.linea),
          right: const BorderSide(color: GColors.linea),
          bottom: const BorderSide(color: GColors.linea),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(store.orderTitle(order), style: GText.sans(size: 18, weight: FontWeight.w800)),
                ),
                Text(
                  '$waited min',
                  style: GText.mono(size: 14, weight: FontWeight.w700, color: waitColor),
                ),
              ],
            ),
          ),
          for (final i in items)
            InkWell(
              onTap: _next(i.status) == null
                  ? null
                  : () => ref.read(storeProvider.notifier).setItemStatus(i.id, _next(i.status)!),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text('${qtyLabel(i.qty)}×', style: GText.sans(size: 18, weight: FontWeight.w800)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i.name,
                            style: GText.sans(
                              size: 17,
                              weight: FontWeight.w800,
                              color: i.status == KitchenStatus.listo ? GColors.tintaSuave : GColors.tinta,
                            ),
                          ),
                          if (i.notes != null)
                            Text(
                              i.notes!,
                              style: GText.sans(size: 14, color: GColors.oxido).copyWith(fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    ),
                    KitchenStatusPill(i.status),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: allReady
                ? Text('Todo listo: esperando al mesero', style: GText.sans(size: 13.5, color: GColors.monte))
                : GButton(
                    label: 'Todo listo',
                    icon: Icons.check,
                    kind: GButtonKind.money,
                    expand: true,
                    onPressed: () => ref.read(storeProvider.notifier).markOrderReady(order.id),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Estado de un platillo con su color.
class KitchenStatusPill extends StatelessWidget {
  const KitchenStatusPill(this.status, {super.key});

  final KitchenStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      KitchenStatus.pendiente => (GColors.papel2, GColors.tinta),
      KitchenStatus.preparando => (GColors.ocre, GColors.tinta),
      KitchenStatus.listo => (GColors.monte, GColors.papel),
      KitchenStatus.servido => (Colors.transparent, GColors.tintaSuave),
      KitchenStatus.cancelado => (Colors.transparent, GColors.rojo),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
      child: Text(
        status.label,
        style: GText.sans(size: 12, weight: FontWeight.w800, color: fg),
      ),
    );
  }
}
