// Atajos del mostrador: que el navegador no abra su ayuda (F1), su buscador (F3), la barra (F4), "Guardar página"
// (Ctrl+S) ni imprima la pantalla (Ctrl+P). La app se encarga de esas teclas.
// Va en un archivo aparte (no dentro de index.html) para que las reglas de seguridad no permitan scripts sueltos.
window.addEventListener('keydown', function (e) {
  var k = (e.key || '').toLowerCase();
  if (k === 'f1' || k === 'f3' || k === 'f4' || ((e.ctrlKey || e.metaKey) && (k === 's' || k === 'p'))) e.preventDefault();
});
