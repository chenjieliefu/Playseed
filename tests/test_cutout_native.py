"""Pixel regression for the bundled native processor, without Vision inference."""
import platform
import struct
import subprocess
import tempfile
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def fixture(kind="border"):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    rows = []
    for y in range(64):
        row = bytearray([0])
        for x in range(64):
            color = (0, 0, 0, 0)
            if 16 <= x <= 48 and 16 <= y <= 48:
                color = (255, 255, 255, 255) if x in (16,48) or y in (16,48) else (50,150,60,255)
            if 26 <= x <= 38 and 26 <= y <= 38: color = (255,255,255,255)
            if x == 32 and 8 <= y < 16: color = (50,150,60,128)
            if kind == "white":
                color = (255,255,255,255) if 16 <= x <= 48 and 16 <= y <= 48 else (0,0,0,0)
            if kind == "separate":
                color = (50,150,60,255) if 2 <= x <= 40 and 2 <= y <= 60 else (0,0,0,0)
                if 48 <= x <= 59 and 22 <= y <= 33: color = (255,255,255,255)
            if kind == "fine":
                color = (220,220,220,128) if x % 4 == 0 and 5 <= y <= 58 else (0,0,0,0)
                if 5 <= x <= 58 and 28 <= y <= 34: color = (255,255,255,255)
            row.extend(color)
        rows.append(bytes(row))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB',64,64,8,6,0,0,0)) + chunk(b'IDAT', zlib.compress(b''.join(rows))) + chunk(b'IEND', b'')

@unittest.skipUnless(platform.system() == 'Darwin', 'macOS native processor')
class NativeCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.base = Path(cls.temp.name)
        cls.binary = cls.base/'cutout'
        subprocess.run(['swiftc','-O',str(ROOT/'scripts/remove_background.swift'),'-o',str(cls.binary)],check=True,capture_output=True)
    @classmethod
    def tearDownClass(cls): cls.temp.cleanup()

    def test_preserve_valid_alpha_and_clean_only_boundary(self):
        source=self.base/'source.png';source.write_bytes(fixture())
        copy=self.base/'copy.png';clean=self.base/'clean.png'
        subprocess.run([str(self.binary),str(source),str(copy),'0','false'],check=True,capture_output=True)
        self.assertEqual(copy.read_bytes(), source.read_bytes())
        subprocess.run([str(self.binary),str(source),str(clean),'0','true'],check=True,capture_output=True)
        check=self.base/'check.gd'
        check.write_text('''extends SceneTree
func _initialize():
 var image = Image.load_from_file(OS.get_cmdline_user_args()[0])
 assert(image.get_size() == Vector2i(64,64))
 assert(image.get_pixel(16,24).a < 0.03)
 assert(image.get_pixel(26,26).a > 0.98)
 assert(image.get_pixel(30,30).a > 0.98)
 assert(image.get_pixel(30,30).r > 0.98)
 assert(abs(image.get_pixel(32,10).a - 128.0/255.0) < 0.02)
 assert(image.get_pixel(20,24).a > 0.98)
 print("PIXEL_CHECK_OK")
 quit()
''')
        result=subprocess.run([str(ROOT/'Playseed.app/Contents/MacOS/PlayseedRuntime'),'--headless','--path',str(ROOT/'app'),'--script',str(check),'--',str(clean)],capture_output=True,text=True,timeout=15)
        self.assertIn('PIXEL_CHECK_OK',result.stdout+result.stderr)
        self.assertNotIn('SCRIPT ERROR',result.stdout+result.stderr)
        self.assertEqual(result.returncode,0)
        refused=subprocess.run([str(self.binary),str(source),str(copy),'0','false'],capture_output=True)
        self.assertNotEqual(refused.returncode,0)
        self.assertEqual(copy.read_bytes(), source.read_bytes())

    def test_white_subject_separate_subject_and_fine_details_are_protected(self):
        for kind in ["white", "separate", "fine"]:
            with self.subTest(kind=kind):
                source=self.base/(kind+".png");source.write_bytes(fixture(kind))
                original=source.read_bytes()
                result=self.base/(kind+"-clean.png")
                failed=subprocess.run([str(self.binary),str(source),str(result),'0','true'],capture_output=True,text=True)
                self.assertNotEqual(failed.returncode,0)
                self.assertIn('PLAYSEED_CUTOUT_DETAIL_LOSS',failed.stderr)
                self.assertFalse(result.exists())
                self.assertEqual(source.read_bytes(),original)
                subprocess.run([str(self.binary),str(source),str(result),'0','false'],check=True,capture_output=True)
                self.assertEqual(result.read_bytes(),original)
