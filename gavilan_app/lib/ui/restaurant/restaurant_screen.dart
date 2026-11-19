import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ticket_html.dart';
import '../../core/print/print.dart';

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
import 'floor_plan.dart';
import 'order_screen.dart';
import 'extras_screen.dart';
import '../account/business_switcher.dart';
import '../../state/profiles.dart';

/// Minutos desde [since], para "hace 12 min".
int minutesSince(DateTime since) => DateTime.now().difference(since).inMinutes;

/// "recién", "12 min", "2 h 5 min", "3 días": se lee bien aunque una cuenta lleve mucho abierta.
String elapsedLabel(DateTime since) {
  final m = minutesSince(since);
  if (m < 1) return 'recién';
  if (m < 60) return '$m min';
  if (m < 24 * 60) return m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} min';
  final d = m ~/ (24 * 60);
  return d == 1 ? '1 día' : '$d días';
}

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

  /// Imprime un envío nuevo ("cuenta@hora"), solo si es reciente (al abrir no se reimprime lo de antes).
  void _printBatch(String key) {
    final at = key.lastIndexOf('@');
    final orderId = key.substring(0, at);
    final sentAt = DateTime.fromMillisecondsSinceEpoch(int.parse(key.substring(at + 1)));
    if (DateTime.now().difference(sentAt).inMinutes >= 3) return;
    printComanda(ref.read(storeProvider), orderId, sentAt: sentAt);
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
    // En la computadora de la cocina, si se pidió, cada envío nuevo se imprime solo.
    if (canPrintTicket) {
      ref.listen(storeProvider.select((s) => kitchenBatches(s)), (before, now) {
        if (!_kitchen || !ref.read(storeProvider).kitchenPrint) return;
        final printed = before ?? const <String>{};
        for (final key in now.difference(printed)) {
          _printBatch(key);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: !widget.embedded,
        title: Text(
          widget.embedded ? ref.watch(storeProvider.select((s) => s.businessName)) : 'Mesas y cocina',
          style: GText.sans(size: 17, weight: FontWeight.w800),
        ),
        actions: [
          if (_kitchen && canPrintTicket)
            Builder(
              builder: (context) {
                final on = ref.watch(storeProvider.select((s) => s.kitchenPrint));
                return TextButton.icon(
                  onPressed: () => ref.read(storeProvider.notifier).setKitchenPrint(!on),
                  icon: Icon(
                    on ? Icons.print_rounded : Icons.print_disabled_outlined,
                    size: 20,
                    color: on ? GColors.cenote : GColors.tintaSuave,
                  ),
                  label: Text(
                    on ? 'Imprime comandas' : 'Imprimir comandas',
                    style: GText.sans(
                      size: 13.5,
                      weight: FontWeight.w800,
                      color: on ? GColors.cenote : GColors.tintaSuave,
                    ),
                  ),
                );
              },
            ),
          if (can.manageTables && !_kitchen)
            IconButton(
              tooltip: 'Acomodar mesas',
              icon: const Icon(Icons.tune),
              onPressed: () => showGSheet<void>(context, (_) => const _TablesSheet()),
            ),
          if (can.manageTables && !_kitchen)
            IconButton(
              tooltip: 'Extras con precio',
              icon: const Icon(Icons.add_card_outlined),
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ExtrasScreen())),
            ),
          if (widget.embedded && ref.watch(businessSwitcherProvider) != null)
            IconButton(
              tooltip: 'Mis negocios',
              icon: const Icon(Icons.swap_horiz_rounded),
              onPressed: () => showBusinessSwitcher(context),
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

class _TablesView extends ConsumerStatefulWidget {
  const _TablesView();

  @override
  ConsumerState<_TablesView> createState() => _TablesViewState();
}

class _TablesViewState extends ConsumerState<_TablesView> {
  /// Ver el salón dibujado (plano) o en tarjetas. null = según la pantalla: plano en la computadora.
  bool? _plan;

  /// Moviendo las mesas en el plano (solo el dueño o el encargado).
  bool _arranging = false;

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
    disposeAfterClose(name);
    if (ok == true && context.mounted) {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => OrderScreen(takeoutLabel: label.trim())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final can = ref.watch(permissionsProvider);
    final tables = store.activeTables;
    final takeouts = store.openOrders.where((o) => o.takeout).toList();
    final plan = _plan ?? MediaQuery.sizeOf(context).width >= 900;
    final narrow = MediaQuery.sizeOf(context).width < 600;

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
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${store.openOrders.where((o) => !o.takeout).length} de ${tables.length} ocupadas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GText.sans(size: 13, weight: FontWeight.w600, color: GColors.tintaSuave),
                  ),
                ),
                // En el celular, "Acomodar" va solo con su icono para que quepa todo en el renglón.
                if (plan && can.manageTables && !_arranging)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: narrow
                        ? IconButton(
                            tooltip: 'Acomodar las mesas',
                            onPressed: () => setState(() => _arranging = true),
                            icon: const Icon(Icons.open_with_rounded, color: GColors.marca),
                          )
                        : TextButton.icon(
                            onPressed: () => setState(() => _arranging = true),
                            icon: const Icon(Icons.open_with_rounded, size: 18),
                            label: const Text('Acomodar'),
                          ),
                  ),
                if (_arranging)
                  FilledButton.icon(
                    onPressed: () => setState(() => _arranging = false),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Listo'),
                  )
                else
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: narrow ? null : const Icon(Icons.grid_view_rounded, size: 18),
                        label: const Text('Tarjetas'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: narrow ? null : const Icon(Icons.chair_alt_outlined, size: 18),
                        label: const Text('Plano'),
                      ),
                    ],
                    selected: {plan},
                    onSelectionChanged: (v) => setState(() => _plan = v.first),
                  ),
              ],
            ),
          ),
        if (_arranging)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(color: GColors.cenoteSuave, borderRadius: BorderRadius.circular(GShape.radius)),
            child: Row(
              children: [
                const Icon(Icons.open_with_rounded, size: 20, color: GColors.cenoteOscuro),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Arrastra cada mesa a donde está en tu local. Toca una para elegir si es cuadrada o redonda '
                    'y cuántas sillas tiene. Se guarda solo y lo ven todos los celulares.'
                    '${narrow ? ' En la computadora o con el celular de lado hay más espacio.' : ''}',
                    style: GText.sans(size: 13, color: GColors.cenoteOscuro),
                  ),
                ),
              ],
            ),
          ),
        if (plan || _arranging)
          for (final zone in store.zones)
            FloorZone(zone: zone, title: store.zones.length > 1 || zone != null, arranging: _arranging)
        else
          for (final zone in store.zones) ...[
            // Con una sola zona (o ninguna) no hace falta título.
            if (store.zones.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
                child: Row(
                  children: [
                    // Las mesas sin zona son las del salón.
                    Text(zone ?? 'Salón', style: GText.sans(size: 15, weight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Text(
                      _freeLabel(store, zone),
                      style: GText.sans(size: 12.5, weight: FontWeight.w600, color: GColors.tintaTenue),
                    ),
                  ],
                ),
              ),
            GridView.count(
              // 3 en el celular; más columnas en pantallas anchas, con mesas de unos 170 px.
              crossAxisCount: (MediaQuery.sizeOf(context).width / 170).floor().clamp(3, 8),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
              children: [
                for (final t in store.tablesIn(zone)) _TableCard(table: t, order: store.openOrderOfTable(t.id)),
              ],
            ),
          ],
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

/// "3 de 5 libres".
String _freeLabel(StoreState store, String? zone) {
  final all = store.tablesIn(zone);
  final free = all.where((t) => store.openOrderOfTable(t.id) == null).length;
  return '$free de ${all.length} ${all.length == 1 ? 'libre' : 'libres'}';
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
    final items = busy
        ? store.itemsOfOrder(o.id).where((i) => i.status != KitchenStatus.cancelado).toList()
        : <OrderItem>[];
    final ready = items.where((i) => i.status == KitchenStatus.listo).length;
    final cooking = items.any(
      (i) => i.sent && (i.status == KitchenStatus.pendiente || i.status == KitchenStatus.preparando),
    );
    final unsent = items.any((i) => !i.sent);
    final dishes = items.fold(0.0, (a, i) => a + i.qty);
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => busy ? OrderScreen(orderId: o.id) : OrderScreen(tableId: table.id),
        ),
      ),
      scale: 0.95,
      // Libre en blanco; ocupada se pinta de achiote suave al abrir la cuenta.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: busy ? GColors.marcaSuave : GColors.superficie,
          borderRadius: BorderRadius.circular(GShape.radius),
          border: Border.all(color: busy ? GColors.marca.withValues(alpha: 0.45) : Colors.transparent, width: 1.5),
          boxShadow: busy ? null : GShape.shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    table.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GText.sans(size: 15, weight: FontWeight.w800),
                  ),
                ),
                Icon(
                  busy ? Icons.restaurant_rounded : Icons.table_restaurant_outlined,
                  size: 17,
                  color: busy ? GColors.marca : GColors.tintaTenue,
                ),
              ],
            ),
            const Spacer(),
            if (!busy)
              Text(
                'Libre',
                style: GText.sans(size: 12.5, weight: FontWeight.w600, color: GColors.tintaTenue),
              )
            else ...[
              Text(money(store.totalOfOrder(o.id)), style: GText.amount(size: 17)),
              // Platillos y tiempo con iconos: caben en la mesa más chica del celular.
              Semantics(
                label: '${qtyLabel(dishes)} ${dishes == 1 ? 'platillo' : 'platillos'}, ${elapsedLabel(o.createdAt)}',
                excludeSemantics: true,
                child: Row(
                  children: [
                    const Icon(Icons.restaurant_menu_rounded, size: 13, color: GColors.tintaSuave),
                    const SizedBox(width: 3),
                    Text(qtyLabel(dishes), style: GText.muted(size: 12)),
                    const SizedBox(width: 8),
                    const Icon(Icons.schedule_rounded, size: 13, color: GColors.tintaSuave),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        elapsedLabel(o.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GText.muted(size: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (ready > 0) ...[
              const SizedBox(height: 5),
              _ReadyPill(count: ready),
            ] else if (unsent) ...[
              const SizedBox(height: 5),
              const _StatePill('Sin mandar', GColors.izamalSuave, Color(0xFF8A5A00)),
            ] else if (cooking) ...[
              const SizedBox(height: 5),
              const _StatePill('En cocina', GColors.hundido, GColors.tintaSuave),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado de la mesa en una pastilla: "En cocina", "Sin mandar".
class _StatePill extends StatelessWidget {
  const _StatePill(this.label, this.background, this.ink);

  final String label;
  final Color background;
  final Color ink;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
    child: Text(
      label,
      style: GText.sans(size: 11.5, weight: FontWeight.w800, color: ink),
    ),
  );
}

/// "2 listos": late suave para que el mesero lo vea desde lejos.
class _ReadyPill extends StatefulWidget {
  const _ReadyPill({required this.count});

  final int count;

  @override
  State<_ReadyPill> createState() => _ReadyPillState();
}

class _ReadyPillState extends State<_ReadyPill> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.07).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: GColors.cenote, borderRadius: BorderRadius.circular(99)),
        child: Text(
          widget.count == 1 ? '1 listo' : '${widget.count} listos',
          style: GText.sans(size: 11.5, weight: FontWeight.w800, color: Colors.white),
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
  Widget build(BuildContext context) => GCard(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OrderScreen(orderId: order.id))),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: GColors.izamalSuave, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.takeout_dining_rounded, color: Color(0xFFB27C00), size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GText.sans(size: 15, weight: FontWeight.w700)),
              Text(
                elapsedLabel(order.createdAt) == 'recién' ? 'Recién abierta' : 'hace ${elapsedLabel(order.createdAt)}',
                style: GText.muted(size: 12.5),
              ),
            ],
          ),
        ),
        Text(money(totalCents), style: GText.amount(size: 16)),
      ],
    ),
  );
}

/// Agregar, renombrar, cambiar de zona y quitar mesas.
class _TablesSheet extends ConsumerStatefulWidget {
  const _TablesSheet();

  @override
  ConsumerState<_TablesSheet> createState() => _TablesSheetState();
}

class _TablesSheetState extends ConsumerState<_TablesSheet> {
  /// Zona donde caen las mesas nuevas (null = sin zona).
  String? _zone;

  StoreNotifier get _store => ref.read(storeProvider.notifier);

  Future<String?> _askZone({String? initial}) async {
    final name = TextEditingController(text: initial ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de la zona'),
        content: TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Terraza, Segunda planta, Aire libre…'),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Listo')),
        ],
      ),
    );
    final value = name.text.trim();
    disposeAfterClose(name);
    return ok == true && value.isNotEmpty ? value : null;
  }

  Future<void> _edit(DiningTable t) async {
    final name = TextEditingController(text: t.name);
    String? zone = t.zone;
    final zones = ref.read(storeProvider).zones.whereType<String>().toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Mesa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Mesa 4, Barra, Jardín 2'),
              ),
              const SizedBox(height: 14),
              Text('Zona', style: GText.label()),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final z in <String?>[null, ...zones])
                    ChoiceChip(
                      label: Text(z ?? 'Sin zona'),
                      selected: zone == z,
                      onSelected: (_) => setLocal(() => zone = z),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nueva'),
                    onPressed: () async {
                      final created = await _askZone();
                      if (created != null) setLocal(() => zone = created);
                    },
                  ),
                ],
              ),
              if (zone != null && !zones.contains(zone))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Zona nueva: $zone', style: GText.muted(size: 12.5)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok == true) {
      if (name.text.trim().isNotEmpty && name.text.trim() != t.name) _store.renameTable(t.id, name.text);
      if (zone != t.zone) _store.moveTable(t.id, zone);
    }
    disposeAfterClose(name);
  }

  Future<void> _remove(DiningTable t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Quitar ${t.fullName}?'),
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
    if (ok == true) _store.removeTable(t.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final zones = store.zones.whereType<String>().toList();
    // Una zona recién inventada todavía no tiene mesas: se muestra como opción igual.
    final options = <String?>[null, ...zones, if (_zone != null && !zones.contains(_zone)) _zone];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('Mesas'),
        Text('AGREGAR EN', style: GText.label()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final z in options)
              ChoiceChip(
                label: Text(z ?? 'Sin zona'),
                selected: _zone == z,
                onSelected: (_) => setState(() => _zone = z),
              ),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nueva zona'),
              onPressed: () async {
                final created = await _askZone();
                if (created != null) setState(() => _zone = created);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final n in [1, 2, 4, 6]) ...[
              Expanded(
                child: GChip(
                  label: '+$n',
                  selected: false,
                  onTap: () => _store.addTables(n, zone: _zone),
                ),
              ),
              if (n != 6) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 14),
        for (final zone in store.zones) ...[
          if (store.zones.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text((zone ?? 'Sin zona').toUpperCase(), style: GText.label()),
            ),
          for (final t in store.tablesIn(zone))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.name, style: GText.sans(size: 15, weight: FontWeight.w600)),
              subtitle: t.zone == null ? null : Text(t.zone!, style: GText.muted()),
              onTap: () => _edit(t),
              trailing: IconButton(
                tooltip: 'Quitar mesa',
                icon: const Icon(Icons.delete_outline_rounded),
                color: GColors.rojo,
                // Con la cuenta abierta no se puede quitar.
                onPressed: store.openOrderOfTable(t.id) == null ? () => _remove(t) : null,
              ),
            ),
        ],
        if (store.activeTables.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Toca una mesa para cambiarle el nombre o la zona.', style: GText.muted(size: 12.5)),
          ),
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
      children: [for (final o in orders) _KitchenTicket(key: ValueKey(o.id), order: o)],
    );
  }
}

class _KitchenTicket extends ConsumerStatefulWidget {
  const _KitchenTicket({super.key, required this.order});

  final RestaurantOrder order;

  @override
  ConsumerState<_KitchenTicket> createState() => _KitchenTicketState();
}

class _KitchenTicketState extends ConsumerState<_KitchenTicket> with SingleTickerProviderStateMixin {
  // Al llegar: entra desde la derecha y el borde late en achiote unos segundos.
  late final _arrive = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    // Solo lo recién mandado (últimos 20 s) entra con animación; lo demás ya estaba ahí.
    final sent = ref.read(storeProvider).kitchenItemsOf(widget.order.id).map((i) => i.sentAt!);
    final fresh = sent.isNotEmpty && sent.any((t) => DateTime.now().difference(t).inSeconds < 20);
    fresh ? _arrive.forward() : _arrive.value = 1;
  }

  @override
  void dispose() {
    _arrive.dispose();
    super.dispose();
  }

  RestaurantOrder get order => widget.order;

  static KitchenStatus? _next(KitchenStatus s) => switch (s) {
    KitchenStatus.pendiente => KitchenStatus.preparando,
    KitchenStatus.preparando => KitchenStatus.listo,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final items = store.kitchenItemsOf(order.id);
    final firstSent = items.map((i) => i.sentAt!).reduce((a, b) => a.isBefore(b) ? a : b);
    final waited = minutesSince(firstSent);
    final allReady = items.every((i) => i.status == KitchenStatus.listo);
    final waitColor = waited >= 15 ? GColors.rojo : (waited >= 8 ? const Color(0xFFB27C00) : GColors.tintaSuave);
    final slide = CurvedAnimation(
      parent: _arrive,
      curve: const Interval(0, 0.18, curve: Curves.easeOutBack),
    );
    final glow = CurvedAnimation(
      parent: _arrive,
      curve: const Interval(0.1, 1, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: _arrive,
      builder: (context, child) {
        // Late tres veces y se apaga.
        final fresh = 1 - glow.value;
        final pulse = math.max(fresh * 0.55, fresh * (0.5 + 0.5 * math.sin(glow.value * math.pi * 6)).abs());
        return Opacity(
          opacity: slide.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(40 * (1 - slide.value), 0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: GColors.superficie,
                borderRadius: BorderRadius.circular(GShape.radius),
                border: Border.all(
                  color: Color.lerp(
                    allReady ? GColors.cenote.withValues(alpha: 0.5) : Colors.transparent,
                    GColors.marca,
                    pulse,
                  )!,
                  width: 2.5,
                ),
                boxShadow: [
                  ...GShape.shadow,
                  if (pulse > 0.01)
                    BoxShadow(color: GColors.marca.withValues(alpha: 0.55 * pulse), blurRadius: 26, spreadRadius: 2),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(store.orderTitle(order), style: GText.sans(size: 18, weight: FontWeight.w800)),
                ),
                // Etiqueta de recién llegada: se desvanece cuando deja de latir.
                AnimatedBuilder(
                  animation: glow,
                  builder: (context, _) => glow.value >= 1
                      ? const SizedBox.shrink()
                      : Opacity(
                          opacity: (1 - glow.value).clamp(0.0, 1.0),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: GColors.marca, borderRadius: BorderRadius.circular(99)),
                            child: Text(
                              'Nueva',
                              style: GText.sans(size: 11.5, weight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ),
                ),
                Text(
                  elapsedLabel(firstSent),
                  style: GText.figures(size: 14, weight: FontWeight.w700, color: waitColor),
                ),
                if (canPrintTicket)
                  IconButton(
                    tooltip: 'Imprimir comanda',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => printComanda(ref.read(storeProvider), order.id),
                    icon: const Icon(Icons.print_outlined, size: 20, color: GColors.tintaSuave),
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
                          // Los extras, bien visibles para que cocina no se los salte.
                          for (final e in i.extras)
                            Text(
                              '+ ${e.name}',
                              style: GText.sans(size: 15, weight: FontWeight.w800, color: GColors.cenote),
                            ),
                          if (i.notes != null)
                            Text(
                              i.notes!,
                              style: GText.sans(size: 14, color: GColors.marca).copyWith(fontStyle: FontStyle.italic),
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
                ? Text('Todo listo: esperando al mesero', style: GText.sans(size: 13.5, color: GColors.cenote))
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
      KitchenStatus.pendiente => (GColors.hundido, GColors.tinta),
      KitchenStatus.preparando => (GColors.izamal, GColors.tinta),
      KitchenStatus.listo => (GColors.cenote, GColors.fondo),
      KitchenStatus.servido => (Colors.transparent, GColors.tintaSuave),
      KitchenStatus.cancelado => (Colors.transparent, GColors.rojo),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(
        status.label,
        style: GText.sans(size: 12, weight: FontWeight.w800, color: fg),
      ),
    );
  }
}

/// Cada envío a cocina ("cuenta@hora en que se mandó"). Lo nuevo de este conjunto es lo que hay que imprimir.
Set<String> kitchenBatches(StoreState s) => {
  for (final o in s.kitchenOrders)
    for (final i in s.kitchenItemsOf(o.id))
      if (i.sentAt != null) '${o.id}@${i.sentAt!.millisecondsSinceEpoch}',
};

/// Imprime la comanda de [orderId]: solo lo de un envío ([sentAt]) o todo lo que está en cocina.
void printComanda(StoreState s, String orderId, {DateTime? sentAt}) {
  final order = s.orderById(orderId);
  if (order == null) return;
  final items = [
    for (final i in s.kitchenItemsOf(orderId))
      if (sentAt == null || i.sentAt == sentAt) i,
  ];
  if (items.isEmpty) return;
  printHtml(comandaHtml(business: s.businessName, place: s.orderTitle(order), items: items));
}
