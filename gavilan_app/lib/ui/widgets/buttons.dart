import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/colors.dart';
import '../../theme/theme.dart';

enum GButtonKind {
  /// Achiote: la acción principal de la pantalla.
  primary,

  /// Cenote: cobrar, abonar, todo lo que mueve dinero.
  money,

  /// Blanco con borde: acciones secundarias.
  outline,

  /// Tinta: acciones fuertes sobre fondos claros (escáner, "darlo de alta").
  dark,
}

/// Se encoge un poco al apretarlo y regresa con rebote: se siente que respondió.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.96});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 90 : 260),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

class GButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      GButtonKind.primary => (GColors.marca, Colors.white),
      GButtonKind.money => (GColors.cenote, Colors.white),
      GButtonKind.dark => (GColors.tinta, Colors.white),
      GButtonKind.outline => (GColors.superficie, GColors.tinta),
    };
    final outline = kind == GButtonKind.outline;
    final disabled = onPressed == null;
    return Semantics(
      button: true,
      enabled: !disabled,
      child: Pressable(
        onTap: onPressed,
        scale: 0.97,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: disabled ? 0.45 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(horizontal: big ? 22 : 16, vertical: big ? 16 : 13),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(GShape.radius),
              border: outline ? Border.all(color: GColors.linea, width: 1.5) : null,
              boxShadow: outline || disabled
                  ? null
                  : [BoxShadow(color: bg.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: big ? 21 : 19, color: fg), const SizedBox(width: 8)],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: GText.sans(size: big ? 17 : 15, weight: FontWeight.w700, color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opción seleccionable (montos rápidos, métodos de pago, filtros).
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
      child: Pressable(
        onTap: onTap,
        scale: 0.95,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? GColors.tinta : GColors.superficie,
            border: Border.all(color: selected ? GColors.tinta : GColors.linea, width: 1.5),
            borderRadius: BorderRadius.circular(GShape.radiusSmall),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GText.sans(size: 14, weight: FontWeight.w700, color: selected ? Colors.white : GColors.tinta),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}
