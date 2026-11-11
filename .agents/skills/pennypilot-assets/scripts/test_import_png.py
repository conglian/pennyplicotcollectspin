"""验证无损导入、文件保护及 URL 下载行为；不依赖第三方图片库。"""

from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch
import zlib

import import_png


def chunk(kind, body):
    return (struct.pack(">I", len(body)) + kind + body
            + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))


def fixture(width=48, height=36, color=6, depth=8, stream=None, extras=(), interlace=0):
    if stream is None:
        # 同时覆盖完全透明、半透明和不透明像素。
        row = bytes((12, 88, 201, 0, 2, 30, 40, 128, 50, 60, 70, 255)) * (width // 3)
        stream = (b"\x00" + row) * height
    header = struct.pack(">IIBBBBB", width, height, depth, color, 0, 0, interlace)
    packed = zlib.compress(stream, level=0)
    split = len(packed) // 2
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
            + b"".join(chunk(kind, body) for kind, body in extras)
            + chunk(b"IDAT", packed[:split]) + chunk(b"IDAT", packed[split:])
            + chunk(b"tEXt", b"source\x00Figma fixture") + chunk(b"IEND", b""))


@contextmanager
def serve(data):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *args):
            pass

    server = HTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield "http://127.0.0.1:%d/figma-export.png" % server.server_port
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


class PngImportTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "source.png"
        self.source.write_bytes(fixture())
        self.output = self.root / "assets" / "pc_test.png"

    def test_smaller_rgba_preserves_transparency_and_color_metadata(self):
        original = fixture(extras=((b"sRGB", b"\x00"), (b"gAMA", struct.pack(">I", 45455))))
        self.source.write_bytes(original)
        result = import_png.import_png(str(self.source), self.output, (48, 36))
        written = self.output.read_bytes()
        before, pixels, size = import_png.read_png(original)
        after, checked_pixels, checked_size = import_png.read_png(written)
        self.assertLess(len(written), len(original))
        self.assertEqual(pixels, checked_pixels)
        self.assertEqual(size, checked_size)
        self.assertEqual([c for c in before if c[0] != b"IDAT"],
                         [c for c in after if c[0] != b"IDAT"])
        self.assertTrue(result["lossless_verified"])

    def test_palette_transparency_and_one_bit_pixels_survive(self):
        original = fixture(8, 2, color=3, depth=1, stream=b"\x00\xaa\x00\x55",
                           extras=((b"PLTE", b"\x00\x00\x00\xff\xff\xff"),
                                   (b"tRNS", b"\x00\xff")))
        optimized, size, _ = import_png.optimize_png(original)
        chunks, stream, _ = import_png.read_png(optimized)
        self.assertEqual(size, (8, 2))
        self.assertEqual(stream, b"\x00\xaa\x00\x55")
        self.assertIn((b"tRNS", b"\x00\xff"), chunks)

    def test_small_optimized_png_is_kept_byte_for_byte(self):
        header = struct.pack(">IIBBBBB", 1, 1, 8, 0, 0, 0, 0)
        original = (import_png.SIGNATURE + chunk(b"IHDR", header)
                    + chunk(b"IDAT", zlib.compress(b"\x00\x11", 9)) + chunk(b"IEND", b""))
        optimized, _, _ = import_png.optimize_png(original)
        self.assertEqual(optimized, original)

    def test_corrupt_input_does_not_replace_existing_asset(self):
        self.output.parent.mkdir()
        self.output.write_bytes(b"existing asset")
        corrupted = bytearray(self.source.read_bytes())
        corrupted[50] ^= 1
        self.source.write_bytes(corrupted)
        with self.assertRaisesRegex(ValueError, "CRC"):
            import_png.import_png(str(self.source), self.output, replace=True)
        self.assertEqual(self.output.read_bytes(), b"existing asset")
        self.assertEqual(list(self.output.parent.iterdir()), [self.output])

    def test_wrong_dimensions_and_html_cannot_be_imported(self):
        with self.assertRaisesRegex(ValueError, "尺寸不符"):
            import_png.import_png(str(self.source), self.output, (144, 108))
        self.source.write_text("<html>expired Figma link</html>")
        with self.assertRaisesRegex(ValueError, "不是 PNG"):
            import_png.import_png(str(self.source), self.output)
        self.assertFalse(self.output.exists())

    def test_existing_asset_requires_replace_and_rerun_is_idempotent(self):
        self.output.parent.mkdir()
        self.output.write_bytes(b"older asset")
        with self.assertRaisesRegex(ValueError, "已存在"):
            import_png.import_png(str(self.source), self.output)
        self.assertEqual(self.output.read_bytes(), b"older asset")
        import_png.import_png(str(self.source), self.output, replace=True)
        timestamp = self.output.stat().st_mtime_ns
        result = import_png.import_png(str(self.source), self.output)
        self.assertTrue(result["unchanged"])
        self.assertEqual(self.output.stat().st_mtime_ns, timestamp)

    def test_png_animation_is_not_silently_flattened(self):
        original = fixture(extras=((b"acTL", struct.pack(">II", 1, 0)),))
        with self.assertRaisesRegex(ValueError, "APNG"):
            import_png.optimize_png(original)

    def test_pixel_change_is_rejected_before_writing(self):
        original_chunk = import_png.make_chunk
        _, stream, _ = import_png.read_png(self.source.read_bytes())
        changed = stream[:1] + bytes((stream[1] ^ 1,)) + stream[2:]

        def altered_chunk(kind, body):
            if kind == b"IDAT":
                body = zlib.compress(changed, 9)
            return original_chunk(kind, body)

        with patch.object(import_png, "make_chunk", side_effect=altered_chunk):
            with self.assertRaisesRegex(ValueError, "无损校验失败"):
                import_png.import_png(str(self.source), self.output)
        self.assertFalse(self.output.exists())

    def test_incomplete_zlib_stream_is_rejected(self):
        header = struct.pack(">IIBBBBB", 1, 1, 8, 0, 0, 0, 0)
        bad = (import_png.SIGNATURE + chunk(b"IHDR", header)
               + chunk(b"IDAT", zlib.compress(b"\x00\x11")[:-2]) + chunk(b"IEND", b""))
        with self.assertRaisesRegex(ValueError, "压缩流不完整"):
            import_png.optimize_png(bad)

    def test_cli_downloads_url_compresses_and_returns_verified_json(self):
        with serve(self.source.read_bytes()) as url:
            command = [sys.executable, "-B", str(Path(import_png.__file__)), url,
                       "--output", str(self.output), "--expected-size", "48", "36"]
            process = subprocess.run(command, capture_output=True, text=True, timeout=10)
        self.assertEqual(process.returncode, 0, process.stderr)
        result = json.loads(process.stdout)
        self.assertTrue(result["lossless_verified"])
        self.assertEqual((result["width"], result["height"]), (48, 36))
        self.assertLess(result["output_bytes"], result["original_bytes"])
        self.assertNotIn(url, process.stdout)


if __name__ == "__main__":
    unittest.main()
