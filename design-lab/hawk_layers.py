"""Separa el gavilán recortado en capas: ala lejana, cuerpo y ala cercana."""
import sys

import numpy as np
from PIL import Image, ImageDraw

src, outdir = sys.argv[1], sys.argv[2]
full = Image.open(src).convert('RGBA')
W, H = full.size

# Coordenadas sobre el recorte de 1710 x 977.
NEAR = [
    (0, 0), (820, 0), (1000, 200), (1100, 330), (1140, 432), (1192, 490), (1235, 545), (1240, 551),
    (1150, 612), (1000, 606), (860, 606), (800, 628), (700, 690), (620, 668), (560, 655), (480, 612),
    (400, 600), (0, 560),
]
FAR = [
    (1140, 432), (1100, 330), (1300, 150), (1700, 150), (1700, 345), (1640, 345), (1480, 480), (1400, 492), (1356, 497),
    (1300, 498), (1250, 485),
]
# Lomo que queda bajo el ala cercana: se pinta para que no se vea hueco al aletear.
BACK = [(1252, 470), (1236, 548), (1150, 612), (860, 606), (700, 690), (560, 700), (560, 672), (900, 545)]
BACK_COLOR = (58, 42, 30, 255)


def mask(poly):
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).polygon(poly, fill=255)
    return m


def only(poly):
    out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    out.paste(full, (0, 0), mask(poly))
    # Respeta la transparencia original.
    a = np.minimum(np.asarray(out)[..., 3], np.asarray(full)[..., 3])
    arr = np.asarray(out).copy()
    arr[..., 3] = a
    return Image.fromarray(arr)


near = only(NEAR)
far = only(FAR)

body = full.copy()
hole = Image.composite(Image.new('L', (W, H), 255), Image.new('L', (W, H), 0), mask(NEAR))
hole = np.maximum(np.asarray(hole), np.asarray(mask(FAR)))
arr = np.asarray(body).copy()
arr[hole > 0] = 0
body = Image.fromarray(arr)
lomo = Image.new('RGBA', (W, H), (0, 0, 0, 0))
ImageDraw.Draw(lomo).polygon(BACK, fill=BACK_COLOR)
body = Image.alpha_composite(lomo, body)

scale = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
for name, im in (('far', far), ('body', body), ('near', near)):
    if scale != 1.0:
        im = im.resize((round(W * scale), round(H * scale)), Image.LANCZOS)
    im.save(f'{outdir}/{name}.png', optimize=True)

# Vista de control: polígonos sobre la imagen.
check = Image.new('RGBA', (W, H), (181, 71, 27, 255))
check.alpha_composite(full)
d = ImageDraw.Draw(check)
d.line(NEAR + [NEAR[0]], fill=(0, 255, 255, 255), width=3)
d.line(FAR + [FAR[0]], fill=(255, 255, 0, 255), width=3)
d.line(BACK + [BACK[0]], fill=(255, 0, 255, 255), width=2)
check.convert('RGB').save(f'{outdir}/check_polys.png')
print(W, H)
