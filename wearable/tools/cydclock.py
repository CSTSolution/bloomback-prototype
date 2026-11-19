#!/usr/bin/env python3
"""Keeps the demo board's clock set while you film it (env `cyd`). The board has no battery clock, so every
reset (RST button, replug) leaves it on the "open the app" screen until something sends `time`.

  uv run --with pyserial python tools/cydclock.py COM3            runs for 30 minutes, Ctrl+C to stop
  uv run --with pyserial python tools/cydclock.py COM3 90         ... for 90 minutes

It holds the COM port: stop it before flashing or using cydshot.py / cydvideo.py.
"""
import sys
import time

import serial


def send_time(s):
    tz_min = -(time.altzone if time.localtime().tm_isdst else time.timezone) // 60
    s.write(f'time {int(time.time())} {tz_min}\n'.encode())
    print(time.strftime('%H:%M:%S'), 'clock set', flush=True)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    minutes = float(sys.argv[2]) if len(sys.argv) > 2 else 30
    s = serial.Serial()
    s.port, s.baudrate, s.timeout = sys.argv[1], 115200, 0.2
    s.dtr = False  # do not reset the board when the port opens
    s.rts = False
    s.open()
    end = time.time() + minutes * 60
    try:
        time.sleep(0.2)
        s.reset_input_buffer()
        s.write(b'info\n')
        buf = b''
        while time.time() < end:
            buf += s.read(256)
            while b'\n' in buf:
                line, buf = buf.split(b'\n', 1)
                text = line.decode('ascii', 'replace').strip()
                if ' fw ' in text and text.startswith('BloomBack-'):  # the boot line: the board just restarted
                    time.sleep(1.0)
                    send_time(s)
                elif text.startswith('INFO ') and '"time_valid":false' in text:
                    send_time(s)
    except KeyboardInterrupt:
        pass
    finally:
        s.close()


if __name__ == '__main__':
    main()
