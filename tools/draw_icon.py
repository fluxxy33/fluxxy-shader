"""Fluxxy Shader's icon: 32x32 pixel art drawn on a grid (a violet End sky with an aurora, stars
and an End island), scaled to 256x256 without smoothing."""
import math
import random
from PIL import Image

N = 32
img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
px = img.load()
rng = random.Random(7)

def put(x, y, c):
    if 0 <= x < N and 0 <= y < N:
        px[x, y] = c

# Sky: deep violet at the top to a pink glow at the horizon, in a rounded tile.
for y in range(N):
    for x in range(N):
        if min(x, N - 1 - x) + min(y, N - 1 - y) < 2 and min(x, N - 1 - x) < 2 and min(y, N - 1 - y) < 2:
            continue
        t = y / (N - 1)
        put(x, y, (int(22 + 70 * t * t), int(10 + 14 * t), int(52 + 60 * t), 255))
# Stars.
for _ in range(26):
    x, y = rng.randrange(2, N - 2), rng.randrange(2, 18)
    put(x, y, (255, 245, 255, 255) if rng.random() < 0.4 else (200, 170, 255, 255))
# Aurora: three curtains of green to teal to violet, waving across the sky.
for band, (amp, base, col) in enumerate([(2.5, 9, (90, 255, 190)), (2.0, 12, (80, 220, 255)), (1.5, 15, (190, 120, 255))]):
    for x in range(2, N - 2):
        top = int(base + amp * math.sin(x / 3.0 + band))
        for k in range(5):
            a = 255 - k * 45
            r, g, b = col
            under = px[x, top + k] if 0 <= top + k < N else (0, 0, 0, 255)
            f = a / 255 * 0.8
            put(x, top + k, (int(r * f + under[0] * (1 - f)), int(g * f + under[1] * (1 - f)), int(b * f + under[2] * (1 - f)), 255))
# End island: pale end stone with a dark rim, at the bottom.
for x in range(4, N - 4):
    h = int(4 + 2 * math.sin(x / 4.0) + (1 if x % 5 == 0 else 0))
    for y in range(N - 2 - h, N - 2):
        edge = y == N - 2 - h
        put(x, y, (238, 236, 178, 255) if edge else (206, 200, 140, 255) if (x + y) % 3 else (180, 172, 118, 255))
# A chorus plant on the island.
for y in range(N - 13, N - 6):
    put(20, y, (150, 90, 160, 255))
for x, y in [(19, N - 11), (21, N - 9), (18, N - 11), (22, N - 9)]:
    put(x, y, (150, 90, 160, 255))
for x, y in [(20, N - 14), (17, N - 12), (23, N - 10)]:
    put(x, y, (230, 190, 255, 255))
# Rim.
VIOLET, DARK = (180, 120, 255, 255), (110, 60, 180, 255)
for i in range(2, N - 2):
    put(i, 0, VIOLET); put(0, i, VIOLET); put(i, N - 1, DARK); put(N - 1, i, DARK)
for x, y in [(1, 1), (N - 2, 1)]:
    put(x, y, VIOLET)
for x, y in [(1, N - 2), (N - 2, N - 2)]:
    put(x, y, DARK)

img.resize((256, 256), Image.NEAREST).save("icon.png")
