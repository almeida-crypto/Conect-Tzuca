{{flutter_js}}
{{flutter_build_config}}

// El motor de dibujo se carga de aquí mismo (no de internet), para que la app abra sin conexión.
// Sin el service worker de Flutter (ya no se usa): el modo sin internet es gavilan_sw.js, solo si el dueño lo activa.
_flutter.loader.load({
  config: { canvasKitBaseUrl: 'canvaskit/' },
});
