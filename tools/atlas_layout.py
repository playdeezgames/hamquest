"""Shared by gen_content.py and pack_atlas.py: which images go in the atlas and where.

Every PNG under data/images except the light-radius masks (turned into radial
profiles) and the unused digit sprites. Deterministic shelf packing, 1024 px wide, no padding
(the renderer samples nearest and never scales sprites).
"""
import os
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
IMAGES = os.path.join(ROOT, 'data', 'images')
EXCLUDE_PREFIXES = ('images/lights/', 'images/numbers/')
ATLAS_WIDTH = 1024


def list_images():
    out = []
    for dirpath, _, files in os.walk(IMAGES):
        for f in files:
            if f.lower().endswith('.png'):
                rel = os.path.relpath(os.path.join(dirpath, f), os.path.dirname(IMAGES)).replace(os.sep, '/')
                if not rel.startswith(EXCLUDE_PREFIXES):
                    out.append(rel)
    return sorted(out)


def png_size(path):
    with open(path, 'rb') as f:
        head = f.read(24)
    if head[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('not a PNG: ' + path)
    return struct.unpack('>II', head[16:24])


def layout():
    """Returns ({path: (x, y, w, h)}, atlas_height)."""
    items = []
    for rel in list_images():
        w, h = png_size(os.path.join(os.path.dirname(IMAGES), rel))
        items.append((rel, w, h))
    items.sort(key=lambda t: (-t[2], -t[1], t[0]))
    rects = {}
    x = y = shelf_h = 0
    for rel, w, h in items:
        if x + w > ATLAS_WIDTH:
            y += shelf_h
            x = 0
            shelf_h = 0
        rects[rel] = (x, y, w, h)
        x += w
        shelf_h = max(shelf_h, h)
    height = y + shelf_h
    # round up to a multiple of 16 for tidiness
    height = (height + 15) // 16 * 16
    return rects, height
