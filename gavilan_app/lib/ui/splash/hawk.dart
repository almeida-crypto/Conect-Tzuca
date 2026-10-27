import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Coordenadas del dibujo (viewBox 0 0 400 260) donde se articula el ala.
const _viewW = 400.0;
const _viewH = 260.0;
const _shoulder = Offset(288, 154);
const _farShoulder = Offset(296, 152);
const _wrist = Offset(238, 60);

/// Pose del ala en un instante del aleteo.
class WingPose {
  const WingPose({this.armAngle = 0, this.armScaleY = 1, this.handAngle = 0, this.beat = 0});

  /// Grados, positivo en sentido horario (igual que CSS rotate).
  final double armAngle;
  final double armScaleY;
  final double handAngle;

  /// Desplazamiento vertical del cuerpo, en unidades del dibujo.
  final double beat;

  static const glide = WingPose();

  /// Un ciclo de aleteo, u en [0, 1). Mismos fotogramas clave que la maqueta.
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
      handAngle: keys(const [(0, 0), (.2, 12), (.42, -6), (.72, -22), (1, 0)]),
      beat: keys(const [(0, 0), (.42, -10), (1, 0)]),
    );
  }
}

/// El gavilán armado por piezas: ala lejana, cuerpo, brazo y mano.
class Hawk extends StatelessWidget {
  const Hawk({super.key, required this.width, this.pose = WingPose.glide});

  final double width;
  final WingPose pose;

  @override
  Widget build(BuildContext context) {
    final k = width / _viewW;
    final height = _viewH * k;

    Widget layer(String name) =>
        SvgPicture.asset('assets/hawk/$name.svg', width: width, height: height, fit: BoxFit.fill);

    Matrix4 armMatrix() =>
        Matrix4.rotationZ(pose.armAngle * math.pi / 180)..multiply(Matrix4.diagonal3Values(1, pose.armScaleY, 1));

    final hand = Transform(
      origin: _wrist * k,
      transform: Matrix4.rotationZ(pose.handAngle * math.pi / 180),
      child: layer('hand'),
    );

    return SizedBox(
      width: width,
      height: height,
      child: Transform.translate(
        offset: Offset(0, pose.beat * k),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Transform(origin: _farShoulder * k, transform: armMatrix(), child: layer('far')),
            layer('body'),
            Transform(
              origin: _shoulder * k,
              transform: armMatrix(),
              child: Stack(clipBehavior: Clip.none, children: [layer('arm'), hand]),
            ),
          ],
        ),
      ),
    );
  }
}
