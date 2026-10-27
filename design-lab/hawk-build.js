// Generador del gavilán (caminero) en vuelo, estilo vector plano con contorno.
// Produce un SVG con grupos articulados: hombro (ala) y muñeca (mano).
(function () {
  var C = {
    ink: '#221C17',
    covert: '#6B4226',
    covertDark: '#4F311C',
    feather: '#B79F84',
    featherDark: '#3A2A1E',
    head: '#6F6A63',
    belly: '#F0DDBB',
    bar: '#B5471B',
    tail: '#9C8B78',
    yellow: '#E2A82C',
    spot: '#E9D6B4'
  };
  var SW = 2.4;
  var defs = [];
  var uid = 0;

  function n2(v) { return Math.round(v * 10) / 10; }

  // Pluma: cápsula de base B a punta T, ancho w, curvatura bend.
  function featherPath(B, T, w, bend) {
    var dx = T[0] - B[0], dy = T[1] - B[1];
    var L = Math.hypot(dx, dy), ux = dx / L, uy = dy / L, nx = -uy, ny = ux;
    var h = w / 2, b = bend || 0;
    var r = h * 1.1;
    var e = [T[0] - ux * r, T[1] - uy * r];
    var p1 = [B[0] + nx * h * 0.8, B[1] + ny * h * 0.8];
    var p2 = [e[0] + nx * h, e[1] + ny * h];
    var p3 = [e[0] - nx * h, e[1] - ny * h];
    var p4 = [B[0] - nx * h * 0.8, B[1] - ny * h * 0.8];
    var m = [(B[0] + e[0]) / 2 + nx * b, (B[1] + e[1]) / 2 + ny * b];
    var c1 = [m[0] + nx * h, m[1] + ny * h], c2 = [m[0] - nx * h, m[1] - ny * h];
    var tipC1 = [T[0] + nx * h * 0.9, T[1] + ny * h * 0.9];
    var tipC2 = [T[0] - nx * h * 0.9, T[1] - ny * h * 0.9];
    return 'M' + n2(p1[0]) + ' ' + n2(p1[1]) +
      ' Q' + n2(c1[0]) + ' ' + n2(c1[1]) + ' ' + n2(p2[0]) + ' ' + n2(p2[1]) +
      ' C' + n2(tipC1[0]) + ' ' + n2(tipC1[1]) + ' ' + n2(tipC2[0]) + ' ' + n2(tipC2[1]) + ' ' + n2(p3[0]) + ' ' + n2(p3[1]) +
      ' Q' + n2(c2[0]) + ' ' + n2(c2[1]) + ' ' + n2(p4[0]) + ' ' + n2(p4[1]) + ' Z';
  }

  // Pluma con barras y punta oscura, recortada a su propia silueta.
  function feather(B, T, w, opt) {
    opt = opt || {};
    var id = 'f' + (uid++);
    var d = featherPath(B, T, w, opt.bend);
    defs.push('<clipPath id="' + id + '"><path d="' + d + '"/></clipPath>');
    var dx = T[0] - B[0], dy = T[1] - B[1], L = Math.hypot(dx, dy);
    var ux = dx / L, uy = dy / L, nx = -uy, ny = ux;
    var inner = '';
    var bars = opt.bars || 5;
    for (var i = 1; i <= bars; i++) {
      var t = 0.18 + (i / (bars + 1)) * 0.62;
      var cx = B[0] + dx * t, cy = B[1] + dy * t;
      var s = w * 0.7;
      inner += '<path d="M' + n2(cx + nx * s) + ' ' + n2(cy + ny * s) + ' L' + n2(cx - nx * s + ux * 3) + ' ' + n2(cy - ny * s + uy * 3) + '" stroke="' + C.featherDark + '" stroke-width="' + (opt.barW || 2.6) + '" stroke-linecap="round"/>';
    }
    var tipLen = opt.tip === undefined ? 0.22 : opt.tip;
    if (tipLen > 0) {
      var tb = [B[0] + dx * (1 - tipLen), B[1] + dy * (1 - tipLen)];
      inner += '<path d="M' + n2(tb[0] + nx * w) + ' ' + n2(tb[1] + ny * w) + ' L' + n2(T[0] + nx * w + ux * w) + ' ' + n2(T[1] + ny * w + uy * w) + ' L' + n2(T[0] - nx * w + ux * w) + ' ' + n2(T[1] - ny * w + uy * w) + ' L' + n2(tb[0] - nx * w) + ' ' + n2(tb[1] - ny * w) + ' Z" fill="' + C.featherDark + '"/>';
    }
    return '<path d="' + d + '" fill="' + (opt.fill || C.feather) + '"/>' +
      '<g clip-path="url(#' + id + ')">' + inner + '</g>' +
      '<path d="' + d + '" fill="none" stroke="' + C.ink + '" stroke-width="' + SW + '" stroke-linejoin="round"/>';
  }

  function shape(d, fill, extra) {
    return '<path d="' + d + '" fill="' + fill + '" stroke="' + C.ink + '" stroke-width="' + SW + '" stroke-linejoin="round" stroke-linecap="round"' + (extra || '') + '/>';
  }

  // Motitas claras sobre las coberteras (como el ajedrezado de la foto).
  function spots(list, clipId) {
    var s = '<g clip-path="url(#' + clipId + ')">';
    list.forEach(function (p) {
      s += '<path d="M' + p[0] + ' ' + p[1] + ' l' + (p[2] || 5) + ' ' + (p[3] || 1.6) + '" stroke="' + C.spot + '" stroke-width="2.4" stroke-linecap="round"/>';
    });
    return s + '</g>';
  }

  // ---------- Geometría ----------
  var S = [288, 154];   // hombro
  var W = [238, 60];    // muñeca

  // Ala lejana (detrás del cuerpo): asoma por encima del lomo hacia adelante.
  // Ala lejana: silueta oscura detrás del ala cercana, desplazada arriba y a la derecha.
  var farD = 'M302 152 C296 114 278 76 252 44 C226 30 190 28 150 34 C120 36 96 36 78 38 C72 40 72 46 78 48 C110 50 150 50 190 52 C214 54 232 58 244 66 C262 90 272 116 276 142 Z';
  var farWing = '<g id="farWing" class="far">' +
    feather([160, 40], [74, 28], 15, { bars: 0, tip: 0, fill: C.featherDark }) +
    shape(farD, C.covertDark) +
    '</g>';

  // Cola con bandas, un poco abierta en abanico
  var tailD = 'M220 166 C186 170 146 174 108 176 C98 180 96 210 106 214 C144 210 186 200 222 190 Z';
  defs.push('<clipPath id="tailClip"><path d="' + tailD + '"/></clipPath>');
  var tailBands = '';
  [118, 142, 168, 194].forEach(function (x) {
    tailBands += '<path d="M' + x + ' 168 L' + (x + 5) + ' 220" stroke="' + C.ink + '" stroke-width="8"/>';
  });
  var tail = '<g id="tail"><path d="' + tailD + '" fill="' + C.tail + '"/><g clip-path="url(#tailClip)">' + tailBands +
    '<path d="M90 198 L232 186 L232 230 L90 230 Z" fill="' + C.ink + '" opacity=".14"/>' +
    '<path d="M100 176 L100 220" stroke="#E9DEC8" stroke-width="5"/></g>' +
    '<path d="' + tailD + '" fill="none" stroke="' + C.ink + '" stroke-width="' + SW + '" stroke-linejoin="round"/></g>';

  // Cuerpo alargado
  var bodyD = 'M204 170 C232 152 282 146 320 152 C338 160 342 178 328 190 C302 206 250 206 216 194 C202 188 196 178 204 170 Z';
  defs.push('<clipPath id="bodyClip"><path d="' + bodyD + '"/></clipPath>');
  var bars = '';
  for (var bx = 214; bx < 340; bx += 11) {
    for (var by = 166; by < 212; by += 9) {
      var off = ((by / 9) % 2) * 5.5;
      bars += '<path d="M' + (bx + off) + ' ' + by + ' l4 3 l4 -3" stroke="' + C.bar + '" stroke-width="2.2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>';
    }
  }
  var feet = shape('M236 194 C244 196 254 198 258 203 C252 207 242 207 234 202 Z', C.yellow);
  var body = '<g id="body">' + feet + '<path d="' + bodyD + '" fill="' + C.belly + '"/><g clip-path="url(#bodyClip)">' + bars +
    '<path d="M190 150 C240 160 290 160 345 158 L345 130 L190 130 Z" fill="' + C.covert + '"/>' +
    '<path d="M300 150 C318 160 324 180 316 200 L350 200 L350 140 Z" fill="' + C.belly + '"/></g>' +
    '<path d="' + bodyD + '" fill="none" stroke="' + C.ink + '" stroke-width="' + SW + '" stroke-linejoin="round"/></g>';

  // Cabeza del gavilán caminero: corona redonda y lisa, ojo amarillo grande y alto,
  // cera amarilla ancha que se alarga bajo el ojo, pico corto y ganchudo.
  // La nuca se funde con el lomo: solo se contornean la corona y la garganta.
  var headD = 'M298 166 C301 152 313 141 329 138.5 C341 137 350 140 355 145 L360 157 C356 165 348 171 338 174 C330 177 322 179 316 180 Q313 177 311 180.5 Q308 175.5 305.5 178 Q304 172.5 301 173 Q301 168.5 298 166 Z';
  defs.push('<clipPath id="headClip"><path d="' + headD + '"/></clipPath>');
  var eyeY = '#F4C21F';
  var head = '<g id="head">' +
    '<path d="' + headD + '" fill="#6C645C"/>' +
    '<g clip-path="url(#headClip)">' +
    '<path d="M294 156 C310 142 330 136 362 140 L362 128 L294 128 Z" fill="#5C554E"/>' +
    '<path d="M320 177 C334 175 348 170 358 160 L366 190 L310 192 Z" fill="#857D74"/>' +
    '<path d="M318 152 l4.5 -1 M312 160 l4.5 -1 M322 163 l4.5 -1 M309 168 l4.5 -1 M326 168 l4.5 -1" stroke="#5A534C" stroke-width="1.5" stroke-linecap="round"/>' +
    '</g>' +
    '<path d="M309 151 C316 143 325 139 335 138.5 C344 138 351 141 355 145" stroke="' + C.ink + '" stroke-width="' + SW + '" fill="none" stroke-linecap="round"/>' +
    '<path d="M360 157 C356 165 348 171 338 174 C332 175.5 326 177.5 321 179" stroke="' + C.ink + '" stroke-width="' + SW + '" fill="none" stroke-linecap="round"/>' +
    '<path d="M331.5 145 C337 142.2 345 142 351 144.2" stroke="#4E4842" stroke-width="2.2" fill="none" stroke-linecap="round"/>' +
    shape('M356 156.4 C351.5 158.2 346.5 159.2 340.8 159.6 C339.4 161.6 340.6 164.2 343.4 164.2 C348.8 163.8 354 162.2 358.6 160 Z', C.yellow, ' stroke-width="1.1"') +
    shape('M351 144 C355 143.6 358.8 144.8 361.2 146.6 L361.8 157.6 C359 158.8 356 159.4 353.4 159.2 C354 154.2 353.2 148.6 351 144 Z', C.yellow, ' stroke-width="1.3"') +
    shape('M360.2 145.6 C366.2 145.2 370.8 149.8 370.4 158.6 C370.1 162.4 368.2 163.8 366.8 162 C366.8 159.4 365 157.6 361.2 157.2 Z', '#33302D', ' stroke-width="1.6"') +
    '<path d="M362.4 148 C365.6 148.2 368.2 150.4 369.2 153.6" stroke="#6E6A63" stroke-width="1.2" fill="none" stroke-linecap="round"/>' +
    '<circle cx="342.5" cy="150.2" r="5.8" fill="' + eyeY + '" stroke="' + C.ink + '" stroke-width="1.6"/>' +
    '<circle cx="343.3" cy="150.4" r="2.5" fill="' + C.ink + '"/>' +
    '<circle cx="344.3" cy="149.2" r="0.9" fill="#fff"/>' +
    '</g>';

  // Ala cercana: brazo (secundarias + coberteras) y mano (primarias + coberteras de la mano)
  var secondaries = [
    feather([202, 104], [130, 128], 24, { bars: 4, tip: 0.18 }),
    feather([216, 114], [150, 142], 24, { bars: 4, tip: 0.18 }),
    feather([232, 124], [174, 154], 24, { bars: 4, tip: 0.18 }),
    feather([248, 134], [198, 163], 24, { bars: 3, tip: 0.18 }),
    feather([264, 144], [224, 170], 22, { bars: 3, tip: 0.18 })
  ].join('');
  var greaterD = 'M196 100 C212 128 244 148 276 160 C258 164 232 158 214 146 C200 136 190 120 186 108 Z';
  var armCovD = 'M292 156 C286 120 268 86 240 58 C224 74 208 90 196 104 C212 130 246 150 272 160 Z';
  defs.push('<clipPath id="armCov"><path d="' + armCovD + '"/></clipPath>');
  var armCov = shape(greaterD, '#86583A') + shape(armCovD, C.covert) +
    spots([[236, 84], [250, 96], [262, 112], [272, 128], [242, 108], [256, 124], [226, 98], [266, 144], [280, 140], [252, 138], [230, 116], [278, 118]], 'armCov');

  var primaries = [
    feather([186, 98], [108, 121], 22, { bars: 4, bend: -2 }),
    feather([190, 92], [88, 110], 22, { bars: 5, bend: -2 }),
    feather([195, 84], [72, 97], 22, { bars: 6, bend: -2 }),
    feather([200, 76], [62, 82], 22, { bars: 6, bend: -3 }),
    feather([206, 68], [58, 66], 22, { bars: 6, bend: -3 }),
    feather([214, 60], [64, 50], 21, { bars: 6, bend: -4 })
  ].join('');
  var handCovD = 'M248 60 C222 46 186 44 146 52 C162 64 180 80 192 96 C196 101 199 104 202 106 C222 96 240 78 248 60 Z';
  defs.push('<clipPath id="handCov"><path d="' + handCovD + '"/></clipPath>');
  var handCov = shape(handCovD, C.covert) +
    spots([[166, 62], [184, 60], [202, 62], [220, 62], [174, 78], [192, 76], [210, 78], [184, 92], [202, 92], [164, 88], [228, 76]], 'handCov');

  var nearWing = '<g id="nearWing" class="near">' +
    '<g id="arm">' + secondaries + armCov + '</g>' +
    '<g id="hand">' + primaries + handCov + '</g>' +
    '</g>';

  var markup = '<defs>' + defs.join('') + '</defs>' +
    '<g id="bird">' + farWing + tail + body + head + nearWing + '</g>';
  window.HAWK_MARKUP = markup;
  // Piezas sueltas (mismo viewBox) para animar el ala en Flutter.
  window.HAWK_PARTS = {
    defs: '<defs>' + defs.join('') + '</defs>',
    far: farWing,
    body: tail + body + head,
    arm: '<g id="arm">' + secondaries + armCov + '</g>',
    hand: '<g id="hand">' + primaries + handCov + '</g>'
  };
  window.HAWK_POINTS = { shoulder: S, wrist: W };
  var svg = typeof document !== 'undefined' && document.getElementById('hawk');
  if (svg) svg.innerHTML = markup;
})();
