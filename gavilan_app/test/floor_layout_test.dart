import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/domain/floor_layout.dart';
import 'package:gavilan/domain/restaurant.dart';

/// El plano de mesas: tamaños, acomodo solo, acomodo a mano y dónde van las sillas.
void main() {
  DiningTable t(String id, {int? x, int? y, TableShape shape = TableShape.cuadrada, int seats = 4}) =>
      DiningTable(id: id, name: 'Mesa $id', x: x, y: y, shape: shape, seats: seats);

  test('tamaño: cuadrada de 4 a 6 sillas, más larga con más; redonda crece poco', () {
    expect(tableSize(TableShape.cuadrada, 4), const Size(132, 112));
    expect(tableSize(TableShape.cuadrada, 6), const Size(132, 112));
    expect(tableSize(TableShape.cuadrada, 10).width, greaterThan(132));
    expect(tableSize(TableShape.redonda, 4), const Size(120, 120));
    expect(tableSize(TableShape.redonda, 8).width, 152);
  });

  test('sin acomodar: en filas que caben en el ancho', () {
    final p = layoutZone([for (var i = 0; i < 8; i++) t('$i')], width: 600);
    // 132 + 18 de espacio: caben 3 en 600 (132*4 + 18*3 = 582 también cabe: 4).
    expect(p.where((x) => x.rect.top == 0), hasLength(4));
    expect(p[4].rect.topLeft, const Offset(0, 130));
    expect(floorBounds(p), Size(132 * 4 + 18 * 3, 112 * 2 + 18));
  });

  test('acomodadas a mano van donde las pusieron; las demás, en una fila abajo', () {
    final p = layoutZone([t('a', x: 300, y: 40), t('b'), t('c', x: 0, y: 0, shape: TableShape.redonda)]);
    expect(p.firstWhere((x) => x.table.id == 'a').rect.topLeft, const Offset(300, 40));
    expect(p.firstWhere((x) => x.table.id == 'c').rect.size, const Size(120, 120));
    expect(p.firstWhere((x) => x.table.id == 'b').rect.top, 40 + 112 + 18);
  });

  test('al soltar: pegada a la cuadrícula de 10 y sin salirse del plano', () {
    expect(snapTable(const Offset(123, 47), const Size(132, 112)), (x: 120, y: 50));
    expect(snapTable(const Offset(-30, -9), const Size(132, 112)), (x: 0, y: 0));
    expect(snapTable(const Offset(2000, 10), const Size(132, 112)).x, 770);
  });

  test('sillas: tantas como diga la mesa, a los lados y arriba y abajo', () {
    const size = Size(132, 112);
    final four = chairSpots(TableShape.cuadrada, 4, size);
    expect(four, hasLength(4));
    expect(four.where((c) => c.sideways), hasLength(2));
    expect(chairSpots(TableShape.cuadrada, 2, size).every((c) => c.sideways), isTrue);
    expect(chairSpots(TableShape.cuadrada, 8, tableSize(TableShape.cuadrada, 8)), hasLength(8));
    final round = chairSpots(TableShape.redonda, 6, const Size(136, 136));
    expect(round, hasLength(6));
    // La primera arriba, al centro.
    expect(round.first.center.dx, closeTo(68, 0.01));
    expect(round.first.center.dy, closeTo(8, 0.01));
  });
}
