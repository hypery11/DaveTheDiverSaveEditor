#!/usr/bin/env python3
"""Inflate the zlib-compressed `embedded_sql_compressed[]` blob from the
upstream `embedded_sql.h` and emit the plaintext SQL dump on stdout."""
import re
import sys
import zlib


def main() -> int:
    if len(sys.argv) != 2:
        sys.stderr.write("usage: inflate_embedded_sql.py <path-to-embedded_sql.h>\n")
        return 2
    header = sys.argv[1]
    with open(header, "r", encoding="utf-8", errors="strict") as fh:
        src = fh.read()
    m = re.search(r"embedded_sql_compressed\[\]\s*=\s*\{(.*?)\};", src, re.S)
    if not m:
        sys.stderr.write("error: embedded_sql_compressed[] array not found\n")
        return 1
    nums = re.findall(r"0x[0-9a-fA-F]{2}", m.group(1))
    if not nums:
        sys.stderr.write("error: no hex byte literals found in array\n")
        return 1
    blob = bytes(int(tok, 16) for tok in nums)
    sql = zlib.decompress(blob)            # raw zlib stream (0x78 0xda header)
    sys.stdout.buffer.write(sql)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
