#!/usr/bin/env python3
"""Draw the 630x500 itch.io cover (assets/cover.png) from the game's own art. Needs Pillow."""
import math
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(ROOT, 'data', 'images', 'map')
FONT = os.path.join(ROOT, 'assets', 'fonts', 'm5x7.png')
OUT = os.path.join(ROOT, 'assets', 'cover.png')
W, H = 630, 500


def sprite(path, scale):
    im = Image.open(os.path.join(IMG, path)).convert('RGBA')
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


class Font:
    def __init__(self):
        self.sheet = Image.open(FONT).convert('L')
        self.adv = []
        for i in range(95):
            cx, cy = (i % 16) * 8, (i // 16) * 9
            maxx = -1
            for y in range(9):
                for x in range(8):
                    if self.sheet.getpixel((cx + x, cy + y)) < 128:
                        maxx = max(maxx, x)
            self.adv.append(5 if i == 0 else maxx + 2)

    def width(self, s, scale):
        return sum(self.adv[ord(c) - 32] for c in s) * scale

    def draw(self, img, x, y, s, scale, color, shadow=None):
        def put(ox, oy, col):
            cx_ = x + ox
            for ch in s:
                i = ord(ch) - 32
                gx, gy = (i % 16) * 8, (i // 16) * 9
                for yy in range(9):
                    for xx in range(8):
                        if self.sheet.getpixel((gx + xx, gy + yy)) < 128:
                            for sy in range(scale):
                                for sx in range(scale):
                                    px, py = cx_ + xx * scale + sx, y + oy + yy * scale + sy
                                    if 0 <= px < img.width and 0 <= py < img.height:
                                        img.putpixel((px, py), col)
                cx_ += self.adv[i] * scale
        if shadow:
            put(scale, scale, shadow)
        put(0, 0, color)


def plate(img, x, y, w, h):
    shade = Image.new('RGBA', (w, h), (0, 0, 0, 190))
    img.alpha_composite(shade, (x, y))


def main():
    img = Image.new('RGBA', (W, H), (16, 14, 20, 255))
    # floor: the game's own tile, darkened toward the edges like the in-game light
    floor = Image.open(os.path.join(IMG, 'terrain', 'misc', 'floor.png')).convert('RGBA')
    for ty in range(0, H, 32):
        for tx in range(0, W, 32):
            img.paste(floor, (tx, ty))
    cx, cy = W / 2, H * 0.70
    px = img.load()
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - cx, (y - cy) * 1.15)
            a = max(0.0, min(1.0, (d - 70) / 230))   # 0 at the centre, 1 at the edges
            r, g, b, _ = px[x, y]
            k = 1.0 - 0.93 * a
            px[x, y] = (int(r * k), int(g * k), int(b * k), 255)

    f = Font()
    t1 = "HamQuest"
    f.draw(img, (W - f.width(t1, 10)) // 2, 28, t1, 10, (255, 232, 140, 255), (60, 20, 10, 255))
    t2 = "of SPLORR!!"
    f.draw(img, (W - f.width(t2, 5)) // 2, 118, t2, 5, (255, 255, 255, 255), (0, 0, 120, 255))
    t3 = "locks, keys, ham and monsters"
    plate(img, 150, 166, 330, 26)
    f.draw(img, (W - f.width(t3, 2)) // 2, 172, t3, 2, (200, 200, 225, 255))

    def place(path, scale, x, y):
        s = sprite(path, scale)
        img.alpha_composite(s, (x, y))

    # a party in the lamplight
    place('creatures/bosses/dragon.png', 5, 90, 230)
    place('creatures/player/player.png', 5, 235, 285)
    place('creatures/undead/skeleton.png', 4, 395, 300)
    place('creatures/goblinoids/goblin.png', 4, 485, 310)
    place('items/consumables/ham.png', 3, 70, 400)
    place('items/keys/red.png', 3, 170, 410)
    place('items/consumables/potion.png', 3, 365, 405)
    place('items/keys/rainbow.png', 3, 465, 400)
    t4 = "a brutal little maze crawl"
    plate(img, 160, 464, 310, 26)
    f.draw(img, (W - f.width(t4, 2)) // 2, 470, t4, 2, (240, 170, 170, 255))
    img.convert('RGB').save(OUT)
    print('wrote', os.path.relpath(OUT, ROOT), img.size)


if __name__ == '__main__':
    main()
