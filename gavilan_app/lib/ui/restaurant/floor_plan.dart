import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/floor_layout.dart';
import '../../domain/restaurant.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import 'order_screen.dart';
import 'restaurant_screen.dart' show elapsedLabel;

/// Una zona del salón dibujada desde arriba, sobre piso de mosaico, con las mesas donde las acomodaron y
/// lo demás del local (paredes, puerta, barra, cocina...). Con [arranging], todo se arrastra; un toque cambia
/// la forma y las sillas de una mesa, o el tamaño y el nombre de lo demás.
class FloorZone extends ConsumerStatefulWidget {
  const FloorZone({super.key, required this.zone, this.title = true, this.arranging = false});

  final String? zone;
  final bool title;
  final bool arranging;

  @override
  ConsumerState<FloorZone> createState() => _FloorZoneState();
}

class _FloorZoneState extends ConsumerState<FloorZone> {
  /// Mesa que se está arrastrando y dónde va (en puntos de diseño).
  String? _dragging;
  Offset _at = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final tables = store.tablesIn(widget.zone);
    final items = store.floorItemsIn(widget.zone);
    final free = tables.where((t) => store.openOrderOfTable(t.id) == null).length;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: GColors.fondo,
        borderRadius: BorderRadius.circular(GShape.radius),
        border: Border.all(
          color: widget.arranging ? GColors.cenote.withValues(alpha: 0.6) : GColors.linea,
          width: widget.arranging ? 1.5 : 1,
        ),
      ),
      child: CustomPaint(
        painter: const _TilesPainter(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.title || widget.arranging)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                child: Row(
                  children: [
                    Text(widget.zone ?? 'Salón', style: GText.sans(size: 15, weight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$free de ${tables.length} ${tables.length == 1 ? 'libre' : 'libres'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GText.sans(size: 12.5, weight: FontWeight.w600, color: GColors.tintaTenue),
                      ),
                    ),
                  ],
                ),
              ),
            // Al acomodar, los botones van en su propio renglón (en el celular no caben junto al nombre).
            if (widget.arranging)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Wrap(
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => _addItem(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Agregar'),
                    ),
                    if (tables.any((t) => t.placed))
                      TextButton.icon(
                        onPressed: () => _reset(context),
                        icon: const Icon(Icons.grid_view_rounded, size: 18),
                        label: const Text('Acomodar solas'),
                      ),
                  ],
                ),
              ),
            LayoutBuilder(
              builder: (context, box) {
                // Las que se acomodan solas llenan el ancho de la pantalla (hasta el del plano);
                // al acomodar se reserva el ancho completo y espacio abajo para mover las mesas.
                final placed = layoutZone(
                  tables,
                  width: widget.arranging ? kFloorWidth : box.maxWidth.clamp(300.0, kFloorWidth),
                  items: items,
                );
                final bounds = floorBounds(placed, items: items);
                final designW = widget.arranging ? kFloorWidth : math.max(bounds.width, 300.0);
                final designH = bounds.height + (widget.arranging ? 140 : 0);
                // Para ver, las mesas no se encogen de más (el texto se tiene que leer): si no caben, el plano
                // se desliza de lado. Para acomodar, cabe todo (arrastrar dentro de algo que se desliza confunde).
                final fit = box.maxWidth / designW;
                final scale = widget.arranging ? math.min(1.15, fit) : fit.clamp(0.75, 1.15);
                final canvas = SizedBox(
                  width: designW * scale,
                  height: designH * scale,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Primero lo del local (abajo) y encima las mesas.
                      for (final f in items) _positionedItem(context, f, scale),
                      for (final p in placed) _positioned(context, p, scale, dragging: _dragging == p.table.id),
                    ],
                  ),
                );
                return designW * scale > box.maxWidth + 0.5
                    ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: canvas)
                    : canvas;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _positioned(BuildContext context, PlacedTable p, double scale, {required bool dragging}) {
    final t = p.table;
    final rect = dragging ? (_at & p.rect.size) : p.rect;
    final store = ref.read(storeProvider);
    final drawing = TableDrawing(
      table: t,
      order: store.openOrderOfTable(t.id),
      arranging: widget.arranging,
      lifted: dragging,
    );
    return Positioned(
      left: rect.left * scale,
      top: rect.top * scale,
      width: rect.width * scale,
      height: rect.height * scale,
      child: !widget.arranging
          ? drawing
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _editTable(context, t),
              onPanStart: (_) => setState(() {
                _dragging = t.id;
                _at = p.rect.topLeft;
              }),
              onPanUpdate: (d) => setState(() => _at += d.delta / scale),
              onPanEnd: (_) {
                final spot = snapTable(_at, p.rect.size);
                ref.read(storeProvider.notifier).placeTable(t.id, spot.x, spot.y);
                setState(() => _dragging = null);
              },
              onPanCancel: () => setState(() => _dragging = null),
              child: MouseRegion(cursor: SystemMouseCursors.grab, child: drawing),
            ),
    );
  }

  Widget _positionedItem(BuildContext context, FloorItem f, double scale) {
    final dragging = _dragging == f.id;
    final rect = dragging ? (_at & itemRect(f).size) : itemRect(f);
    final drawing = FloorItemDrawing(item: f, lifted: dragging, editable: widget.arranging);
    return Positioned(
      left: rect.left * scale,
      top: rect.top * scale,
      width: rect.width * scale,
      height: rect.height * scale,
      child: !widget.arranging
          ? IgnorePointer(child: drawing)
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showGSheet<void>(context, (_) => _FloorItemSheet(itemId: f.id)),
              onPanStart: (_) => setState(() {
                _dragging = f.id;
                _at = itemRect(f).topLeft;
              }),
              onPanUpdate: (d) => setState(() => _at += d.delta / scale),
              onPanEnd: (_) {
                final spot = snapTable(_at, itemRect(f).size);
                ref.read(storeProvider.notifier).moveFloorItem(f.id, spot.x, spot.y);
                setState(() => _dragging = null);
              },
              onPanCancel: () => setState(() => _dragging = null),
              child: MouseRegion(cursor: SystemMouseCursors.grab, child: drawing),
            ),
    );
  }

  Future<void> _addItem(BuildContext context) async {
    final kind = await showGSheet<FloorItemKind>(
      context,
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader('Agregar al plano', caption: widget.zone ?? 'Salón'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final k in FloorItemKind.values)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(ctx).pop(k),
                  child: Container(
                    width: 104,
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                    decoration: BoxDecoration(
                      color: GColors.fondo,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: GColors.linea),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 80,
                          height: 44,
                          child: FittedBox(
                            child: SizedBox(
                              width: k.width.toDouble(),
                              height: k.height.toDouble(),
                              child: FloorItemDrawing(
                                item: FloorItem(id: '', kind: k, x: 0, y: 0, width: k.width, height: k.height),
                                showName: false,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(k.label, style: GText.sans(size: 13, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (kind != null) ref.read(storeProvider.notifier).addFloorItem(widget.zone, kind);
  }

  Future<void> _reset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Acomodar solas las mesas de ${widget.zone ?? 'Salón'}?'),
        content: const Text('Vuelven a ponerse en filas. Su forma y sus sillas no cambian.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Acomodar')),
        ],
      ),
    );
    if (ok == true) ref.read(storeProvider.notifier).resetLayout(widget.zone);
  }

  Future<void> _editTable(BuildContext context, DiningTable t) =>
      showGSheet<void>(context, (_) => _TableShapeSheet(tableId: t.id));
}

/// Forma y sillas de una mesa.
class _TableShapeSheet extends ConsumerWidget {
  const _TableShapeSheet({required this.tableId});

  final String tableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(storeProvider).tableById(tableId);
    if (t == null) return const SizedBox.shrink();
    final store = ref.read(storeProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(t.name, caption: 'Cómo se ve en el plano'),
        const SizedBox(height: 10),
        Center(
          child: SizedBox.fromSize(
            size: tableSize(t.shape, t.seats) * 1.1,
            child: CustomPaint(
              painter: TablePainter(shape: t.shape, seats: t.seats, busy: false),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text('Forma', style: GText.label()),
        const SizedBox(height: 6),
        SegmentedButton<TableShape>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: TableShape.cuadrada, icon: Icon(Icons.crop_square_rounded), label: Text('Cuadrada')),
            ButtonSegment(value: TableShape.redonda, icon: Icon(Icons.circle_outlined), label: Text('Redonda')),
          ],
          selected: {t.shape},
          onSelectionChanged: (v) => store.shapeTable(t.id, shape: v.first),
        ),
        const SizedBox(height: 14),
        Text('Sillas', style: GText.label()),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final n in const [2, 4, 6, 8, 10, 12])
              ChoiceChip(
                label: Text('$n'),
                selected: t.seats == n,
                onSelected: (_) => store.shapeTable(t.id, seats: n),
              ),
          ],
        ),
        const SizedBox(height: 16),
        GButton(label: 'Listo', expand: true, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// Líneas finas cada 28 px, como el piso de mosaico de las fondas.
class _TilesPainter extends CustomPainter {
  const _TilesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = GColors.linea.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var x = 28.0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 28.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_TilesPainter old) => false;
}

/// Una mesa vista desde arriba con sus sillas y, encima, su nombre, el total y el tiempo.
/// Ocupada en achiote; libre en blanco. Fuera de "Acomodar", un toque abre la cuenta (o una nueva).
class TableDrawing extends ConsumerWidget {
  const TableDrawing({super.key, required this.table, this.order, this.arranging = false, this.lifted = false});

  final DiningTable table;
  final RestaurantOrder? order;
  final bool arranging;

  /// Se está arrastrando: se ve levantada.
  final bool lifted;

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
    final total = busy ? store.totalOfOrder(o.id) : 0;
    final label = busy
        ? '${table.name}, ocupada: ${money(total)}, desde hace ${elapsedLabel(o.createdAt)}'
              '${ready > 0 ? ', $ready listos en cocina' : ''}'
        : '${table.name}, libre';
    final round = table.shape == TableShape.redonda;

    final picture = Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: TablePainter(shape: table.shape, seats: table.seats, busy: busy, lifted: lifted),
          ),
        ),
        Positioned.fill(
          child: FractionallySizedBox(
            widthFactor: round ? 0.6 : 0.7,
            heightFactor: round ? 0.5 : 0.56,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      table.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GText.sans(size: 13, weight: FontWeight.w800),
                    ),
                  ),
                  if (arranging)
                    Text(
                      '${table.seats} ${table.seats == 1 ? 'silla' : 'sillas'}',
                      style: GText.sans(size: 11.5, weight: FontWeight.w600, color: GColors.tintaSuave),
                    )
                  else if (busy) ...[
                    Text(
                      money(total),
                      style: GText.figures(size: 14, weight: FontWeight.w800, color: GColors.marcaOscura),
                    ),
                    Text(elapsedLabel(o.createdAt), maxLines: 1, style: GText.muted(size: 11)),
                  ] else
                    Text(
                      'Libre',
                      style: GText.sans(size: 12, weight: FontWeight.w600, color: GColors.tintaTenue),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!arranging && (ready > 0 || cooking))
          Positioned(
            top: 4,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: ready > 0 ? GColors.cenote : GColors.hundido,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                ready > 0 ? '$ready ${ready == 1 ? 'listo' : 'listos'}' : 'en cocina',
                style: GText.sans(
                  size: 10.5,
                  weight: FontWeight.w800,
                  color: ready > 0 ? Colors.white : GColors.tintaSuave,
                ),
              ),
            ),
          ),
      ],
    );

    return Semantics(
      button: true,
      label: arranging ? '${table.name}, ${table.seats} sillas. Arrastra para moverla' : label,
      excludeSemantics: true,
      child: arranging
          ? picture
          : Pressable(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => busy ? OrderScreen(orderId: o.id) : OrderScreen(tableId: table.id),
                ),
              ),
              scale: 0.95,
              child: picture,
            ),
    );
  }
}

/// Dibujo de la mesa y sus sillas, en un lienzo del tamaño que da [tableSize] (se escala para caber).
class TablePainter extends CustomPainter {
  const TablePainter({required this.shape, required this.seats, required this.busy, this.lifted = false});

  final TableShape shape;
  final int seats;
  final bool busy;
  final bool lifted;

  @override
  void paint(Canvas canvas, Size size) {
    final design = tableSize(shape, seats);
    final k = math.min(size.width / design.width, size.height / design.height);
    canvas.translate((size.width - design.width * k) / 2, (size.height - design.height * k) / 2);
    canvas.scale(k);

    final chair = Paint()..color = busy ? GColors.marca.withValues(alpha: 0.55) : GColors.linea;
    for (final c in chairSpots(shape, seats, design)) {
      final rect = Rect.fromCenter(center: c.center, width: c.sideways ? 12 : 24, height: c.sideways ? 24 : 12);
      if (shape == TableShape.redonda) {
        canvas.drawCircle(c.center, 8, chair);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), chair);
      }
    }

    final fill = Paint()..color = busy ? GColors.marcaSuave : GColors.superficie;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = busy ? GColors.marca : (lifted ? GColors.cenote : GColors.linea);
    final Path top;
    if (shape == TableShape.redonda) {
      top = Path()..addOval(Rect.fromCircle(center: design.center(Offset.zero), radius: design.width / 2 - 18));
    } else {
      top = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(18, 20, design.width - 18, design.height - 20),
            const Radius.circular(12),
          ),
        );
    }
    if (lifted) canvas.drawShadow(top, Colors.black, 6, false);
    canvas.drawPath(top, fill);
    canvas.drawPath(top, stroke);
  }

  @override
  bool shouldRepaint(TablePainter old) =>
      old.shape != shape || old.seats != seats || old.busy != busy || old.lifted != lifted;
}

/// Tamaño, nombre, girar o quitar una pared, puerta, barra...
class _FloorItemSheet extends ConsumerStatefulWidget {
  const _FloorItemSheet({required this.itemId});

  final String itemId;

  @override
  ConsumerState<_FloorItemSheet> createState() => _FloorItemSheetState();
}

class _FloorItemSheetState extends ConsumerState<_FloorItemSheet> {
  late final _name = TextEditingController(text: ref.read(storeProvider).floorItemById(widget.itemId)?.label ?? '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(storeProvider).floorItemById(widget.itemId);
    if (f == null || !f.active) return const SizedBox.shrink();
    final store = ref.read(storeProvider.notifier);
    // Largo de una pared o ventana; tamaño de lo demás (proporcional al de inicio).
    final horizontal = f.width >= f.height;
    final long = horizontal ? f.width : f.height;
    final thick = horizontal ? f.height : f.width;
    void setLong(int v) => horizontal ? store.resizeFloorItem(f.id, v, thick) : store.resizeFloorItem(f.id, thick, v);
    final base = f.kind.width >= f.kind.height
        ? (f.kind.width.toDouble(), f.kind.height.toDouble())
        : (f.kind.height.toDouble(), f.kind.width.toDouble());
    final factor = (horizontal ? f.width : f.height) / base.$1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(f.title, caption: 'Cómo se ve en el plano'),
        if (f.kind.named) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            maxLength: 30,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Nombre', hintText: f.kind.label, counterText: ''),
            onChanged: (v) => store.renameFloorItem(f.id, v),
          ),
        ],
        const SizedBox(height: 12),
        Text(f.kind.isLine ? 'Largo' : 'Tamaño', style: GText.label()),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: f.kind.isLine
              ? [
                  for (final (label, v) in const [
                    ('Corta', 120),
                    ('Media', 300),
                    ('Larga', 600),
                    ('Todo el ancho', 900),
                  ])
                    ChoiceChip(label: Text(label), selected: long == v, onSelected: (_) => setLong(v)),
                ]
              : [
                  for (final (label, k) in const [
                    ('Chica', 0.7),
                    ('Mediana', 1.0),
                    ('Grande', 1.5),
                    ('Muy grande', 2.0),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: (factor - k).abs() < 0.05,
                      onSelected: (_) {
                        final w = (base.$1 * k).round(), h = (base.$2 * k).round();
                        horizontal ? store.resizeFloorItem(f.id, w, h) : store.resizeFloorItem(f.id, h, w);
                      },
                    ),
                ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GButton(
                label: 'Girar',
                icon: Icons.rotate_90_degrees_ccw_rounded,
                kind: GButtonKind.outline,
                expand: true,
                onPressed: () => store.rotateFloorItem(f.id),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GButton(
                label: 'Quitar',
                icon: Icons.delete_outline_rounded,
                kind: GButtonKind.outline,
                expand: true,
                onPressed: () {
                  store.removeFloorItem(f.id);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GButton(label: 'Listo', expand: true, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// Dibujo de una pared, puerta, ventana, barra, cocina, baños o caja, visto desde arriba.
class FloorItemDrawing extends StatelessWidget {
  const FloorItemDrawing({
    super.key,
    required this.item,
    this.lifted = false,
    this.editable = false,
    this.showName = true,
  });

  final FloorItem item;
  final bool lifted;

  /// Se está acomodando: un borde punteado dice que se puede mover.
  final bool editable;
  final bool showName;

  static const _icons = {
    FloorItemKind.cocina: Icons.soup_kitchen_outlined,
    FloorItemKind.bano: Icons.wc_rounded,
    FloorItemKind.caja: Icons.point_of_sale_rounded,
    FloorItemKind.barra: Icons.local_bar_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final k = item.kind;
    return Semantics(
      label: editable ? '${item.title}. Arrastra para moverla' : item.title,
      excludeSemantics: true,
      child: CustomPaint(
        painter: _FloorItemPainter(kind: k, lifted: lifted, editable: editable),
        child: !k.named || !showName
            ? const SizedBox.expand()
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    // En una barra parada, el nombre también va de lado, como en un plano.
                    child: RotatedBox(
                      quarterTurns: item.height > item.width * 1.5 ? 3 : 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_icons[k], size: 16, color: _ink(k)),
                          const SizedBox(width: 4),
                          Text(
                            item.title,
                            style: GText.sans(size: 13, weight: FontWeight.w800, color: _ink(k)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  static Color _ink(FloorItemKind k) => k == FloorItemKind.barra ? Colors.white : GColors.tintaSuave;
}

class _FloorItemPainter extends CustomPainter {
  const _FloorItemPainter({required this.kind, required this.lifted, required this.editable});

  final FloorItemKind kind;
  final bool lifted;
  final bool editable;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    if (lifted) canvas.drawShadow(Path()..addRRect(rr), Colors.black, 6, false);
    switch (kind) {
      case FloorItemKind.pared:
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), Paint()..color = GColors.tintaSuave);
      case FloorItemKind.ventana:
        canvas.drawRect(rect, Paint()..color = const Color(0xFFD6ECF3));
        final line = Paint()
          ..color = const Color(0xFF6FA8BC)
          ..strokeWidth = 1.5;
        final horizontal = size.width >= size.height;
        canvas.drawRect(rect, line..style = PaintingStyle.stroke);
        if (horizontal) {
          canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), line);
        } else {
          canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), line);
        }
      case FloorItemKind.puerta:
        // La hoja de la puerta y el arco por donde abre.
        final ink = Paint()
          ..color = GColors.cafe
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        final r = math.min(size.width, size.height);
        canvas.drawLine(Offset(0, size.height), Offset(0, size.height - r), ink..strokeWidth = 3);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(0, size.height), radius: r),
          -math.pi / 2,
          math.pi / 2,
          false,
          ink
            ..strokeWidth = 1.5
            ..color = GColors.cafe.withValues(alpha: 0.6),
        );
        canvas.drawLine(
          Offset(0, size.height),
          Offset(r, size.height),
          Paint()
            ..color = GColors.fondo
            ..strokeWidth = 6,
        );
      case FloorItemKind.barra:
        canvas.drawRRect(rr, Paint()..color = GColors.cafe);
        canvas.drawRRect(
          rr.deflate(4),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      case FloorItemKind.cocina:
        canvas.drawRRect(rr, Paint()..color = GColors.hundido);
        // Rayado, como se marcan las áreas de servicio en un plano.
        canvas.save();
        canvas.clipRRect(rr);
        final hatch = Paint()
          ..color = GColors.linea
          ..strokeWidth = 1.5;
        for (var x = -size.height; x < size.width; x += 14) {
          canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), hatch);
        }
        canvas.restore();
        canvas.drawRRect(
          rr,
          Paint()
            ..color = GColors.tintaTenue
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      case FloorItemKind.bano:
      case FloorItemKind.caja:
        canvas.drawRRect(rr, Paint()..color = GColors.superficie);
        canvas.drawRRect(
          rr,
          Paint()
            ..color = GColors.tintaTenue
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
    }
    if (editable && (kind == FloorItemKind.pared || kind == FloorItemKind.ventana || kind == FloorItemKind.puerta)) {
      // Las líneas finas son difíciles de ver al acomodar: un contorno claro marca dónde agarrarlas.
      canvas.drawRRect(
        rr.inflate(2),
        Paint()
          ..color = GColors.cenote.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_FloorItemPainter old) => old.kind != kind || old.lifted != lifted || old.editable != editable;
}
