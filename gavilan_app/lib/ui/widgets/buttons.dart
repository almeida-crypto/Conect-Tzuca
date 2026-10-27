import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/theme.dart';

enum GButtonKind { primary, money, outline, dark }

/// Botón con borde inferior grueso, como una tecla que se aprieta.
class GButton extends StatefulWidget {
  const GButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = GButtonKind.primary,
    this.icon,
    this.expand = false,
    this.big = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final GButtonKind kind;
  final IconData? icon;
  final bool expand;
  final bool big;

  @override
  State<GButton> createState() => _GButtonState();
}

class _GButtonState extends State<GButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, edge) = switch (widget.kind) {
      GButtonKind.primary => (GColors.oxido, GColors.papel, GColors.oxidoOscuro),
      GButtonKind.money => (GColors.monte, GColors.papel, GColors.monteOscuro),
      GButtonKind.dark => (GColors.tinta, GColors.papel, Colors.black),
      GButtonKind.outline => (GColors.papel, GColors.tinta, GColors.tinta),
    };
    final outline = widget.kind == GButtonKind.outline;
    final edgeWidth = _down ? 1.0 : 3.0;
    final disabled = widget.onPressed == null;
    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[Icon(widget.icon, size: 19, color: fg), const SizedBox(width: 8)],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: GText.sans(size: widget.big ? 17 : 15, weight: FontWeight.w800, color: fg),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      child: GestureDetector(
        onTapDown: widget.onPressed == null ? null : (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        // Dos capas: la de abajo es el borde grueso de "tecla"; al apretar, la de arriba baja.
        child: Opacity(
          opacity: disabled ? 0.45 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 70),
            margin: EdgeInsets.only(top: 3 - edgeWidth),
            padding: EdgeInsets.only(bottom: edgeWidth),
            decoration: BoxDecoration(color: edge, borderRadius: BorderRadius.circular(4)),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: widget.big ? 22 : 16, vertical: widget.big ? 13 : 11),
              decoration: BoxDecoration(
                color: outline ? GColors.papel : bg,
                borderRadius: BorderRadius.circular(4),
                border: outline ? Border.all(color: GColors.tinta, width: 1.5) : null,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opción tipo "ficha" seleccionable (montos rápidos, métodos de pago).
class GChip extends StatelessWidget {
  const GChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? GColors.tinta : Colors.transparent,
            border: Border.all(color: GColors.tinta),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GText.sans(size: 14, weight: FontWeight.w800, color: selected ? GColors.papel : GColors.tinta),
          ),
        ),
      ),
    );
  }
}
