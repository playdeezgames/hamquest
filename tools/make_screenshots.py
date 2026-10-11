#!/usr/bin/env python3
"""Regenerate the itch.io screenshots from the real renderer (needs Pillow and the Odin toolchain).

Runs the `shots_for_the_itch_page` test (frames in build/shots/*.ppm), then writes PNGs to
assets/screenshots/. The frames are 640x560, the game's own size.
"""
import os
import subprocess
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ODIN = os.path.expanduser(os.environ.get('ODIN', '~/ODIN/odin'))
KEEP = {  # frame -> published name (credits are left out: the page lists them as text)
    '01_start.ppm': '01-start.png',
    '02_fight.ppm': '02-fight.png',
    '03_explored.ppm': '03-explored.png',
    '04_shop.ppm': '04-shop.png',
    '05_tip.ppm': '05-tip.png',
}

os.makedirs(os.path.join(ROOT, 'build', 'shots'), exist_ok=True)
subprocess.check_call([ODIN, 'test', 'odin/tests', '-define:ODIN_TEST_THREADS=1',
                       '-define:ODIN_TEST_NAMES=tests.shots_for_the_itch_page', '-o:speed',
                       '-out:build/tests.bin'], cwd=ROOT)
out = os.path.join(ROOT, 'assets', 'screenshots')
os.makedirs(out, exist_ok=True)
for src, dst in KEEP.items():
    Image.open(os.path.join(ROOT, 'build', 'shots', src)).save(os.path.join(out, dst))
    print('wrote assets/screenshots/' + dst)
