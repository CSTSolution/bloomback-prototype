#!/usr/bin/env python3
"""Send one command line to the band over USB serial and print what comes back (for agents; no interactive monitor).

  python bbserial.py COM5 info
  python bbserial.py COM5 time            # sets the band clock to now (UTC + this computer's time zone)
  python bbserial.py COM5 --listen 10     # just print what the band says for 10 s (press RST to see the boot lines)

Needs pyserial (PlatformIO's own Python has it: %USERPROFILE%\\.platformio\\penv\\Scripts\\python.exe).
Do not save `sync` or `export` output from a band someone wore in git (real health data).
"""
import sys
import time

import serial


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    port, rest = a[0], a[1:]
    listen = 3.0
    if rest[:1] == ['--listen']:
        listen, rest = float(rest[1]), rest[2:]
    cmd = ' '.join(rest)
    if cmd == 'time':
        tz_min = -(time.altzone if time.localtime().tm_isdst else time.timezone) // 60
        cmd = f'time {int(time.time())} {tz_min}'
    with serial.Serial(port, 115200, timeout=0.2) as s:
        time.sleep(0.3)
        s.reset_input_buffer()
        if cmd:
            print('>', cmd)
            s.write((cmd + '\n').encode())
        end = time.time() + listen
        while time.time() < end:
            line = s.readline()
            if line:
                print(line.decode('utf-8', 'replace').rstrip())
                if line.startswith((b'OK', b'ERR', b'INFO', b'END')):
                    end = min(end, time.time() + 0.5)


if __name__ == '__main__':
    main()
