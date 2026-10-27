// Exporta el gavilán: node design-lab/export-hawk.js
// - design-lab/gavilan-vuelo.svg: dibujo completo.
// - gavilan_app/assets/hawk/*.svg: piezas para la animación de Flutter.
const fs = require('fs');
const path = require('path');

global.window = {};
require('./hawk-build.js');

const open = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 260">';
const full = open + window.HAWK_MARKUP + '</svg>\n';
fs.writeFileSync(path.join(__dirname, 'gavilan-vuelo.svg'), full);
console.log('gavilan-vuelo.svg', full.length, 'bytes');

const appAssets = path.join(__dirname, '..', 'gavilan_app', 'assets', 'hawk');
fs.mkdirSync(appAssets, { recursive: true });
fs.writeFileSync(path.join(appAssets, 'gavilan.svg'), full);
const parts = window.HAWK_PARTS;
for (const name of ['far', 'body', 'arm', 'hand']) {
  const svg = open + parts.defs + parts[name] + '</svg>\n';
  fs.writeFileSync(path.join(appAssets, name + '.svg'), svg);
  console.log('assets/hawk/' + name + '.svg', svg.length, 'bytes');
}
