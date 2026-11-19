import 'dart:js_interop';

// Llamadas a window.gavilanOffline (web/offline.js), que maneja gavilan_sw.js.

extension type _Result._(JSObject _) implements JSObject {
  external int get saved;
  external int get failed;
}

extension type _Offline._(JSObject _) implements JSObject {
  external bool supported();
  external bool enabled();
  external JSPromise<_Result> enable(JSArray<JSString> extra);
  external JSPromise<JSAny?> disable();
  external bool canInstall();
  external bool installed();
  external JSPromise<JSBoolean> install();
}

@JS('gavilanOffline')
external _Offline? get _offline;

/// El navegador permite guardar la app (Chrome, Edge y Firefox modernos, en https o localhost).
bool offlineSupported() => _offline?.supported() ?? false;

/// Ya está guardada en este navegador.
bool offlineEnabled() => _offline?.enabled() ?? false;

/// Guarda la app en este navegador; [extra] son archivos de la app que todavía no se han cargado (imágenes).
Future<({int saved, int failed})> enableOffline(List<String> extra) async {
  final o = _offline;
  if (o == null) throw StateError('No disponible');
  final r = await o.enable([for (final u in extra) u.toJS].toJS).toDart;
  return (saved: r.saved, failed: r.failed);
}

Future<void> disableOffline() async {
  await _offline?.disable().toDart;
}

/// El navegador ofrece poner Gavilán con ícono, como programa.
bool canInstallApp() => _offline?.canInstall() ?? false;

/// Abierta como programa instalado.
bool runningInstalled() => _offline?.installed() ?? false;

/// Muestra la ventana del navegador "¿Instalar Gavilán?". true si la persona aceptó.
Future<bool> installApp() async => (await _offline?.install().toDart)?.toDart ?? false;
