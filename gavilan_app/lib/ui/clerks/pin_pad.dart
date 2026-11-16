import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/clerk.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';

/// Cuatro puntos y un teclado de números. En la computadora también se teclea con los números del teclado.
///
/// [onComplete] recibe el PIN al poner la cuarta cifra; si regresa false, los puntos tiemblan y se borra.
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onComplete, this.enabled = true});

  final bool Function(String pin) onComplete;
  final bool enabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  final _focus = FocusNode(debugLabel: 'PIN');

  @override
  void dispose() {
    _shake.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add(String digit) {
    if (!widget.enabled || _pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      final pin = _pin;
      // Que se alcance a ver el cuarto punto antes de revisar.
      Future<void>.delayed(const Duration(milliseconds: 90), () {
        if (!mounted) return;
        final ok = widget.onComplete(pin);
        if (!mounted) return;
        if (!ok) {
          HapticFeedback.heavyImpact();
          _shake.forward(from: 0);
        }
        setState(() => _pin = '');
      });
    }
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final ch = e.character;
    if (ch != null && RegExp(r'^\d$').hasMatch(ch)) {
      _add(ch);
      return KeyEventResult.handled;
    }
    final k = e.logicalKey;
    final numpad = {
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    }[k];
    if (numpad != null) {
      _add(numpad);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.delete) {
      _back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _shake,
            builder: (context, child) => Transform.translate(
              offset: Offset(sin(_shake.value * pi * 6) * 10 * (1 - _shake.value), 0),
              child: child,
            ),
            child: Semantics(
              label: 'PIN: ${_pin.length} de 4 cifras',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 4; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.symmetric(horizontal: 9),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length ? GColors.cenote : Colors.transparent,
                        border: Border.all(color: i < _pin.length ? GColors.cenote : GColors.tintaTenue, width: 2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', '<'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final key in row)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: key.isEmpty
                          ? const SizedBox(width: 76, height: 58)
                          : _Key(
                              label: key,
                              enabled: widget.enabled,
                              onTap: () {
                                _focus.requestFocus();
                                key == '<' ? _back() : _add(key);
                              },
                            ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap, required this.enabled});

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final back = label == '<';
    return Semantics(
      button: true,
      label: back ? 'Borrar' : label,
      excludeSemantics: true,
      child: Pressable(
        onTap: enabled ? onTap : null,
        scale: 0.9,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1 : 0.4,
          child: Container(
            width: 76,
            height: 58,
            alignment: Alignment.center,
            decoration: back ? null : GShape.card(radius: 18),
            child: back
                ? const Icon(Icons.backspace_outlined, size: 22, color: GColors.tintaSuave)
                : Text(label, style: GText.figures(size: 24, weight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

/// Círculo con la inicial; el color dice qué puede hacer (dueño achiote, encargado cenote, cajero café).
class ClerkAvatar extends StatelessWidget {
  const ClerkAvatar({super.key, required this.clerk, this.size = 44});

  final Clerk clerk;
  final double size;

  static Color colorOf(ClerkRole role) => switch (role) {
    ClerkRole.dueno => GColors.marca,
    ClerkRole.encargado => GColors.cenote,
    ClerkRole.cajero => GColors.cafe,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(clerk.role);
    final initial = clerk.name.isEmpty ? '?' : clerk.name.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
      child: Text(
        initial,
        style: GText.sans(size: size * 0.42, weight: FontWeight.w800, color: color),
      ),
    );
  }
}
