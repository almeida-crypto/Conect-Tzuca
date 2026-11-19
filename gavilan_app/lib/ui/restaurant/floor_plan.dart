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

/// Una zona del salón dibujada desde arriba, sobre piso de mosaico, con las mesas donde las acomodaron.
/// Con [arranging], las mesas se arrastran y un toque cambia su forma y sus sillas.
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
                        style: GText.sans(size: 12.5, weight: FontWeight.w600, color: GColors.tintaTenue),
                      ),
                    ),
                    if (widget.arranging && tables.any((t) => t.placed))
                      TextButton(onPressed: () => _reset(context), child: const Text('Acomodar solas')),
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
                );
                final bounds = floorBounds(placed);
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
