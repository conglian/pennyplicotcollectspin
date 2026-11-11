#!/usr/bin/env python3
"""下载或读取 PNG，无损重压缩、校验后原子导入；只依赖 Python 3 标准库。"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import struct
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import zlib


SIGNATURE = b"\x89PNG\r\n\x1a\n"


def read_png(data):
    """保留所有数据块，校验 CRC 和完整图像流，不转换像素或元数据。"""
    if not data.startswith(SIGNATURE):
        raise ValueError("输入不是 PNG，不能通过修改扩展名导入")
    chunks = []
    offset = len(SIGNATURE)
    idat_ended = False
    seen_idat = False
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError("PNG 数据块不完整")
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + length
        if end > len(data):
            raise ValueError("PNG 数据块长度超出文件")
        body = data[offset + 8:end - 4]
        checksum = struct.unpack_from(">I", data, end - 4)[0]
        if zlib.crc32(kind + body) & 0xFFFFFFFF != checksum:
            raise ValueError("PNG CRC 校验失败")
        if kind in (b"acTL", b"fcTL", b"fdAT"):
            raise ValueError("此脚本仅处理静态 PNG，不能导入 APNG 动画")
        if kind == b"IDAT":
            if idat_ended:
                raise ValueError("PNG IDAT 数据块必须连续")
            seen_idat = True
        elif seen_idat:
            idat_ended = True
        chunks.append((kind, body))
        offset = end
        if kind == b"IEND":
            break
    if not chunks or chunks[0][0] != b"IHDR" or len(chunks[0][1]) != 13:
        raise ValueError("PNG 缺少有效 IHDR")
    if sum(kind == b"IHDR" for kind, _ in chunks) != 1:
        raise ValueError("PNG 含重复 IHDR")
    if chunks[-1] != (b"IEND", b"") or offset != len(data) or not seen_idat:
        raise ValueError("PNG 缺少 IDAT/IEND，或文件尾含多余数据")
    width, height, depth, color, compression, filtering, interlace = struct.unpack(
        ">IIBBBBB", chunks[0][1]
    )
    depths = {0: (1, 2, 4, 8, 16), 2: (8, 16), 3: (1, 2, 4, 8),
              4: (8, 16), 6: (8, 16)}
    if (width == 0 or height == 0 or depth not in depths.get(color, ())
            or compression != 0 or filtering != 0 or interlace not in (0, 1)):
        raise ValueError("PNG IHDR 参数无效")
    packed = b"".join(body for kind, body in chunks if kind == b"IDAT")
    decoder = zlib.decompressobj()
    stream = decoder.decompress(packed) + decoder.flush()
    if not decoder.eof or decoder.unused_data or decoder.unconsumed_tail:
        raise ValueError("PNG 图像压缩流不完整或包含多余数据")
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color]
    passes = ((0, 0, 1, 1),) if interlace == 0 else (
        (0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4),
        (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2),
    )
    position = 0
    for x, y, dx, dy in passes:
        columns = max(0, (width - x + dx - 1) // dx)
        rows = max(0, (height - y + dy - 1) // dy)
        if not columns or not rows:
            continue
        stride = (columns * channels * depth + 7) // 8 + 1
        end = position + rows * stride
        if end > len(stream) or any(stream[p] > 4 for p in range(position, end, stride)):
            raise ValueError("PNG 图像扫描线长度或过滤类型无效")
        position = end
    if position != len(stream):
        raise ValueError("PNG 图像扫描线存在多余数据")
    return chunks, stream, (width, height)


def make_chunk(kind, body):
    return (struct.pack(">I", len(body)) + kind + body
            + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))


def optimize_png(original):
    """仅压缩原扫描线；保留更小的结果并再次证明图像及元数据一致。"""
    chunks, stream, size = read_png(original)
    best = original
    for strategy in (zlib.Z_DEFAULT_STRATEGY, zlib.Z_FILTERED, zlib.Z_RLE):
        encoder = zlib.compressobj(9, zlib.DEFLATED, 15, 9, strategy)
        packed = encoder.compress(stream) + encoder.flush()
        output = [SIGNATURE]
        written_idat = False
        for kind, body in chunks:
            if kind == b"IDAT":
                if not written_idat:
                    output.append(make_chunk(kind, packed))
                    written_idat = True
            else:
                output.append(make_chunk(kind, body))
        candidate = b"".join(output)
        if len(candidate) < len(best):
            best = candidate
    checked_chunks, checked_stream, checked_size = read_png(best)
    metadata = [chunk for chunk in chunks if chunk[0] != b"IDAT"]
    checked_metadata = [chunk for chunk in checked_chunks if chunk[0] != b"IDAT"]
    if checked_stream != stream or checked_metadata != metadata or checked_size != size:
        raise ValueError("无损校验失败，拒绝写入")
    return best, size, hashlib.sha256(stream).hexdigest()


def read_source(source):
    if urllib.parse.urlsplit(source).scheme.lower() in ("http", "https"):
        request = urllib.request.Request(source, headers={"User-Agent": "PennyPilot-Assets/1.0"})
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.read()
    return Path(source).read_bytes()


def import_png(source, output, expected_size=None, replace=False):
    original = read_source(source)
    optimized, size, digest = optimize_png(original)
    if expected_size is not None and tuple(expected_size) != size:
        raise ValueError("导出像素尺寸不符：实际 %s，预期 %s" % (size, tuple(expected_size)))
    target = Path(output).absolute()
    if target.suffix.lower() != ".png":
        raise ValueError("目标文件必须使用 .png 扩展名")
    if target.is_symlink():
        raise ValueError("目标是符号链接，请使用实际资源路径")
    exists = target.exists()
    unchanged = exists and target.read_bytes() == optimized
    if exists and not unchanged and not replace:
        raise ValueError("目标文件已存在；确认是对应素材的更新时使用 --replace")
    if not unchanged:
        target.parent.mkdir(parents=True, exist_ok=True)
        permissions = stat.S_IMODE(target.stat().st_mode) if exists else 0o644
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".png-import-", delete=False) as handle:
                temporary = Path(handle.name)
                handle.write(optimized)
                handle.flush()
                os.fsync(handle.fileno())
            temporary.chmod(permissions)
            os.replace(temporary, target)
        finally:
            if temporary is not None and temporary.exists():
                temporary.unlink()
    return {
        "path": str(target), "width": size[0], "height": size[1],
        "original_bytes": len(original), "output_bytes": len(optimized),
        "saved_bytes": len(original) - len(optimized),
        "saved_percent": round((1 - len(optimized) / len(original)) * 100, 2),
        "compressed": len(optimized) < len(original), "unchanged": unchanged,
        "lossless_verified": True, "image_data_sha256": digest,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", help="Figma 导出 URL 或已下载的本地 PNG 路径")
    parser.add_argument("--output", required=True, help="项目中的目标 PNG 路径")
    parser.add_argument("--expected-size", type=int, nargs=2, metavar=("WIDTH", "HEIGHT"))
    parser.add_argument("--replace", action="store_true", help="替换已确认对应同一素材的文件")
    args = parser.parse_args()
    try:
        result = import_png(args.source, args.output, args.expected_size, args.replace)
    except (OSError, ValueError, zlib.error, urllib.error.URLError) as error:
        print("PNG 导入失败：%s" % error, file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
