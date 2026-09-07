import threading
import unittest
from urllib.request import urlopen, Request
from urllib.error import HTTPError
from scripts.preview_3d import make_server

class PreviewServerTests(unittest.TestCase):
    def test_only_bundled_assets_are_served(self):
        server, url = make_server()
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        try:
            with urlopen(url) as result:
                self.assertIn('3D 素材预览', result.read().decode())
                self.assertIn("frame-ancestors 'none'", result.headers['Content-Security-Policy'])
            for path in ['../backend.py', '../../backend.py', 'missing.js']:
                with self.assertRaises(HTTPError): urlopen(url + path)
            with self.assertRaises(HTTPError): urlopen(url.split('/', 3)[0]+'//'+url.split('/')[2]+'/')
            with self.assertRaises(HTTPError): urlopen(Request(url, headers={'Host':'untrusted.example'}))
            with urlopen(url+'vendor/build/three.module.js') as result:
                self.assertEqual(result.headers['Content-Type'], 'text/javascript')
        finally:
            server.shutdown(); server.server_close();thread.join()
