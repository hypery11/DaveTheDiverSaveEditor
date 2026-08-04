# Third-Party Licenses

## DaveSaveEd (FNGarvin) — MIT

The bundled item/ingredient reference database
(`Sources/DaveSaveCore/Resources/reference.sqlite`, generated from `reference.sql`)
is produced by inflating the embedded SQL blob from
[FNGarvin/DaveSaveEd](https://github.com/FNGarvin/DaveSaveEd) (`embedded_sql.h`)
using `Scripts/inflate_embedded_sql.py` and `Scripts/gen_refdb.sh`. The inflated
output is byte-identical to `reference.sql` in this repository
(SHA-256 `e34116c90c00efc4ab29b126b97d80910390a8caa73282935690a64ce8a6b0c1`,
139,056 bytes). It is therefore a derivative of that MIT-licensed work, and its
license notice is reproduced in full below, as MIT requires.

```
MIT License

Copyright (c) 2025 FNGarvin (184324400+FNGarvin@users.noreply.github.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## WhiteMinds/dave-diver-expansion — credit, no license asserted

The char-level (UTF-16 code unit) XOR codec understanding — which lets this editor
handle non-ASCII (Chinese/Korean/Japanese) saves without corruption, unlike
byte-level implementations — was informed by
[WhiteMinds/dave-diver-expansion](https://github.com/WhiteMinds/dave-diver-expansion).

That repository publishes no `LICENSE` file and GitHub reports no license for it,
so **no license is asserted on its behalf**. File-format facts and algorithms are
not copyrightable (17 U.S.C. § 102(b)); this credit is offered as a courtesy.

## SQLite — public domain

On macOS the system `libsqlite3` is linked via the SDK's `import SQLite3` module.
No SQLite source is vendored in this repository.

## Trademarks

The MIT license covers software, not names. "DAVE THE DIVER" and "MINTROCKET" are
trademarks of Nexon Korea Corporation, used here only to identify the game this tool
works with. This project is not affiliated with them.
