import 'package:flutter/material.dart';

import '../../core/ticket_text.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';

/// Campo para escribir dinero, con el signo de pesos y números grandes.
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    this.label,
    this.hint = '0.00',
    this.error,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? label;
  final String hint;
  final String? error;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GText.amount(size: 22),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, prefixText: '\$ ', hintText: hint, errorText: error),
    );
  }
}

/// Barra de avance gruesa: óxido mientras falta, verde monte al completarse.
class ProgressStrip extends StatelessWidget {
  const ProgressStrip({super.key, required this.fraction, this.height = 10});

  final double fraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: GColors.hundido,
        border: Border.all(color: GColors.linea),
        borderRadius: BorderRadius.circular(GShape.radiusSmall),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: f,
        child: Container(color: f >= 1 ? GColors.cenote : GColors.marca),
      ),
    );
  }
}

String dayLabel(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

/// "en 3 días", "hoy", "venció hace 2 días".
String dueLabel(DateTime due, DateTime now) {
  final days = DateTime(due.year, due.month, due.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days == 0) return 'vence hoy';
  if (days == 1) return 'vence mañana';
  if (days > 1) return 'vence en $days días';
  if (days == -1) return 'venció ayer';
  return 'venció hace ${-days} días';
}

/// Selector de fecha en español con los colores de la app.
Future<DateTime?> pickDay(BuildContext context, {DateTime? initial, DateTime? first}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: first ?? DateTime(now.year - 1),
    lastDate: DateTime(now.year + 2),
  );
}

/// Pantalla vacía que invita a empezar.
class EmptyInvite extends StatelessWidget {
  const EmptyInvite({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 20),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GText.sans(size: 17, weight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: GText.muted(size: 14)),
        ],
      ),
    );
  }
}
