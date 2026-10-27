import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/theme.dart';
import 'hawk.dart';
import 'yucatan_painters.dart';

/// Inicio: el gavilán cruza planeando y deja escrito el nombre.
/// Línea de tiempo (segundos), igual que la maqueta:
///   0.3–2.7  vuelo (aletea 2 veces y planea); el nombre se revela detrás de la cola
///   2.3–3.2  greca · 2.6 lema · 2.9 hipil · 3.1 pie · 4.8 entra a la app
/// Un toque salta el inicio.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _total = 4.8;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800));
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
    _c.forward();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Avance 0..1 de un tramo [start, end] en segundos, con curva opcional.
  double _span(double t, double start, double end, [Curve curve = Curves.linear]) =>
      curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: GColors.papel,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: LayoutBuilder(
          builder: (context, box) {
            // Diseñado para 302 px de ancho; en pantallas grandes no crece sin control.
            final k = (box.maxWidth / 302).clamp(0.8, 1.6);
            return AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = reduceMotion ? _total : _c.value * _total;
                return _frame(t, k, box.biggest);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _frame(double t, double k, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Vuelo: entra por la izquierda y sale 28 px después del borde derecho.
    final s = _span(t, 0.3, 2.7);
    final hawkW = 240 * k;
    final x = -250 * k + (size.width + 28 * k + 250 * k) * s;
    final b = const Cubic(.3, .1, .5, 1).transform(s);
    final (dy, rot) = b < .5
        ? (_lerp(150, 0, b / .5) * k, _lerp(-10, -2, b / .5))
        : (_lerp(0, -130, (b - .5) / .5) * k, _lerp(-2, -10, (b - .5) / .5));
    final flapping = t >= 0.3 && t < 1.4;
    final pose = flapping ? WingPose.flap(((t - 0.3) / 0.55) % 1) : WingPose.glide;

    // Nombre revelado justo detrás de la cola (la punta de la cola está a 58/240 del ancho del ave).
    final wordStyle = GText.sans(size: 36 * k, weight: FontWeight.w800).copyWith(letterSpacing: 36 * k * .14);
    final painter = TextPainter(
      text: TextSpan(text: 'GAVILÁN', style: wordStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final wordW = painter.width + 36 * k * .14;
    painter.dispose();
    final tailX = x + 58 * k + 6 * k;
    final reveal = ((tailX - (cx - wordW / 2)) / wordW).clamp(0.0, 1.0);
    final grecaW = 220 * k;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          right: -120 * k,
          top: -100 * k,
          child: Opacity(
            opacity: _span(t, 0, 0.9, Curves.easeOut),
            child: Container(
              width: 280 * k,
              height: 280 * k,
              decoration: const BoxDecoration(color: GColors.oxido, shape: BoxShape.circle),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: cy - 22 * k,
          child: Center(
            child: ClipRect(
              clipper: RevealClipper(reveal),
              child: Padding(
                padding: EdgeInsets.only(left: 36 * k * .14),
                child: Text('GAVILÁN', style: wordStyle, semanticsLabel: 'Gavilán'),
              ),
            ),
          ),
        ),
        Positioned(
          left: cx - grecaW / 2,
          top: cy + 25 * k,
          child: CustomPaint(
            size: Size(grecaW, 13 * k),
            painter: GrecaPainter(progress: _span(t, 2.3, 3.2, Curves.easeOut)),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: cy + 44 * k,
          child: Opacity(
            opacity: _span(t, 2.6, 3.4, Curves.easeOut),
            child: Text(
              'ojo de gavilán para tu negocio',
              textAlign: TextAlign.center,
              style: GText.mono(size: 12 * k, color: GColors.pardo),
            ),
          ),
        ),
        Positioned(
          left: x,
          top: cy - 152 * k + dy,
          child: Transform.rotate(
            angle: rot * math.pi / 180,
            alignment: const Alignment(0, .2),
            child: ExcludeSemantics(
              child: Hawk(width: hawkW, pose: pose),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 60 * k + 26,
          child: Opacity(
            opacity: _span(t, 3.1, 3.9, Curves.easeOut),
            child: Text(
              'hecho en Tzucacab, Yucatán',
              textAlign: TextAlign.center,
              style: GText.mono(size: 11, color: GColors.tintaSuave),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: FractionalTranslation(
            translation: Offset(0, 1 - _span(t, 2.9, 3.6, Curves.easeOutCubic)),
            child: CustomPaint(size: Size(size.width, 60 * k), painter: const HipilPainter()),
          ),
        ),
      ],
    );
  }

  static double _lerp(double a, double b, double f) => a + (b - a) * f;
}
