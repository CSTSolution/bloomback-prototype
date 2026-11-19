#!/usr/bin/env python3
"""Screen recording of the demo board (env `cyd`) as an MP4, frame by frame over USB.

  uv run --with pyserial --with pillow python tools/cydvideo.py COM3 out.mp4

What it is: the board's own firmware draws every frame (USB command `frame <screen> <page> <choice> <t_ms>`)
and sends the pixels back; this script follows the storyboard below at 12.5 frames a second and joins the
frames with ffmpeg. What it is not: a film of someone using the board. The round "tap" marks are added here,
at the places a pen would tap; steps, sleep and the name on screen are whatever the board shows (demo data
while the DEMO tag is on). Set the clock first (`cydshot.py COM3 - time`), or the recording shows the
"open the app" screen.
"""
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import serial
from PIL import ImageDraw

from cydshot import read_line, to_image

FRAME_MS = 80
SCALE = 3
TAB = lambda i: (32 + 64 * i, 215)  # noqa: E731  centre of tab i
# (screen, page, choice, how long in ms, where the pen taps at the end or None)
# screens: 0 boot splash, 1 home, 2 check-in, 3 saved, 4 reminder
STORY = [
    (0, 0, 0, 1900, None),
    (1, 0, 0, 2600, TAB(1)),
    (1, 1, 0, 3600, TAB(2)),
    (1, 2, 0, 2200, TAB(3)),
    (1, 3, 0, 2600, TAB(4)),
    (1, 4, 0, 2000, TAB(0)),
    (1, 0, 0, 1500, (160, 125)),   # Check in
    (2, 0, 0, 1500, (160, 126)),   # Partly
    (2, 0, 1, 1200, (58, 126)),    # Done
    (2, 0, 0, 1100, (221, 202)),   # Save
    (3, 0, 0, 1700, None),
    (1, 0, 0, 1500, None),
    (4, 0, 0, 2500, (231, 202)),   # reminder: Check in
    (2, 0, 0, 1200, (221, 202)),   # Save
    (3, 0, 0, 1700, None),
    (1, 0, 0, 1800, None),
]
TAP_FRAMES = 5  # the tap mark shows on the last frames of a part


def tap_mark(im, xy, k):
    """A ring closing in on the tap point; k = 0 (first) .. TAP_FRAMES-1 (the tap)."""
    d = ImageDraw.Draw(im, 'RGBA')
    x, y = xy[0] * SCALE, xy[1] * SCALE
    r = (26 - 4 * k) * SCALE // 3 + 10
    d.ellipse((x - r, y - r, x + r, y + r), outline=(30, 42, 36, 200), width=5)
    d.ellipse((x - 9, y - 9, x + 9, y + 9), fill=(226, 185, 87, 235), outline=(30, 42, 36, 220), width=2)


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    port, out = sys.argv[1], Path(sys.argv[2])
    fast = 921600
    if not shutil.which('ffmpeg'):
        sys.exit('ffmpeg is not on the PATH')
    tmp = Path(tempfile.mkdtemp(prefix='cydvideo-'))
    s = serial.Serial()
    s.port, s.baudrate, s.timeout = port, 115200, 0.02
    s.dtr = False  # do not reset the board when the port opens
    s.rts = False
    s.open()
    n = 0
    try:
        time.sleep(0.2)
        s.reset_input_buffer()
        s.write(f'baud {fast}\n'.encode())
        if not read_line(s, 'OK baud', 2):
            sys.exit('the board did not answer `baud` (is this the cyd firmware?)')
        s.flush()
        time.sleep(0.15)
        s.baudrate = fast
        time.sleep(0.15)
        s.reset_input_buffer()
        total = sum(p[3] // FRAME_MS for p in STORY)
        for screen, page, choice, ms, tap in STORY:
            frames = ms // FRAME_MS
            for f in range(frames):
                im = None
                for _ in range(4):  # a damaged frame is asked for again
                    s.write(f'frame {screen} {page} {choice} {f * FRAME_MS}\n'.encode())
                    line = read_line(s, 'SCREEN4 ', 6)
                    im = to_image(line) if line else None
                    if im is not None:
                        break
                    time.sleep(0.2)
                    s.reset_input_buffer()
                if im is None:
                    sys.exit(f'no good frame after 4 tries (frame {n})')
                im = im.resize((im.size[0] * SCALE, im.size[1] * SCALE), 0)  # 0 = nearest: crisp pixels
                if tap and f >= frames - TAP_FRAMES:
                    tap_mark(im, tap, f - (frames - TAP_FRAMES))
                im.save(tmp / f'f{n:04d}.png')
                n += 1
                if n % 25 == 0:
                    print(f'{n}/{total} frames', flush=True)
    finally:
        try:
            s.write(b'baud 115200\n')
            s.flush()
            time.sleep(0.3)
        finally:
            s.close()
    out.parent.mkdir(parents=True, exist_ok=True)
    cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(1000 / FRAME_MS), '-i', str(tmp / 'f%04d.png'),
           '-vf', 'format=yuv420p', '-c:v', 'libx264', '-crf', '14', '-preset', 'slow', '-r', '25',
           '-movflags', '+faststart', str(out)]
    subprocess.run(cmd, check=True)
    print(f'{out}: {n} frames, {n * FRAME_MS / 1000:.1f} s; frames kept in {tmp}')


if __name__ == '__main__':
    main()
