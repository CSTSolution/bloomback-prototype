#!/usr/bin/env python3
"""Band screen mirror for the demo: shows the band's 0.42" screen large in a browser, over USB.

  python mirror.py COM5          then open http://localhost:8765 (full screen with F11, record it or film it)

The page also has a box to send band commands (info, time = set the clock from this computer, sync ...).
Needs pyserial only (PlatformIO's Python has it: %USERPROFILE%\\.platformio\\penv\\Scripts\\python.exe).
Close `pio device monitor` first: only one program can hold the COM port.
"""
import collections
import json
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import serial

PORT_HTTP = 8765
state = {'on': None, 'hex': '', 'at': 0.0}
log = collections.deque(maxlen=14)
outbox = collections.deque()
lock = threading.Lock()


def serial_loop(port):
    while True:
        try:
            with serial.Serial(port, 115200, timeout=0.05) as s:
                log.append(f'connected to {port}')
                last_ask = 0.0
                buf = b''
                while True:
                    now = time.time()
                    while outbox:
                        cmd = outbox.popleft()
                        log.append('> ' + cmd)
                        s.write((cmd + '\n').encode())
                    if now - last_ask > 0.12:
                        s.write(b'screen\n')
                        last_ask = now
                    buf += s.read(4096)
                    while b'\n' in buf:
                        line, buf = buf.split(b'\n', 1)
                        text = line.decode('utf-8', 'replace').strip()
                        if text.startswith('SCREEN '):
                            parts = text.split(' ')
                            if len(parts) == 3 and len(parts[2]) == 720:
                                with lock:
                                    state.update(on=parts[1] == '1', hex=parts[2], at=now)
                        elif text:
                            log.append(text[:160])
        except (serial.SerialException, OSError) as e:
            log.append(f'waiting for {port} ({e.__class__.__name__})')
            time.sleep(1.0)


PAGE = """<!doctype html><html><head><meta charset="utf-8"><title>BloomBack band</title>
<style>
 body{margin:0;background:#f7f3ea;font-family:Arial,sans-serif;color:#1c2b24;display:flex;flex-direction:column;
      align-items:center;justify-content:center;min-height:100vh}
 h1{font-size:28px;color:#278552;margin:0 0 6px} p{margin:0 0 22px;color:#6e7670}
 .band{background:#3e4f63;border-radius:60px;padding:min(70px,6vw) min(46px,4vw)}
 .face{background:#1e2622;border-radius:26px;padding:26px}
 canvas{display:block;image-rendering:pixelated;width:min(864px,78vw);height:auto}
 #log{font:13px monospace;color:#6e7670;margin-top:22px;white-space:pre;min-height:120px;width:min(900px,90vw);overflow:hidden}
 form{margin-top:14px} input{font-size:16px;padding:6px 10px;width:320px}
</style></head><body>
<h1>BloomBack band</h1><p>Live screen of the ESP32-C3 band over USB (72 × 40 pixels, shown 12× larger)</p>
<div class="band"><div class="face"><canvas id="c" width="864" height="480"></canvas></div></div>
<form id="f"><input id="cmd" placeholder="command: info · time · sync 0" autocomplete="off"></form>
<div id="log"></div>
<script>
const c=document.getElementById('c'),g=c.getContext('2d'),S=12;
async function tick(){
 try{const r=await (await fetch('/frame')).json();
  g.fillStyle='#05080a';g.fillRect(0,0,c.width,c.height);
  if(r.hex&&r.on){g.fillStyle='#e8f6ff';
   for(let p=0;p<5;p++)for(let x=0;x<72;x++){const b=parseInt(r.hex.substr((p*72+x)*2,2),16);
    for(let k=0;k<8;k++)if(b>>k&1)g.fillRect(x*S,(p*8+k)*S,S-1,S-1);}}
  else{g.fillStyle='#3a4a44';g.font='28px Arial';g.textAlign='center';
   g.fillText(r.hex?'screen off · press the button':'waiting for the band…',c.width/2,c.height/2);}
  document.getElementById('log').textContent=r.log.join('\\n');
 }catch(e){}
 setTimeout(tick,120);}
tick();
document.getElementById('f').onsubmit=async e=>{e.preventDefault();const i=document.getElementById('cmd');
 await fetch('/cmd',{method:'POST',body:i.value});i.value='';};
</script></body></html>"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, body, ctype):
        data = body.encode()
        self.send_response(200)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path.startswith('/frame'):
            with lock:
                fresh = time.time() - state['at'] < 2
                body = json.dumps({'on': bool(state['on']) and fresh, 'hex': state['hex'] if fresh else '',
                                   'log': list(log)})
            self._send(body, 'application/json')
        else:
            self._send(PAGE, 'text/html; charset=utf-8')

    def do_POST(self):
        n = int(self.headers.get('Content-Length', 0))
        cmd = self.rfile.read(min(n, 200)).decode('utf-8', 'replace').strip()
        if cmd == 'time':
            tz_min = -(time.altzone if time.localtime().tm_isdst else time.timezone) // 60
            cmd = f'time {int(time.time())} {tz_min}'
        if cmd and cmd != 'screen':
            outbox.append(cmd)
        self._send('ok', 'text/plain')


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    threading.Thread(target=serial_loop, args=(sys.argv[1],), daemon=True).start()
    print(f'open http://localhost:{PORT_HTTP}  (Ctrl+C to stop)')
    ThreadingHTTPServer(('127.0.0.1', PORT_HTTP), Handler).serve_forever()


if __name__ == '__main__':
    main()
