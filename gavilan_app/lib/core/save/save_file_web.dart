import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// En la computadora: descarga el archivo (queda en "Descargas", listo para abrir e imprimir).
Future<void> saveFile(Uint8List bytes, {required String name, required String mimeType}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final link = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = name;
  web.document.body!.append(link);
  link.click();
  link.remove();
  Future<void>.delayed(const Duration(seconds: 5), () => web.URL.revokeObjectURL(url));
}
