// Plano de mesas: tamaño de cada mesa según su forma y sillas, y dónde va en el dibujo de su zona.
// Las medidas son "puntos de diseño"; la pantalla las escala para que quepan.
import 'dart:math' as math;
import 'dart:ui';

import 'restaurant.dart';

/// Ancho que se reserva para el plano al acomodar (seis mesas cuadradas en fila).
const kFloorWidth = 900.0;

/// Cada cuánto se "pega" una mesa al soltarla, para que queden alineadas.
const kFloorSnap = 10;

/// Espacio entre mesas cuando se acomodan solas.
const _gap = 18.0;

/// Tamaño de la mesa con sus sillas: cuadrada de 4 a 6 sillas, más larga si lleva más; redonda, un círculo.
Size tableSize(TableShape shape, int seats) {
  if (shape == TableShape.redonda) {
    final d = seats <= 4 ? 120.0 : 120.0 + (seats - 4) * 8;
    return Size(d, d);
  }
  final perSide = math.max(2, ((seats - 2) / 2).ceil());
  return Size(math.max(132, 36.0 + perSide * 40), 112);
}

/// Una mesa ya acomodada: su rectángulo en el plano de la zona.
class PlacedTable {
  const PlacedTable(this.table, this.rect);

  final DiningTable table;
  final Rect rect;
}

/// Rectángulo de una pared, barra... en el plano.
Rect itemRect(FloorItem f) => Rect.fromLTWH(f.x.toDouble(), f.y.toDouble(), f.width.toDouble(), f.height.toDouble());

/// Acomoda las mesas de una zona: las que tienen lugar van donde las pusieron; las demás, en filas.
/// Si ya hay mesas puestas (o paredes, barra...), las que faltan van en una fila abajo de ellas.
List<PlacedTable> layoutZone(List<DiningTable> tables, {double width = kFloorWidth, List<FloorItem> items = const []}) {
  final placed = <PlacedTable>[];
  var bottom = 0.0;
  for (final f in items) {
    bottom = math.max(bottom, itemRect(f).bottom + _gap);
  }
  for (final t in tables.where((t) => t.placed)) {
    final s = tableSize(t.shape, t.seats);
    final r = Rect.fromLTWH(t.x!.toDouble(), t.y!.toDouble(), s.width, s.height);
    placed.add(PlacedTable(t, r));
    bottom = math.max(bottom, r.bottom + _gap);
  }
  var x = 0.0, y = bottom, row = 0.0;
  for (final t in tables.where((t) => !t.placed)) {
    final s = tableSize(t.shape, t.seats);
    if (x > 0 && x + s.width > width) {
      x = 0;
      y += row + _gap;
      row = 0;
    }
    placed.add(PlacedTable(t, Rect.fromLTWH(x, y, s.width, s.height)));
    x += s.width + _gap;
    row = math.max(row, s.height);
  }
  return placed;
}

/// Lo que ocupa todo el plano de la zona (mesas y lo dibujado).
Size floorBounds(List<PlacedTable> tables, {List<FloorItem> items = const []}) {
  var w = 0.0, h = 0.0;
  for (final r in [for (final p in tables) p.rect, for (final f in items) itemRect(f)]) {
    w = math.max(w, r.right);
    h = math.max(h, r.bottom);
  }
  return Size(w, h);
}

/// Al soltar una mesa: pegada a la cuadrícula y sin salirse del plano.
({int x, int y}) snapTable(Offset topLeft, Size size, {double width = kFloorWidth}) {
  int snap(double v) => (v / kFloorSnap).round() * kFloorSnap;
  final maxX = math.max(0.0, width - size.width);
  return (x: snap(topLeft.dx.clamp(0, maxX)), y: snap(math.max(0, topLeft.dy)));
}

/// Dónde van las sillas (centro y si va acostada), en un lienzo del tamaño de la mesa.
List<({Offset center, bool sideways})> chairSpots(TableShape shape, int seats, Size size) {
  if (shape == TableShape.redonda) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    return [
      for (var i = 0; i < seats; i++)
        (
          center:
              c +
              Offset(
                    math.cos(-math.pi / 2 + i * 2 * math.pi / seats),
                    math.sin(-math.pi / 2 + i * 2 * math.pi / seats),
                  ) *
                  r,
          sideways: false,
        ),
    ];
  }
  // Una a cada lado (cabeceras) y las demás repartidas arriba y abajo.
  final ends = seats >= 3 ? 2 : seats;
  final rest = seats - ends;
  final top = (rest / 2).ceil();
  final bottom = rest - top;
  List<Offset> along(int n, double y) => [
    for (var i = 0; i < n; i++) Offset(18 + (size.width - 36) * (i + 0.5) / n, y),
  ];
  return [
    for (final o in along(top, 10)) (center: o, sideways: false),
    for (final o in along(bottom, size.height - 10)) (center: o, sideways: false),
    if (ends >= 1) (center: Offset(8, size.height / 2), sideways: true),
    if (ends >= 2) (center: Offset(size.width - 8, size.height / 2), sideways: true),
  ];
}
