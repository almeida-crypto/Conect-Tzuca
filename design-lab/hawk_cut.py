"""Quita el fondo blanco del gavilán de Flow y guarda un PNG con transparencia."""
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

src, out = sys.argv[1], sys.argv[2]
im = np.asarray(Image.open(src).convert('RGB')).astype(np.float32)
h, w, _ = im.shape
minc = im.min(axis=2)

# Fondo: lo casi blanco conectado con el borde.
white = minc > 222
bg = np.zeros((h, w), bool)
q = deque()
for x in range(w):
    for y in (0, h - 1):
        if white[y, x] and not bg[y, x]:
            bg[y, x] = True
            q.append((y, x))
for y in range(h):
    for x in (0, w - 1):
        if white[y, x] and not bg[y, x]:
            bg[y, x] = True
            q.append((y, x))
while q:
    y, x = q.popleft()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ny, nx = y + dy, x + dx
        if 0 <= ny < h and 0 <= nx < w and white[ny, nx] and not bg[ny, nx]:
            bg[ny, nx] = True
            q.append((ny, nx))

# Borde suave: en una franja de 2 px junto al fondo, la opacidad sale de qué tan blanco es el pixel.
bg_img = Image.fromarray((bg * 255).astype(np.uint8))
near = np.asarray(bg_img.filter(ImageFilter.MaxFilter(5))) > 0
edge = near & ~bg
alpha = np.ones((h, w), np.float32)
alpha[bg] = 0
a_edge = np.clip((255 - minc) / (255 - 150), 0, 1)
alpha[edge] = a_edge[edge]

# Quita el blanco mezclado en el borde (des-premultiplica contra blanco).
rgb = im.copy()
safe = np.maximum(alpha, 1e-3)[..., None]
rgb = np.where(edge[..., None], 255 - (255 - im) / safe, im)
rgb = np.clip(rgb, 0, 255)

rgba = np.dstack([rgb, alpha * 255]).astype(np.uint8)
ys, xs = np.nonzero(alpha > 0.05)
x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
print('recorte', x0, y0, x1, y1, '->', x1 - x0, 'x', y1 - y0)
Image.fromarray(rgba).crop((x0 - 4, y0 - 4, x1 + 4, y1 + 4)).save(out)
