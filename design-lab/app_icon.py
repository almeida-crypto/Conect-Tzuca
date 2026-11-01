"""Iconos de Gavilán para Android e iPhone: la cabeza del gavilán sobre óxido.

Uso, desde la raíz del repositorio:
    python design-lab/app_icon.py <cuerpo a resolución completa (body.png de hawk_layers.py con escala 1)>
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

body = Image.open(sys.argv[1])  # 1710 × 977
APP = Path('gavilan_app')
OXIDO = (181, 71, 27, 255)

N = 1024
EYE = (1545, 575)  # ojo en el dibujo completo
SCALE, EYE_AT = 1.45, (560, 470)


def foreground():
    """Capa de frente del icono adaptable (108 dp; se ven los 72 dp del centro)."""
    big = body.resize((round(body.width * SCALE), round(body.height * SCALE)), Image.LANCZOS)
    layer = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    ox = round(EYE_AT[0] - EYE[0] * SCALE)
    oy = round(EYE_AT[1] - EYE[1] * SCALE)
    layer.alpha_composite(big, (max(ox, 0), max(oy, 0)), (max(-ox, 0), max(-oy, 0)))
    return layer


def square(fg):
    """Icono cuadrado completo: lo visible de la capa adaptable sobre óxido."""
    im = Image.new('RGBA', (N, N), OXIDO)
    im.alpha_composite(fg)
    r = N * 72 / 108 / 2
    return im.crop((round(N / 2 - r), round(N / 2 - r), round(N / 2 + r), round(N / 2 + r)))


def round_icon(sq, size):
    im = sq.resize((size, size), Image.LANCZOS)
    m = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(m).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(im, (0, 0), m.resize((size, size), Image.LANCZOS))
    return out


fg = foreground()
sq = square(fg)

# Android: icono adaptable (API 26+) y redondo para versiones anteriores.
res = APP / 'android/app/src/main/res'
for folder, mult in (('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)):
    d = res / f'mipmap-{folder}'
    d.mkdir(exist_ok=True)
    fg.resize((round(108 * mult),) * 2, Image.LANCZOS).save(d / 'ic_launcher_foreground.png', optimize=True)
    round_icon(sq, round(48 * mult)).save(d / 'ic_launcher.png', optimize=True)

# iPhone: cuadrado sin transparencia; iOS redondea las esquinas.
ios = APP / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
contents = json.loads((ios / 'Contents.json').read_text())
flat = sq.convert('RGB')
for img in contents['images']:
    size = float(img['size'].split('x')[0]) * int(img['scale'][0])
    flat.resize((round(size),) * 2, Image.LANCZOS).save(ios / img['filename'], optimize=True)

print('listo')
