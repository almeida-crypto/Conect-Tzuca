import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/theme.dart';

/// Lista de atajos de teclado del mostrador (F1).
Future<void> showShortcutsHelp(BuildContext context) {
  const items = [
    ('F2', 'Cobrar la cuenta'),
    ('Esc', 'Borrar la búsqueda o vaciar la cuenta'),
    ('+  −', 'Cambiar la cantidad del último producto'),
    ('F3', 'Venta rápida por monto'),
    ('Escribe', 'Buscar sin dar clic; Enter lo agrega'),
    ('Lector', 'Pasa el código: entra solo a la cuenta'),
    ('Al cobrar', 'Escribe con cuánto paga y da Enter'),
    ('Ticket', 'Enter: nueva venta · P: imprimir'),
  ];
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Atajos de teclado', style: GText.sans(size: 18, weight: FontWeight.w800)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (k, what) in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Align(alignment: Alignment.centerLeft, child: KeyCap(k)),
                    ),
                    Expanded(child: Text(what, style: GText.sans(size: 14))),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Listo'))],
    ),
  );
}

/// Tecla dibujada, para enseñar atajos.
class KeyCap extends StatelessWidget {
  const KeyCap(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: GColors.superficie,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: GColors.linea),
        boxShadow: const [BoxShadow(color: GColors.linea, offset: Offset(0, 2))],
      ),
      child: Text(
        label,
        style: GText.sans(size: 12, weight: FontWeight.w800, color: GColors.tintaSuave),
      ),
    );
  }
}
