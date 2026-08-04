#!/usr/bin/env python3
"""Render the README support banners and buttons into docs/images/.

    python3 Scripts/gen_support_art.py        # needs rsvg-convert and ImageMagick

The art is language-neutral and only the text differs per locale, so a new language
needs two lines in BANNER and BUTTON below and nothing else. Colours come from the
site's own palette (site/style.css) so the README matches the app and the docs site.

Buttons are sized from the *rendered* label rather than an em-width guess: the four
locales mix Latin, Han and Hangul, and guessing leaves a visible gap of dead pill on
the short ones.
"""
import pathlib, random, subprocess

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parent / "docs/images"

SAND      = "#FBF6EC"
INK       = "#14181B"
CORAL     = "#FF7A59"
CORAL_DP  = "#D8532F"
OCEAN     = "#1A8A94"
OCEAN_DP  = "#12666E"

# Family list mirrors --sans in site/style.css.
FONT = "Helvetica Neue, Helvetica, PingFang TC, PingFang SC, Apple SD Gothic Neo, sans-serif"

BANNER = {
    "en":      ("Free forever — but not costless",),
    "zh-Hant": ("永遠免費 — 但不是零成本",),
    "zh-Hans": ("永远免费 — 但不是零成本",),
    "ko":      ("언제나 무료 — 하지만 공짜는 아닙니다",),
}

BUTTON = {
    "en":      "Support DiveSaveEd",
    "zh-Hant": "贊助 DiveSaveEd",
    "zh-Hans": "赞助 DiveSaveEd",
    "ko":      "DiveSaveEd 후원하기",
}

W, H = 1200, 300


def bubbles(seed=7):
    """Rising bubbles. Fixed seed so a re-render is byte-stable."""
    rnd = random.Random(seed)
    out = []
    for _ in range(26):
        cx = rnd.uniform(-20, W + 20)
        cy = rnd.uniform(-10, H + 10)
        r = rnd.choice([3, 4, 5, 6, 8, 10, 13, 17, 22])
        op = 0.05 + (22 - r) / 22 * 0.10
        out.append(
            f'<circle cx="{cx:.0f}" cy="{cy:.0f}" r="{r}" fill="#FFFFFF" opacity="{op:.3f}"/>'
            f'<circle cx="{cx:.0f}" cy="{cy:.0f}" r="{r}" fill="none" stroke="#BFEAEE" '
            f'stroke-width="1" opacity="{op*2.4:.3f}"/>'
            f'<circle cx="{cx - r*0.34:.0f}" cy="{cy - r*0.36:.0f}" r="{max(1, r*0.20):.1f}" '
            f'fill="#FFFFFF" opacity="{min(0.55, op*4):.3f}"/>'
        )
    return "\n".join(out)


def heart(cx, cy, s):
    """A heart drawn as two arcs and a point, scaled about (cx, cy)."""
    return (f'<path transform="translate({cx},{cy}) scale({s}) translate(-12,-11)" '
            'd="M12 21s-7.5-4.9-9.9-9.3C.4 8.3 1.9 4.4 5.3 3.3 7.7 2.5 10.3 3.4 12 5.4c1.7-2 '
            '4.3-2.9 6.7-2.1 3.4 1.1 4.9 5 3.2 8.4C19.5 16.1 12 21 12 21z" />')


def rays():
    out = []
    for x, w, op in ((180, 120, 0.055), (430, 190, 0.040), (760, 140, 0.048), (1010, 100, 0.032)):
        out.append(f'<polygon points="{x},-40 {x+w},-40 {x+w+180},{H+40} {x+120},{H+40}" '
                   f'fill="#CFF3F6" opacity="{op}"/>')
    return "\n".join(out)


def kelp(x, h, sway, w, op):
    """One seaweed stalk, rooted at the seabed and bending with the current."""
    return (f'<path d="M{x},300 C{x+sway*0.3:.0f},{300-h*0.35:.0f} {x-sway*0.4:.0f},{300-h*0.7:.0f} '
            f'{x+sway:.0f},{300-h:.0f}" fill="none" stroke="#03212A" stroke-width="{w}" '
            f'stroke-linecap="round" opacity="{op}"/>')


def fish(x, y, s, op, flip=False):
    """A minimal fish silhouette — body, tail, eye notch."""
    sx = -s if flip else s
    return (f'<g transform="translate({x},{y}) scale({sx},{s})" fill="#04252E" opacity="{op}">'
            '<path d="M0,0 C6,-7 20,-9 28,0 C20,9 6,7 0,0 Z"/>'
            '<path d="M-1,0 L-11,-7 L-9,0 L-11,7 Z"/>'
            '</g>')


def reef():
    parts = [
        kelp(1062, 176, 26, 9, 0.62), kelp(1018, 128, -20, 7, 0.52),
        kelp(1106, 208, 18, 11, 0.68), kelp(969, 92, 22, 6, 0.42),
        kelp(1150, 150, -24, 8, 0.55),
        # a low rock, so the stalks look rooted rather than floating
        '<path d="M980,300 C1010,262 1074,250 1122,262 C1164,272 1190,262 1200,254 L1200,300 Z" '
        'fill="#03212A" opacity="0.6"/>',
        fish(880, 126, 1.5, 0.28), fish(946, 158, 1.0, 0.20),
        fish(792, 176, 0.85, 0.16, flip=True),
    ]
    return "\n    ".join(parts)


def banner_svg(tagline):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
  <defs>
    <linearGradient id="sea" x1="0" y1="0" x2="0.35" y2="1">
      <stop offset="0" stop-color="#17727C"/>
      <stop offset="0.55" stop-color="#0C4A54"/>
      <stop offset="1" stop-color="#062B33"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0" r="0.9">
      <stop offset="0" stop-color="#7FE0E8" stop-opacity="0.30"/>
      <stop offset="1" stop-color="#7FE0E8" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="coral" x1="0" y1="0" x2="0.4" y2="1">
      <stop offset="0" stop-color="#FF9A7C"/>
      <stop offset="0.5" stop-color="{CORAL}"/>
      <stop offset="1" stop-color="{CORAL_DP}"/>
    </linearGradient>
    <radialGradient id="heartglow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="{CORAL}" stop-opacity="0.45"/>
      <stop offset="1" stop-color="{CORAL}" stop-opacity="0"/>
    </radialGradient>
    <clipPath id="round"><rect x="0" y="0" width="{W}" height="{H}" rx="22" ry="22"/></clipPath>
  </defs>

  <g clip-path="url(#round)">
    <rect width="{W}" height="{H}" fill="url(#sea)"/>
    <rect width="{W}" height="{H}" fill="url(#glow)"/>
    {rays()}
    {bubbles()}

    <!-- seabed swell -->
    <path d="M0,258 C160,232 300,286 470,268 C640,250 760,290 920,272 C1040,258 1130,286 1200,272 L1200,300 L0,300 Z"
          fill="#04222A" opacity="0.55"/>
    <path d="M0,276 C180,254 320,300 500,284 C680,268 800,302 980,288 C1090,279 1150,298 1200,290 L1200,300 L0,300 Z"
          fill="#031A21" opacity="0.7"/>

    {reef()}

    <!-- the heart, floating up with the bubbles -->
    <circle cx="158" cy="146" r="86" fill="url(#heartglow)"/>
    <g transform="rotate(-9 158 146)">
      {heart(158, 146, 4.6)}
      <ellipse cx="132" cy="112" rx="17" ry="11" fill="#FFFFFF" opacity="0.30"
               transform="rotate(-32 132 112)"/>
    </g>

    <text x="292" y="140" font-family="{FONT}" font-size="70" font-weight="700"
          fill="{SAND}" letter-spacing="-1.5">DiveSaveEd</text>
    <rect x="296" y="163" width="86" height="5" rx="2.5" fill="{CORAL}"/>
    <text x="292" y="212" font-family="{FONT}" font-size="31" font-weight="500"
          fill="#AEDDE2">{tagline}</text>
  </g>
</svg>'''.replace('d="M12 21s', f'fill="url(#coral)" d="M12 21s')


BH = 88
FS = 27          # button label size
PAD_L, PAD_R = 74, 34    # text baseline start, and space after the last glyph


def text_width(label):
    """Measure the rendered label rather than guessing: the four locales mix Latin,
    Han and Hangul, and estimating em widths gets the pill padding visibly wrong."""
    probe = OUT / "_probe.svg"
    probe.write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="120">'
        f'<text x="20" y="80" font-family="{FONT}" font-size="{FS}" font-weight="600" '
        f'fill="#000">{label}</text></svg>', encoding="utf-8")
    png = OUT / "_probe.png"
    subprocess.run(["rsvg-convert", "-o", str(png), str(probe)], check=True)
    box = subprocess.run(["magick", "identify", "-format", "%@", str(png)],
                         capture_output=True, text=True, check=True).stdout
    w = int(box.split("x")[0])           # "WxH+X+Y"
    probe.unlink(); png.unlink()
    return w


def button_svg(label):
    BW = PAD_L + text_width(label) + PAD_R
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{BW}" height="{BH}" viewBox="0 0 {BW} {BH}">
  <defs>
    <linearGradient id="pill" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FF8E6C"/>
      <stop offset="1" stop-color="{CORAL_DP}"/>
    </linearGradient>
    <linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.30"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect x="6" y="8" width="{BW-12}" height="{BH-18}" rx="{(BH-18)/2}" fill="{CORAL_DP}" opacity="0.22"/>
  <rect x="6" y="4" width="{BW-12}" height="{BH-16}" rx="{(BH-16)/2}" fill="url(#pill)"/>
  <rect x="6" y="4" width="{BW-12}" height="{(BH-16)/2}" rx="{(BH-16)/4}" fill="url(#sheen)"/>
  <g transform="translate(46,{BH/2 - 2}) scale(1.35) translate(-12,-11)" fill="#FFFFFF">
    <path d="M12 21s-7.5-4.9-9.9-9.3C.4 8.3 1.9 4.4 5.3 3.3 7.7 2.5 10.3 3.4 12 5.4c1.7-2 4.3-2.9 6.7-2.1 3.4 1.1 4.9 5 3.2 8.4C19.5 16.1 12 21 12 21z"/>
  </g>
  <text x="{PAD_L}" y="{BH/2 + 6}" font-family="{FONT}" font-size="27" font-weight="600"
        fill="#FFFFFF">{label}</text>
</svg>'''


def render(svg, name, scale):
    src = OUT / f"{name}.svg"
    src.write_text(svg, encoding="utf-8")
    png = OUT / f"{name}.png"
    subprocess.run(["rsvg-convert", "-z", str(scale), "-o", str(png), str(src)], check=True)
    src.unlink()
    return png


if __name__ == "__main__":
    for loc, (tag,) in BANNER.items():
        p = render(banner_svg(tag), f"support-banner-{loc}", 2)
        print(p.name, p.stat().st_size)
    for loc, label in BUTTON.items():
        p = render(button_svg(label), f"btn-support-{loc}", 2)
        print(p.name, p.stat().st_size)
