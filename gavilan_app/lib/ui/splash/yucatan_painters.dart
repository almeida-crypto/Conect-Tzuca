import 'package:flutter/widgets.dart';

/// Colores del inicio animado. Se quedan como los aprobó el usuario aunque cambie la paleta de la app.
abstract final class IntroColors {
  static const papel = Color(0xFFF4ECDD);
  static const papelClaro = Color(0xFFFBF6EC);
  static const tinta = Color(0xFF221C17);
  static const tintaSuave = Color(0x99221C17);
  static const pardo = Color(0xFF6B4226);
  static const oxido = Color(0xFFB5471B);
  static const ocre = Color(0xFFD8A02A);
  static const monte = Color(0xFF2E5E3E);
  static const rosa = Color(0xFFC2416F);
}

/// Greca maya escalonada (como los frisos de Uxmal) que se dibuja de izquierda a derecha.
class GrecaPainter extends CustomPainter {
  const GrecaPainter({required this.progress, this.color = IntroColors.oxido});

  final double progress;
  final Color color;

  static Path buildPath(double w) {
    final p = Path()
      ..moveTo(0, 12)
      ..lineTo(w, 12);
    for (var x = 2.0; x + 16 <= w; x += 20) {
      p
        ..moveTo(x, 12)
        ..lineTo(x, 1)
        ..lineTo(x + 15, 1)
        ..lineTo(x + 15, 8)
        ..lineTo(x + 7, 8)
        ..lineTo(x + 7, 4.5);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final scale = size.height / 13;
    canvas.save();
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.square;
    final path = buildPath(size.width / scale);
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * progress.clamp(0, 1)), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GrecaPainter old) => old.progress != progress || old.color != color;
}

/// Franja de bordado de hipil en punto de cruz (xok bil chuuy): flores, hojas y orillas en zigzag.
class HipilPainter extends CustomPainter {
  const HipilPainter();

  static const _flower = ['.1...1.', '111.111', '.11111.', '..121..', '.11111.', '111.111', '.1...1.'];
  static const _leaf = ['.3.', '333', '.3.'];
  static const _petals = [IntroColors.oxido, IntroColors.rosa];

  @override
  void paint(Canvas canvas, Size size) {
    // Diseñado sobre 60 de alto; se escala al alto real.
    final k = size.height / 60;
    canvas.save();
    canvas.scale(k);
    final w = size.width / k;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 60), Paint()..color = IntroColors.papelClaro);
    canvas.drawLine(
      Offset.zero,
      Offset(w, 0),
      Paint()
        ..color = IntroColors.tinta
        ..strokeWidth = 1.2,
    );

    final zig = Paint()
      ..color = IntroColors.monte
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final top = Path(), bottom = Path();
    for (var x = 0.0; x < w; x += 8) {
      top
        ..moveTo(x, 8)
        ..relativeLineTo(4, -4)
        ..relativeLineTo(4, 4);
      bottom
        ..moveTo(x, 48)
        ..relativeLineTo(4, 4)
        ..relativeLineTo(4, -4);
    }
    canvas.drawPath(top, zig);
    canvas.drawPath(bottom, zig);

    const cell = 3.0;
    final fill = Paint();
    void stamp(List<String> pattern, double ox, double oy, Color petal) {
      for (var y = 0; y < pattern.length; y++) {
        for (var x = 0; x < pattern[y].length; x++) {
          final ch = pattern[y][x];
          if (ch == '.') continue;
          fill.color = switch (ch) {
            '2' => IntroColors.ocre,
            '3' => IntroColors.monte,
            _ => petal,
          };
          canvas.drawRect(Rect.fromLTWH(ox + x * cell, oy + y * cell, cell - .6, cell - .6), fill);
        }
      }
    }

    var i = 0;
    for (var x = 4.0; x < w; x += 42) {
      stamp(_flower, x, 16, _petals[i % 2]);
      stamp(_leaf, x + 27, 25, IntroColors.monte);
      i++;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HipilPainter old) => false;
}

/// Recorte que revela un widget de izquierda a derecha.
class RevealClipper extends CustomClipper<Rect> {
  const RevealClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction.clamp(0, 1), size.height);

  @override
  bool shouldReclip(RevealClipper old) => old.fraction != fraction;
}
