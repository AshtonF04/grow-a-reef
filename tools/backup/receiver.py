#!/usr/bin/env python3
"""Local receiver for Studio backups.

Studio plugins can't write files directly, so tools/backup/Backup.luau serializes each service's
children with SerializationService and POSTs them here as base64. Each POST overwrites
studio_backup/<Service>.rbxm in the repo root. Restore by dragging an .rbxm into that service in Studio.

Run: python3 tools/backup/receiver.py   (listens on 127.0.0.1:34900 only)
"""
import base64
import os
import re
from http.server import BaseHTTPRequestHandler, HTTPServer

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "studio_backup")
NAME_RE = re.compile(r"^[A-Za-z0-9_]+$")


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        name = self.path.strip("/").split("?")[0]
        if not NAME_RE.match(name):
            self.send_response(400)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", 0))
        data = base64.b64decode(self.rfile.read(length))
        os.makedirs(OUT_DIR, exist_ok=True)
        tmp = os.path.join(OUT_DIR, name + ".rbxm.tmp")
        with open(tmp, "wb") as f:
            f.write(data)
        os.replace(tmp, os.path.join(OUT_DIR, name + ".rbxm"))  # atomic overwrite
        self.send_response(200)
        self.end_headers()
        self.wfile.write(f"saved {name}.rbxm ({len(data)} bytes)".encode())

    def log_message(self, fmt, *args):
        print(fmt % args, flush=True)


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 34900), Handler).serve_forever()
