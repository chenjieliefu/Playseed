"""Serve only bundled preview assets on loopback; never expose project files."""
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import model_assets
import json
import secrets
import time
import webbrowser

ROOT = Path(__file__).resolve().parents[1] / 'tools/three-preview'

def make_server(folder=None, idea_id=None, model_id=None):
    if model_id: model_assets.read_model(folder,idea_id,model_id)
    token = secrets.token_urlsafe(24)
    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            origin = f'http://127.0.0.1:{self.server.server_port}'
            if self.headers.get('Host') != origin[7:] or self.headers.get('Origin') != origin or self.path != '/' + token + '/save-model':
                self.send_error(403); return
            try:
                size = int(self.headers.get('Content-Length', '0'))
                if not folder or not idea_id: raise ValueError('请从项目素材区打开预览后保存。')
                if not 0 < size <= model_assets.LIMIT: raise ValueError('模型大小无效。')
                self.connection.settimeout(20)
                data = self.rfile.read(size)
                result = model_assets.save_model(folder, idea_id, data)
                body = json.dumps(result, ensure_ascii=False).encode()
                self.send_response(200)
            except (ValueError, OSError) as error:
                body = json.dumps({'error':str(error)}, ensure_ascii=False).encode()
                self.send_response(400)
            self.send_header('Content-Type','application/json; charset=utf-8')
            self.send_header('Content-Length',str(len(body)))
            self.end_headers(); self.wfile.write(body)
        def do_GET(self):
            if self.headers.get('Host') != f'127.0.0.1:{self.server.server_port}':
                self.send_error(403); return
            prefix = '/' + token + '/'
            if not self.path.startswith(prefix):
                self.send_error(404); return
            relative = self.path[len(prefix):].split('?')[0] or 'index.html'
            if relative == 'selected.glb' and model_id:
                try: data=model_assets.read_model(folder,idea_id,model_id)
                except (ValueError,OSError): self.send_error(404); return
                self.send_response(200)
                self.send_header('Content-Type','model/gltf-binary')
                self.send_header('Content-Length',str(len(data)))
                self.send_header('X-Content-Type-Options','nosniff')
                self.end_headers();self.wfile.write(data);return
            path = (ROOT / relative).resolve()
            if not path.is_relative_to(ROOT.resolve()) or not path.is_file():
                self.send_error(404); return
            data = path.read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', 'text/javascript' if path.suffix == '.js' else 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(data)))
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' blob: data:; connect-src 'self' blob: data:; object-src 'none'; frame-ancestors 'none'")
            self.end_headers(); self.wfile.write(data)
        def log_message(self, *_args): pass
    server = HTTPServer(('127.0.0.1', 0), Handler)
    return server, f'http://127.0.0.1:{server.server_port}/{token}/'+('?selected=1' if model_id else '')

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--project'); parser.add_argument('--idea'); parser.add_argument('--model')
    args = parser.parse_args()
    server, url = make_server(args.project, args.idea, args.model)
    webbrowser.open(url)
    server.timeout = 1
    deadline = time.monotonic() + 3600
    while time.monotonic() < deadline:
        server.handle_request()
    server.server_close()
