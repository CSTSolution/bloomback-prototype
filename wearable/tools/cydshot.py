#!/usr/bin/env python3
"""Screenshot of the demo board's screen (env `cyd`) over USB, as a PNG. For agents and for the deck.

  uv run --with pyserial --with pillow python tools/cydshot.py COM3 out.png
  ... cydshot.py COM3 out.png "tap 96 215"           send commands first (each waits a moment), then shoot
  ... cydshot.py COM3 - time "owner Chi"             no picture: just send commands (`time` = this computer's clock)
  ... cydshot.py COM3 out.png --preview 5            draw screen 5 (pairing code) once and shoot it
                                                     screens: 1 home, 2 check-in, 3 saved, 4 reminder,
                                                     5 pairing, 6 unpair; then page 0..4 and choice 0..2

The firmware answers the USB-only `screen` command with "SCREEN4 <on> <w> <h> <runs>": runs are a letter
a..p (palette index) followed by a run length (none = 1). The palette is the one in src/cyd/ui.cpp.
"""
import re
import sys
import time

import serial
from PIL import Image

PALETTE = [0xF4FAF5, 0xFFFFFF, 0xDCE7E0, 0x278552, 0xE3F4E9, 0xC9E8D4, 0x1E2A24, 0x66746C,
           0xFDF0D2, 0x9A6A12, 0xE2B957, 0x3E7CB1, 0xE6ECE8, 0x1D6A40, 0xFCF1D6, 0x000000]


def read_line(s, prefix, timeout):
    end = time.time() + timeout
    buf = b''
    while time.time() < end:
        buf += s.read(4096)
        while b'\n' in buf:
            line, buf = buf.split(b'\n', 1)
            text = line.decode('ascii', 'replace').strip()
            if text.startswith(prefix):
                return text
            if text:
                print(' ', text[:110])
    return None


def to_image(line):
    """A SCREEN4 line as an RGB image at the screen's own size; None if the frame is damaged."""
    parts = line.split(' ', 4)
    if len(parts) != 5 or not parts[2].isdigit() or not parts[3].isdigit():
        return None
    w, h, runs = int(parts[2]), int(parts[3]), parts[4]
    px = bytearray()
    for m in re.finditer(r'([a-p])(\d*)', runs):
        px += bytes([ord(m.group(1)) - 97]) * (int(m.group(2)) if m.group(2) else 1)
    if len(px) != w * h:
        return None
    im = Image.frombytes('P', (w, h), bytes(px))
    flat = []
    for c in PALETTE:
        flat += [(c >> 16) & 255, (c >> 8) & 255, c & 255]
    im.putpalette(flat)
    return im.convert('RGB')


def decode(line, path, scale):
    im = to_image(line)
    if im is None:
        sys.exit('bad frame (damaged SCREEN4 line)')
    w, h = im.size
    if scale > 1:
        im = im.resize((w * scale, h * scale), Image.NEAREST)
    im.save(path)
    print(f'saved {path} ({w}x{h}, backlight {"on" if line.split(" ", 2)[1] == "1" else "off"})')


def main():
    a = sys.argv[1:]
    if len(a) < 2:
        sys.exit(__doc__)
    port, path, rest = a[0], a[1], a[2:]
    scale, preview, wait = 2, None, 1.0
    cmds = []
    while rest:
        x = rest.pop(0)
        if x == '--preview':
            preview = []
            while rest and rest[0].lstrip('-').isdigit():
                preview.append(rest.pop(0))
        elif x == '--scale':
            scale = int(rest.pop(0))
        elif x == '--wait':
            wait = float(rest.pop(0))
        else:
            cmds.append(x)
    s = serial.Serial()
    s.port, s.baudrate, s.timeout = port, 115200, 0.05
    s.dtr = False  # do not reset the board when the port opens
    s.rts = False
    s.open()
    try:
        time.sleep(0.2)
        s.reset_input_buffer()
        for c in cmds:
            if c == 'time':  # like bbserial.py: the clock of this computer, with its time zone
                tz_min = -(time.altzone if time.localtime().tm_isdst else time.timezone) // 60
                c = f'time {int(time.time())} {tz_min}'
            print('>', c)
            s.write((c + '\n').encode())
            time.sleep(wait)
        if path == '-':  # commands only: show what the board answered
            read_line(s, 'SCREEN4 ', 0.6)
            return
        if preview is not None:
            s.write(('preview ' + ' '.join(preview or ['1']) + '\n').encode())
        else:
            s.write(b'screen\n')
        line = read_line(s, 'SCREEN4 ', 12)
        if not line:
            sys.exit('no SCREEN4 answer (is this the cyd firmware, and is the port free?)')
        decode(line, path, scale)
    finally:
        s.close()


if __name__ == '__main__':
    main()
