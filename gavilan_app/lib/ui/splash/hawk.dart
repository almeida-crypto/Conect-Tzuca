import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Coordenadas del dibujo original (1710 × 977) donde se articulan las alas.
const _viewW = 1710.0;
const _viewH = 977.0;
const _shoulder = Offset(1190, 560);
const _farShoulder = Offset(1250, 470);

/// Pose del ala en un instante del aleteo.
class WingPose {
  const WingPose({this.armAngle = 0, this.armScaleY = 1, this.beat = 0});

  /// Grados, positivo en sentido horario (igual que CSS rotate).
  final double armAngle;

  /// 1 = ala arriba como en el dibujo; negativo = ala abajo, del otro lado del hombro.
  final double armScaleY;

  /// Desplazamiento vertical del cuerpo, como fracción del alto del ave.
  final double beat;

  static const glide = WingPose();

  /// Un ciclo de aleteo, u en [0, 1).
  static WingPose flap(double u) {
    const ease = Cubic(.45, 0, .55, 1);
    double keys(List<(double, double)> k) {
      for (var i = 0; i < k.length - 1; i++) {
        final (t0, v0) = k[i];
        final (t1, v1) = k[i + 1];
        if (u >= t0 && u <= t1) return v0 + (v1 - v0) * ease.transform((u - t0) / (t1 - t0));
      }
      return k.last.$2;
    }

    return WingPose(
      armAngle: keys(const [(0, 0), (.42, -10), (1, 0)]),
      armScaleY: keys(const [(0, 1), (.42, -.82), (1, 1)]),
      beat: keys(const [(0, 0), (.42, -.04), (1, 0)]),
    );
  }
}

/// El gavilán armado por capas: ala lejana, cuerpo y ala cercana.
class Hawk extends StatelessWidget {
  const Hawk({super.key, required this.width, this.pose = WingPose.glide});

  final double width;
  final WingPose pose;

  /// Alto del ave para un ancho dado.
  static double heightFor(double width) => width * _viewH / _viewW;

  /// Punta de la cola, como fracción del ancho desde la izquierda.
  static const tailTip = 60 / _viewW;

  static const layers = ['far', 'body', 'near'];

  @override
  Widget build(BuildContext context) {
    final k = width / _viewW;
    final height = heightFor(width);

    Widget layer(String name) => Image.asset(
      'assets/hawk/flight/$name.png',
      width: width,
      height: height,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );

    final wing = Matrix4.rotationZ(pose.armAngle * math.pi / 180)
      ..multiply(Matrix4.diagonal3Values(1, pose.armScaleY, 1));

    return SizedBox(
      width: width,
      height: height,
      child: Transform.translate(
        offset: Offset(0, pose.beat * height),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Transform(origin: _farShoulder * k, transform: wing, child: layer('far')),
            layer('body'),
            Transform(origin: _shoulder * k, transform: wing, child: layer('near')),
          ],
        ),
      ),
    );
  }
}
