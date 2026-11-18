import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Lo más que pesa un logo ya listo. El almacenamiento acepta hasta 512 KB por archivo.
const maxLogoBytes = 450 * 1024;

/// Deja el logo listo para el ticket: cabe en [maxWidth]×[maxHeight] sin deformarse, con fondo blanco (la
/// impresora de tickets no entiende lo transparente y saldría negro) y en PNG, que deja nítidas las letras.
/// Si pesa de más, lo hace más chico. null si no es una imagen que se pueda leer.
Future<Uint8List?> prepareLogo(Uint8List raw, {int maxWidth = 600, int maxHeight = 240}) async {
  try {
    var scale = 1.0;
    for (var attempt = 0; attempt < 4; attempt++) {
      final png = await _flatten(raw, (maxWidth * scale).round(), (maxHeight * scale).round());
      if (png.length <= maxLogoBytes) return png;
      scale *= 0.7;
    }
    return null;
  } catch (_) {
    return null;
  }
}

Future<Uint8List> _flatten(Uint8List raw, int maxWidth, int maxHeight) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(raw);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (w, h) {
      final s = math.min(1.0, math.min(maxWidth / w, maxHeight / h));
      return ui.TargetImageSize(width: math.max(1, (w * s).round()), height: math.max(1, (h * s).round()));
    },
  );
  final src = (await codec.getNextFrame()).image;
  codec.dispose();
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final size = ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble());
  canvas.drawRect(size, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  canvas.drawImage(src, ui.Offset.zero, ui.Paint()..filterQuality = ui.FilterQuality.medium);
  final picture = recorder.endRecording();
  final out = await picture.toImage(src.width, src.height);
  picture.dispose();
  src.dispose();
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  out.dispose();
  return data!.buffer.asUint8List();
}
