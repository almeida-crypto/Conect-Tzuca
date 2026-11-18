import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/core/ticket_html.dart';
import 'package:gavilan/domain/restaurant.dart';

/// La comanda impresa para la cocina.
void main() {
  test('la comanda trae la mesa, los platillos, sus extras e indicaciones, sin precios', () {
    final at = DateTime(2026, 11, 18, 14, 5);
    final html = comandaHtml(
      business: 'Cocina <Doña> Mary',
      place: 'Mesa 4',
      items: [
        OrderItem(
          id: 'a',
          orderId: 'o',
          name: 'Tacos de pastor',
          qty: 3,
          unitCents: 2000,
          createdAt: at,
          sentAt: at,
          extras: const [ItemExtra('Extra queso', 1000)],
          notes: 'sin cebolla',
        ),
        OrderItem(id: 'b', orderId: 'o', name: 'Horchata', qty: 1, unitCents: 3000, createdAt: at, sentAt: at),
      ],
    );
    expect(html, contains('<h1>Mesa 4</h1>'));
    expect(html, contains('Comanda · 14:05'));
    expect(html, contains('Tacos de pastor'));
    expect(html, contains('+ Extra queso'));
    expect(html, contains('** sin cebolla **'));
    expect(html, contains('2 platillos'));
    expect(html, contains('Cocina &lt;Doña&gt; Mary')); // escapado
    expect(html, isNot(contains(r'$')));
  });
}
