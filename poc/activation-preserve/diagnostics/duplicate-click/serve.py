#!/usr/bin/env python3
"""Local Phase 1 witness; records only test counters and match booleans."""
import argparse
import json
import time
import ctypes
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--run-dir', type=Path, required=True)
parser.add_argument('--port', type=int, default=9594)
args = parser.parse_args()
args.run_dir.mkdir(parents=True, exist_ok=True)
page = Path(__file__).with_name('BrowserTarget.html').read_bytes()
allowed = {'kind', 'count', 'trusted', 'click_count', 'command', 'user_activation', 'success', 'clipboard_match', 'uptime_ms', 'trial', 'valid_trial', 'page_session', 'event_type', 'event_sequence', 'button', 'buttons', 'pointer_type', 'event_timestamp_ms', 'page_has_focus', 'visibility', 'counter_at_event', 'target_id'}


libsystem = ctypes.CDLL('/usr/lib/libSystem.B.dylib')
class Timebase(ctypes.Structure):
    _fields_ = [('numer', ctypes.c_uint32), ('denom', ctypes.c_uint32)]
timebase = Timebase()
if libsystem.mach_timebase_info(ctypes.byref(timebase)) != 0:
    raise RuntimeError('mach_timebase_info failed')
libsystem.mach_absolute_time.restype = ctypes.c_uint64

def native_uptime_ns():
    return libsystem.mach_absolute_time() * timebase.numer // timebase.denom

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        if self.path not in ('/', '/BrowserTarget.html'):
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(page)))
        self.end_headers()
        self.wfile.write(page)

    def do_POST(self):
        if self.path != '/event':
            self.send_error(404)
            return
        length = int(self.headers.get('Content-Length', '0'))
        if not 0 < length <= 4096:
            self.send_error(400)
            return
        try:
            incoming = json.loads(self.rfile.read(length))
            if not isinstance(incoming, dict):
                raise ValueError('not a record')
            row = {key: value for key, value in incoming.items() if key in allowed}
            row['monotonic_ns_received'] = time.monotonic_ns()
            row['native_uptime_ns_received'] = native_uptime_ns()
            row['wall_time_ns_received'] = time.time_ns()
            with (args.run_dir / 'browser-events.jsonl').open('a') as out:
                out.write(json.dumps(row, sort_keys=True) + '\n')
        except (ValueError, TypeError):
            self.send_error(400)
            return
        self.send_response(204)
        self.end_headers()

print(f'Browser witness: http://127.0.0.1:{args.port}/', flush=True)
HTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
