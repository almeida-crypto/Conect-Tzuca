import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// En el navegador se puede imprimir: con la impresora de tickets o cualquier otra instalada.
const bool canPrintTicket = true;

/// Imprime [html] desde un marco invisible, para no imprimir la pantalla de la app.
Future<void> printHtml(String html) async {
  // Al terminar se regresa el teclado a la app: si no, los atajos dejan de responder.
  final previous = web.document.activeElement;
  final frame = web.document.createElement('iframe') as web.HTMLIFrameElement;
  frame.style
    ..position = 'fixed'
    ..right = '0'
    ..bottom = '0'
    ..width = '0'
    ..height = '0'
    ..border = '0';
  final loaded = Completer<void>();
  frame.onload = ((web.Event _) {
    if (!loaded.isCompleted) loaded.complete();
  }).toJS;
  frame.srcdoc = html.toJS;
  web.document.body!.append(frame);
  await loaded.future.timeout(const Duration(seconds: 5), onTimeout: () {});
  final win = frame.contentWindow;
  if (win != null) {
    win.focus();
    win.print();
  }
  // El cuadro de imprimir detiene la página; al cerrarlo se quita el marco y el teclado regresa.
  void restore() {
    if (previous != null && previous.isA<web.HTMLElement>()) (previous as web.HTMLElement).focus();
  }

  restore();
  Timer(const Duration(milliseconds: 1500), () {
    frame.remove();
    restore();
  });
}
