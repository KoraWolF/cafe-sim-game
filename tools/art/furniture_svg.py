"""Draws the bar's furniture, décor and room as layered SVGs in the art guide's
style: a cyberpunk dive bar (steel, chrome, grime and neon; see docs/art-guide.md).

Run:  python tools/art/furniture_svg.py
Writes art/furniture/<id>.svg, art/decor/<id>.svg, art/furniture/pod.svg and the
room: art/room/floor_a.svg, floor_b.svg, wall_plain.svg, wall_window.svg,
wall_shelf.svg and door.svg.

Style (docs/art-guide.md): outlines in a darker shade of each material (no
black), one gradient per material lit from the top-left, a flat cel shadow, a
cyan rim light on the right edges and magenta neon spill underneath.

Canvas: 4x the game size. A floor tile is a 384 x 192 diamond. A piece with a
footprint of w x d tiles has a canvas (w + d) * 192 + 2 * PAD wide; the top
corner of its top-left tile sits at (d * 192 + PAD, height - (w + d) * 96 - PAD).
The game finds that anchor from the canvas size, so every file follows it.
Rotated pieces are drawn mirrored by the game (a w x d footprint mirrored is d x w).

Editing a file by hand is fine; re-running this script overwrites it.
"""
import math
import os

PAD = 16
HX = 192.0  # half a tile's width at 4x
HY = 96.0   # half a tile's height at 4x
RIM = "#19f0ff"
ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "art")


def shade(hex_color, amount):
    """Lighter (amount > 0) or darker (amount < 0) version of a colour."""
    hex_color = hex_color.lstrip("#")
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (0, 2, 4))
    if amount >= 0:
        r, g, b = (round(c + (255 - c) * amount) for c in (r, g, b))
    else:
        r, g, b = (round(c * (1 + amount)) for c in (r, g, b))
    return "#%02x%02x%02x" % (r, g, b)


class Piece:
    def __init__(self, piece_id, w, d, height, folder):
        self.id = piece_id
        self.w, self.d = w, d
        self.width = (w + d) * HX + 2 * PAD
        self.height = (w + d) * HY + height + 2 * PAD
        self.ox = d * HX + PAD
        self.oy = self.height - (w + d) * HY - PAD
        self.folder = folder
        self.defs = []
        self.layers = []  # (name, [svg elements])
        self._grad = 0

    # --- projection -------------------------------------------------------
    def p(self, x, y, z=0.0):
        """Screen point of floor cell position (x, y) in tiles, z px (4x) up."""
        return (self.ox + (x - y) * HX, self.oy + (x + y) * HY - z)

    def pts(self, points):
        return " ".join("%.1f,%.1f" % self.p(*q) for q in points)

    # --- paint ------------------------------------------------------------
    def gradient(self, light, dark, vertical=True):
        self._grad += 1
        gid = "%s_g%d" % (self.id, self._grad)
        x2, y2 = ("0", "1") if vertical else ("1", "0")
        self.defs.append('<linearGradient id="%s" x1="0" y1="0" x2="%s" y2="%s">'
                         '<stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>'
                         % (gid, x2, y2, light, dark))
        return "url(#%s)" % gid

    def glow(self, color, radius=1.0):
        self._grad += 1
        gid = "%s_r%d" % (self.id, self._grad)
        self.defs.append('<radialGradient id="%s" r="%.2f"><stop offset="0" stop-color="%s" stop-opacity="0.85"/>'
                         '<stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient>' % (gid, radius * 0.5, color, color))
        return "url(#%s)" % gid

    def layer(self, name):
        elements = []
        self.layers.append((name, elements))
        return elements

    # --- shapes -----------------------------------------------------------
    def floor_shadow(self, out, x0, y0, w, d, grow=0.06):
        out.append('<polygon points="%s" fill="#1a1230" opacity="0.35"/>' % self.pts(
            [(x0 - grow, y0 - grow), (x0 + w + grow, y0 - grow), (x0 + w + grow, y0 + d + grow), (x0 - grow, y0 + d + grow)]))

    def box(self, out, x0, y0, w, d, z0, h, color, top=None, rim=True, outline=None):
        """An upright box: its two near sides and top, outlined, rim-lit on the right."""
        line = outline or shade(color, -0.55)
        top = top or shade(color, 0.18)
        x1, y1, z1 = x0 + w, y0 + d, z0 + h
        left = self.gradient(shade(color, 0.04), shade(color, -0.16))
        right = self.gradient(shade(color, -0.32), shade(color, -0.48))
        out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="4" stroke-linejoin="round"/>'
                   % (self.pts([(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)]), left, line))
        out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="4" stroke-linejoin="round"/>'
                   % (self.pts([(x1, y0, z1), (x1, y1, z1), (x1, y1, z0), (x1, y0, z0)]), right, line))
        if h > 30:
            foot = min(h * 0.25, 22)
            out.append('<polygon points="%s" fill="%s" opacity="0.3"/>'
                       % (self.pts([(x0, y1, z0 + foot), (x1, y1, z0 + foot), (x1, y1, z0), (x0, y1, z0)]), shade(color, -0.6)))
        out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="4" stroke-linejoin="round"/>'
                   % (self.pts([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]),
                      self.gradient(shade(top, 0.12), top), line))
        out.append('<polyline points="%s" fill="none" stroke="#ffffff" stroke-width="3" stroke-opacity="0.35" stroke-linecap="round"/>'
                   % self.pts([(x0 + 0.03, y1, z1), (x1 - 0.03, y1, z1)]))
        if rim and h > 6:
            out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="3" stroke-opacity="0.7" stroke-linecap="round"/>'
                       % (self.pts([(x1, y0, z0 + 6), (x1, y0, z1 - 2), (x1 + 0.0, y1 * 0.5 + y0 * 0.5, z1)]), RIM))

    def ellipse_xy(self, cx, cy, z, r):
        x, y = self.p(cx, cy, z)
        return x, y, r * HX * math.sqrt(2), r * HY * math.sqrt(2)

    def cylinder(self, out, cx, cy, r, z0, h, color, top=None, rim=True, outline=None, top_opacity=1.0):
        line = outline or shade(color, -0.55)
        top = top or shade(color, 0.2)
        x, y0, rx, ry = self.ellipse_xy(cx, cy, z0, r)
        y1 = y0 - h
        side = self.gradient(shade(color, 0.08), shade(color, -0.35), vertical=False)
        out.append('<path d="M %.1f %.1f L %.1f %.1f A %.1f %.1f 0 0 0 %.1f %.1f L %.1f %.1f Z" fill="%s" stroke="%s" '
                   'stroke-width="4" stroke-linejoin="round"/>' % (x - rx, y1, x - rx, y0, rx, ry, x + rx, y0, x + rx, y1,
                                                                   side, line))
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" stroke="%s" stroke-width="4" opacity="%.2f"/>'
                   % (x, y1, rx, ry, self.gradient(shade(top, 0.15), top), line, top_opacity))
        if rim and h > 6:
            out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="3" stroke-opacity="0.7" '
                       'stroke-linecap="round"/>' % (x + rx - 2, y0 - 4, x + rx - 2, y1 + 2, RIM))

    def disc(self, out, cx, cy, z, r, color, outline=None, opacity=1.0):
        x, y, rx, ry = self.ellipse_xy(cx, cy, z, r)
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" stroke="%s" stroke-width="4" opacity="%.2f"/>'
                   % (x, y, rx, ry, color, outline or shade(color if color.startswith("#") else "#888888", -0.5), opacity))

    def write(self):
        folder = os.path.join(ROOT, self.folder)
        os.makedirs(folder, exist_ok=True)
        body = []
        for name, elements in self.layers:
            body.append('  <g inkscape:groupmode="layer" id="%s" inkscape:label="%s">\n    %s\n  </g>'
                        % (name, name, "\n    ".join(elements)))
        svg = ('<?xml version="1.0" encoding="UTF-8"?>\n'
               '<!-- NanoBrew Café: %s. Made by tools/art/furniture_svg.py (see docs/art-guide.md). -->\n'
               '<svg xmlns="http://www.w3.org/2000/svg" xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" '
               'width="%d" height="%d" viewBox="0 0 %d %d">\n  <defs>\n    %s\n  </defs>\n%s\n</svg>\n'
               % (self.id, self.width, self.height, self.width, self.height, "\n    ".join(self.defs), "\n".join(body)))
        with open(os.path.join(folder, self.id + ".svg"), "w", encoding="utf-8", newline="\n") as f:
            f.write(svg)


# --- the pieces: a cyberpunk dive bar ------------------------------------------
INK = "#14111f"
PLUM = "#1f1a2e"
GUNMETAL = "#4a5068"
STEEL = "#7a829c"
CHROME = "#c9d2e3"
VINYL = "#8a1f3a"
MAGENTA = "#ff2fb4"
CYAN = "#19f0ff"
ACID = "#b6ff3b"
AMBER = "#ffb03b"
METAL_LINE = "#2a3046"


def neon(piece, out, points, color, width=6):
    """A neon tube along points (tile coordinates with z): a soft halo and a bright core."""
    pts = piece.pts(points)
    out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="%d" stroke-opacity="0.3" stroke-linecap="round" stroke-linejoin="round"/>'
               % (pts, color, width * 3))
    out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="%d" stroke-linecap="round" stroke-linejoin="round"/>' % (pts, color, width))
    out.append('<polyline points="%s" fill="none" stroke="#ffffff" stroke-width="%d" stroke-opacity="0.6" stroke-linecap="round" stroke-linejoin="round"/>'
               % (pts, max(width // 3, 1)))


def spill(piece, out, x0, y0, w, d, color, grow=0.12):
    """Neon light spilling on the floor under a piece."""
    out.append('<polygon points="%s" fill="%s" opacity="0.22"/>' % (piece.pts(
        [(x0 - grow, y0 - grow), (x0 + w + grow, y0 - grow), (x0 + w + grow, y0 + d + grow), (x0 - grow, y0 + d + grow)]), color))


def scuffs(piece, out, x, y, z, count=3, color="#000000"):
    """A few scratches on a face near (x, y, z)."""
    cx, cy = piece.p(x, y, z)
    for i in range(count):
        out.append('<path d="M %.1f %.1f l %d %d" stroke="%s" stroke-width="2" opacity="0.35"/>' % (cx + i * 9 - 10, cy + i * 5, 10 + i * 3, -4 + i, color))


def seat(name, back):
    """A chrome bar stool with an oxblood vinyl seat and a neon ring; back = "" (none),
    "far" (upper-left edge) or "near" (lower-right edge)."""
    piece = Piece(name, 1, 1, 210, "furniture")
    out = piece.layer("shadow")
    spill(piece, out, 0.2, 0.2, 0.6, 0.6, MAGENTA, 0.06)
    if back == "far":
        backrest(piece, 0.14)
    out = piece.layer("stool")
    piece.disc(out, 0.5, 0.5, 2, 0.24, GUNMETAL, outline=METAL_LINE)
    piece.cylinder(out, 0.5, 0.5, 0.05, 0, 70, CHROME, rim=False, outline=METAL_LINE)
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 24, 0.2)
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="none" stroke="%s" stroke-width="7"/>' % (x, y, rx, ry, CHROME))
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="none" stroke="%s" stroke-width="3" opacity="0.9"/>' % (x, y + 4, rx, ry, MAGENTA))
    piece.cylinder(out, 0.5, 0.5, 0.34, 68, 22, VINYL, top=shade(VINYL, 0.15))
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 90, 0.34)
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="none" stroke="%s" stroke-width="3" stroke-dasharray="8 7" opacity="0.6"/>'
               % (x, y, rx * 0.78, ry * 0.78, shade(VINYL, -0.4)))
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#ffffff" opacity="0.22"/>' % (x - rx * 0.3, y - ry * 0.3, rx * 0.35, ry * 0.3))
    out.append('<path d="M %.1f %.1f l 14 6" stroke="#000000" stroke-width="3" opacity="0.35"/>' % (x + rx * 0.2, y))
    if back == "near":
        backrest(piece, 0.76)
    piece.write()


def backrest(piece, x0):
    """A low chrome backrest with a vinyl pad, along the edge at x0 (tiles)."""
    out = piece.layer("backrest")
    for y in (0.24, 0.76):
        piece.box(out, x0, y - 0.03, 0.06, 0.06, 76, 84, CHROME, outline=METAL_LINE, rim=False)
    pad_x = x0 + 0.06 if x0 < 0.5 else x0 - 0.02
    out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round"/>'
               % (piece.pts([(pad_x, 0.2, 166), (pad_x, 0.8, 166), (pad_x, 0.8, 124), (pad_x, 0.2, 124)]),
                  piece.gradient(shade(VINYL, 0.15), shade(VINYL, -0.2)), shade(VINYL, -0.55)))


def table():
    """A high bar table: chrome pedestal, a dark glass top with a neon edge, a glowing coaster."""
    piece = Piece("table", 1, 1, 200, "furniture")
    out = piece.layer("shadow")
    spill(piece, out, 0.14, 0.14, 0.72, 0.72, CYAN, 0.06)
    out = piece.layer("table")
    piece.disc(out, 0.5, 0.5, 2, 0.24, GUNMETAL, outline=METAL_LINE)
    piece.cylinder(out, 0.5, 0.5, 0.05, 4, 100, CHROME, rim=False, outline=METAL_LINE)
    piece.cylinder(out, 0.5, 0.5, 0.44, 104, 10, "#2b2540", top="#3a3156", outline="#110e1c")
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 108, 0.44)
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="none" stroke="%s" stroke-width="5" opacity="0.9"/>' % (x, y + 4, rx, ry, CYAN))
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 114, 0.44)
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#ffffff" opacity="0.08"/>' % (x - rx * 0.25, y - ry * 0.25, rx * 0.5, ry * 0.4))
    out.append('<path d="M %.1f %.1f q 18 6 30 -4" fill="none" stroke="#000000" stroke-width="4" opacity="0.4"/>' % (x + rx * 0.2, y + ry * 0.2))
    out = piece.layer("candle")
    piece.cylinder(out, 0.24, 0.3, 0.05, 114, 16, "#2a2e3f", top=AMBER, rim=False)
    cx, cy = piece.p(0.24, 0.3, 134)
    out.append('<circle cx="%.1f" cy="%.1f" r="14" fill="%s"/>' % (cx, cy, piece.glow(AMBER)))
    out.append('<circle cx="%.1f" cy="%.1f" r="4" fill="#fff1c9"/>' % (cx, cy))
    piece.write()


def stove():
    """The drink mixer (the game's "stove"): a steel station with taps, a glowing
    liquid tank, a cocktail shaker and a mixing screen."""
    piece = Piece("stove", 1, 1, 270, "furniture")
    out = piece.layer("shadow")
    spill(piece, out, 0.03, 0.03, 0.94, 0.94, MAGENTA, 0.05)
    out = piece.layer("body")
    piece.box(out, 0.03, 0.03, 0.94, 0.94, 0, 120, GUNMETAL, top="#2b2f42", outline=METAL_LINE)
    for i in range(3):
        bx, by = piece.p(0.12 + i * 0.36, 0.97, 104)
        out.append('<circle cx="%.1f" cy="%.1f" r="4" fill="%s"/>' % (bx, by, CHROME))
    neon(piece, out, [(0.08, 0.97, 10), (0.92, 0.97, 10)], MAGENTA, 4)
    out = piece.layer("taps")
    piece.box(out, 0.2, 0.16, 0.66, 0.12, 120, 70, "#2b2f42", outline=METAL_LINE)
    for i, color in enumerate((ACID, AMBER, MAGENTA)):
        tx, ty = piece.p(0.3 + i * 0.22, 0.28, 172)
        out.append('<rect x="%.1f" y="%.1f" width="10" height="26" rx="4" fill="%s" stroke="%s" stroke-width="3"/>' % (tx - 5, ty - 26, color, shade(color, -0.5)))
        out.append('<path d="M %.1f %.1f l 0 18 l 8 0" fill="none" stroke="%s" stroke-width="5"/>' % (tx, ty, CHROME))
    out = piece.layer("tank")
    piece.cylinder(out, 0.76, 0.72, 0.14, 120, 76, "#2b2f42", top="#1a1d2a", rim=False, outline=METAL_LINE)
    gx, gy, grx, gry = piece.ellipse_xy(0.76, 0.72, 128, 0.11)
    out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="58" rx="8" fill="%s" opacity="0.9"/>' % (gx - grx, gy - 62, 2 * grx, piece.gradient(ACID, "#3f8a1a")))
    for k in range(3):
        out.append('<circle cx="%.1f" cy="%.1f" r="%d" fill="#ffffff" opacity="0.6"/>' % (gx - 8 + k * 9, gy - 20 - k * 12, 3 + k % 2))
    out = piece.layer("shaker")
    piece.cylinder(out, 0.36, 0.66, 0.07, 120, 46, CHROME, top=CHROME, outline=METAL_LINE)
    sx, sy = piece.p(0.36, 0.66, 168)
    out.append('<path d="M %.1f %.1f l 12 0 l -2 -14 l -8 0 z" fill="%s" stroke="%s" stroke-width="3"/>' % (sx - 6, sy, CHROME, METAL_LINE))
    out = piece.layer("screen")
    out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="3"/>'
               % (piece.pts([(0.97, 0.22, 96), (0.97, 0.78, 96), (0.97, 0.78, 48), (0.97, 0.22, 48)]), piece.gradient(CYAN, "#0a6f86"), METAL_LINE))
    for i in range(4):
        a = piece.p(0.97, 0.3 + i * 0.12, 60)
        b = piece.p(0.97, 0.3 + i * 0.12, 60 + (12 + (i * 11) % 24))
        out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#0a2a3a" stroke-width="7"/>' % (a + b))
    scuffs(piece, out, 0.5, 0.97, 60)
    piece.write()


def counter():
    """A bar counter segment: steel front with rivets, a black top with a neon edge,
    magenta under-glow. Drinks wait on it."""
    piece = Piece("counter", 1, 1, 190, "furniture")
    out = piece.layer("shadow")
    spill(piece, out, 0.0, 0.0, 1.0, 1.0, MAGENTA, 0.1)
    out = piece.layer("front")
    piece.box(out, 0.04, 0.04, 0.92, 0.92, 0, 110, PLUM, top="#2b2540", outline="#0e0b17")
    out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="3"/>'
               % (piece.pts([(0.1, 0.96, 96), (0.9, 0.96, 96), (0.9, 0.96, 20), (0.1, 0.96, 20)]), piece.gradient(STEEL, GUNMETAL), METAL_LINE))
    for i in range(4):
        for z in (30, 86):
            rx_, ry_ = piece.p(0.16 + i * 0.22, 0.96, z)
            out.append('<circle cx="%.1f" cy="%.1f" r="4" fill="%s" stroke="%s" stroke-width="1.5"/>' % (rx_, ry_, CHROME, METAL_LINE))
    out.append('<path d="M %.1f %.1f l 26 -10 l -6 18 z" fill="%s" opacity="0.85"/>' % (piece.p(0.4, 0.96, 60) + (ACID,)))
    scuffs(piece, out, 0.7, 0.96, 50)
    out = piece.layer("top")
    piece.box(out, 0.0, 0.0, 1.0, 1.0, 110, 12, "#2a2236", top="#3a3050", outline="#0e0b17")
    neon(piece, out, [(0.02, 1.0, 108), (1.0, 1.0, 108), (1.0, 0.02, 108)], MAGENTA, 4)
    x, y = piece.p(0.5, 0.5, 122)
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="70" ry="22" fill="#ffffff" opacity="0.06"/>' % (x - 20, y - 6))
    piece.write()


def bin_piece():
    """A recycler: an industrial drum with hazard stripes and a glowing slot."""
    piece = Piece("bin", 1, 1, 180, "furniture")
    out = piece.layer("shadow")
    piece.floor_shadow(out, 0.16, 0.16, 0.68, 0.68)
    out = piece.layer("drum")
    piece.cylinder(out, 0.5, 0.5, 0.32, 0, 104, GUNMETAL, top="#2b2f42", outline=METAL_LINE)
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 30, 0.32)
    out.append('<path d="M %.1f %.1f A %.1f %.1f 0 0 0 %.1f %.1f L %.1f %.1f A %.1f %.1f 0 0 1 %.1f %.1f Z" fill="%s"/>'
               % (x - rx, y, rx, ry, x + rx, y, x + rx, y - 22, rx, ry, x - rx, y - 22, AMBER))
    for k in range(5):
        sx = x - rx + 14 + k * (2 * rx - 28) / 4
        out.append('<path d="M %.1f %.1f l 12 -22" stroke="#14111f" stroke-width="8"/>' % (sx - 6, y + ry * 0.6 - 2))
    piece.cylinder(out, 0.5, 0.5, 0.34, 104, 10, "#2b2f42", top="#1a1d2a", outline=METAL_LINE)
    hx, hy = piece.p(0.5, 0.5, 116)
    out.append('<rect x="%.1f" y="%.1f" width="54" height="10" rx="5" fill="%s"/>' % (hx - 27, hy - 5, ACID))
    out.append('<rect x="%.1f" y="%.1f" width="54" height="10" rx="5" fill="none" stroke="%s" stroke-width="10" stroke-opacity="0.3"/>' % (hx - 27, hy - 5, ACID))
    piece.write()


def register():
    """The pay terminal: a steel kiosk pillar with a holo screen and a glowing card slot."""
    piece = Piece("register", 1, 1, 230, "furniture")
    out = piece.layer("shadow")
    spill(piece, out, 0.1, 0.1, 0.8, 0.8, CYAN, 0.06)
    out = piece.layer("kiosk")
    piece.box(out, 0.1, 0.1, 0.8, 0.8, 0, 96, PLUM, top="#2b2540", outline="#0e0b17")
    neon(piece, out, [(0.14, 0.9, 80), (0.86, 0.9, 80)], CYAN, 4)
    piece.box(out, 0.3, 0.3, 0.4, 0.4, 96, 50, GUNMETAL, top="#2b2f42", outline=METAL_LINE)
    out.append('<polygon points="%s" fill="#0e0b17" stroke="%s" stroke-width="4" stroke-linejoin="round"/>'
               % (piece.pts([(0.26, 0.56, 146), (0.74, 0.56, 146), (0.74, 0.66, 214), (0.26, 0.66, 214)]), METAL_LINE))
    out.append('<polygon points="%s" fill="%s" opacity="0.95"/>'
               % (piece.pts([(0.3, 0.58, 152), (0.7, 0.58, 152), (0.7, 0.64, 208), (0.3, 0.64, 208)]), piece.gradient(CYAN, "#0a5f8a")))
    for i in range(3):
        a = piece.p(0.36, 0.61, 194 - i * 14)
        b = piece.p(0.62 - i * 0.07, 0.61, 194 - i * 14)
        out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#04202e" stroke-width="5"/>' % (a + b))
    sx, sy = piece.p(0.7, 0.7, 120)
    out.append('<rect x="%.1f" y="%.1f" width="22" height="6" rx="3" fill="%s"/>' % (sx - 11, sy - 3, ACID))
    out.append('<path d="M %.1f %.1f l -16 -10 l 12 -2 z" fill="%s" opacity="0.8"/>' % (piece.p(0.2, 0.9, 50) + (MAGENTA,)))
    piece.write()


def potted_fern():
    """A neon fern: a steel planter and fronds with glowing veins."""
    piece = Piece("potted_fern", 1, 1, 270, "decor")
    out = piece.layer("shadow")
    piece.floor_shadow(out, 0.2, 0.2, 0.6, 0.6)
    out = piece.layer("planter")
    piece.box(out, 0.25, 0.25, 0.5, 0.5, 0, 66, GUNMETAL, top="#2b1f1a", outline=METAL_LINE)
    neon(piece, out, [(0.27, 0.75, 54), (0.73, 0.75, 54)], ACID, 3)
    out = piece.layer("fronds")
    x, y = piece.p(0.5, 0.5, 66)
    for angle, length, color in ((-160, 100, "#1f6b4a"), (-20, 95, "#1f6b4a"), (-140, 130, "#2a8a5a"), (-40, 125, "#2a8a5a"),
                                 (-120, 150, "#1f6b4a"), (-60, 150, "#1f6b4a"), (-100, 170, "#33a36a"), (-80, 165, "#2a8a5a"),
                                 (-90, 185, "#3ab877")):
        a = math.radians(angle)
        tx, ty = x + math.cos(a) * length, y + math.sin(a) * length
        cx, cy = x + math.cos(a + 0.3) * length * 0.6, y + math.sin(a + 0.3) * length * 0.6 - 12
        out.append('<path d="M %.1f %.1f Q %.1f %.1f %.1f %.1f Q %.1f %.1f %.1f %.1f Z" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round"/>'
                   % (x, y, cx - 16, cy, tx, ty, cx + 16, cy + 10, x, y, color, shade(color, -0.5)))
        out.append('<path d="M %.1f %.1f Q %.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="3" opacity="0.85"/>' % (x, y, cx, cy + 4, tx, ty, ACID))
    piece.write()


def bubble_lamp():
    """An orb lamp: a chrome stand with a glowing magenta orb and a halo ring."""
    piece = Piece("bubble_lamp", 1, 1, 290, "decor")
    out = piece.layer("glow")
    x, y = piece.p(0.5, 0.5, 210)
    out.append('<circle cx="%.1f" cy="%.1f" r="140" fill="%s"/>' % (x, y, piece.glow(MAGENTA)))
    spill(piece, piece.layer("shadow"), 0.25, 0.25, 0.5, 0.5, MAGENTA, 0.15)
    out = piece.layer("lamp")
    piece.cylinder(out, 0.5, 0.5, 0.22, 0, 14, GUNMETAL, rim=False, outline=METAL_LINE)
    piece.cylinder(out, 0.5, 0.5, 0.03, 14, 150, CHROME, rim=False, outline=METAL_LINE)
    out.append('<circle cx="%.1f" cy="%.1f" r="52" fill="%s" stroke="%s" stroke-width="4"/>' % (x, y, piece.gradient("#ffd6f2", MAGENTA), shade(MAGENTA, -0.4)))
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="74" ry="18" fill="none" stroke="%s" stroke-width="5" opacity="0.9"/>' % (x, y + 6, CYAN))
    out.append('<circle cx="%.1f" cy="%.1f" r="14" fill="#ffffff" opacity="0.7"/>' % (x - 18, y - 20))
    piece.write()


def glass_pod_plant():
    """A bio pod: a glass tube of glowing green fluid with a specimen plant."""
    piece = Piece("glass_pod_plant", 1, 1, 270, "decor")
    out = piece.layer("shadow")
    spill(piece, out, 0.2, 0.2, 0.6, 0.6, ACID, 0.1)
    out = piece.layer("base")
    piece.cylinder(out, 0.5, 0.5, 0.32, 0, 34, GUNMETAL, top="#2b2f42", outline=METAL_LINE)
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 34, 0.32)
    gx = rx * 0.82
    top = y - 200
    out = piece.layer("fluid")
    out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="%s" opacity="0.75"/>' % (x - gx, top + 30, 2 * gx, 200 - 30, gx * 0.6, piece.gradient(ACID, "#1f6b2a")))
    for dx, h, color in ((-16, 110, "#1f6b4a"), (8, 140, "#2a8a5a"), (22, 90, "#1f6b4a")):
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="12" ry="%.1f" fill="%s" stroke="%s" stroke-width="3"/>' % (x + dx, y - h / 2 - 8, h / 2, color, shade(color, -0.5)))
    for k in range(5):
        out.append('<circle cx="%.1f" cy="%.1f" r="%d" fill="#ffffff" opacity="0.55"/>' % (x - 20 + k * 11, y - 40 - k * 26, 3 + k % 3))
    out = piece.layer("glass")
    out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="none" stroke="%s" stroke-width="5" opacity="0.8"/>'
               % (x - gx, top, 2 * gx, 200, gx * 0.6, CHROME))
    piece.cylinder(out, 0.5, 0.5, 0.3, 200, 18, GUNMETAL, top="#2b2f42", outline=METAL_LINE)
    out.append('<path d="M %.1f %.1f L %.1f %.1f" stroke="#ffffff" stroke-width="6" opacity="0.4"/>' % (x - gx * 0.6, y - 20, x - gx * 0.6, top + 30))
    piece.write()


def beanbag():
    """A lounge pod: a round black vinyl armchair with a neon trim."""
    piece = Piece("beanbag", 1, 1, 160, "decor")
    out = piece.layer("shadow")
    spill(piece, out, 0.08, 0.08, 0.84, 0.84, CYAN, 0.05)
    out = piece.layer("chair")
    piece.cylinder(out, 0.5, 0.5, 0.38, 0, 44, "#2a2236", top="#3a3050", outline="#0e0b17")
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 44, 0.38)
    out.append('<path d="M %.1f %.1f A %.1f %.1f 0 0 1 %.1f %.1f L %.1f %.1f A %.1f %.1f 0 0 0 %.1f %.1f Z" fill="%s" stroke="#0e0b17" stroke-width="4"/>'
               % (x - rx, y, rx, ry * 1.6, x + rx, y, x + rx * 0.7, y + 4, rx * 0.7, ry * 1.1, x - rx * 0.7, y + 4,
                  piece.gradient("#3a3050", "#1a1428")))
    out.append('<path d="M %.1f %.1f A %.1f %.1f 0 0 1 %.1f %.1f" fill="none" stroke="%s" stroke-width="5"/>' % (x - rx, y, rx, ry * 1.6, x + rx, y, CYAN))
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" stroke="#0e0b17" stroke-width="3"/>' % (x, y + 10, rx * 0.62, ry * 0.5, VINYL))
    x2, y2, rx2, ry2 = piece.ellipse_xy(0.5, 0.5, 0, 0.38)
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="none" stroke="%s" stroke-width="4" opacity="0.8"/>' % (x2, y2, rx2, ry2, MAGENTA))
    piece.write()


def led_sign():
    """A neon bar sign on a stand: a martini glass and a lightning bolt."""
    piece = Piece("led_sign", 2, 1, 250, "decor")
    out = piece.layer("shadow")
    spill(piece, out, 0.2, 0.3, 1.6, 0.4, MAGENTA, 0.1)
    out = piece.layer("stand")
    for px in (0.4, 1.6):
        piece.cylinder(out, px, 0.55, 0.04, 0, 70, CHROME, rim=False, outline=METAL_LINE)
    out = piece.layer("panel")
    piece.box(out, 0.15, 0.48, 1.7, 0.1, 70, 130, INK, top=PLUM, outline="#0a0812")
    out = piece.layer("neon")
    neon(piece, out, [(0.5, 0.58, 186), (0.9, 0.58, 186), (0.7, 0.58, 140), (0.5, 0.58, 186)], MAGENTA, 5)
    neon(piece, out, [(0.7, 0.58, 140), (0.7, 0.58, 96)], MAGENTA, 5)
    neon(piece, out, [(0.6, 0.58, 96), (0.8, 0.58, 96)], MAGENTA, 5)
    neon(piece, out, [(1.3, 0.58, 186), (1.18, 0.58, 140), (1.38, 0.58, 140), (1.24, 0.58, 96)], CYAN, 5)
    neon(piece, out, [(0.22, 0.58, 192), (1.78, 0.58, 192)], ACID, 2)
    piece.write()


def holo_menu():
    """A holo drinks menu floating over a projector."""
    piece = Piece("holo_menu", 1, 1, 270, "decor")
    out = piece.layer("shadow")
    spill(piece, out, 0.3, 0.3, 0.4, 0.4, CYAN, 0.1)
    out = piece.layer("projector")
    piece.cylinder(out, 0.5, 0.5, 0.18, 0, 50, GUNMETAL, top="#2b2f42", outline=METAL_LINE)
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 50, 0.12)
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (x, y, rx, ry, CYAN))
    out = piece.layer("hologram")
    out.append('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s" opacity="0.18"/>' % (x - rx, y, x + rx, y, x + 70, y - 90, x - 70, y - 90, CYAN))
    panel = [piece.p(0.2, 0.5, 230), piece.p(0.8, 0.5, 230), piece.p(0.8, 0.5, 100), piece.p(0.2, 0.5, 100)]
    out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="4" stroke-linejoin="round" opacity="0.7"/>'
               % (" ".join("%.1f,%.1f" % q for q in panel), piece.gradient(CYAN, "#5a1f8a"), "#9ffaff"))
    for i, color in enumerate((MAGENTA, ACID, AMBER, CYAN)):
        gx, gy = piece.p(0.3, 0.5, 206 - i * 28)
        out.append('<path d="M %.1f %.1f l 12 0 l -6 10 z" fill="%s"/>' % (gx - 6, gy - 6, color))
        a = piece.p(0.4, 0.5, 206 - i * 28)
        b = piece.p(0.68 - (i % 2) * 0.1, 0.5, 206 - i * 28)
        out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#e8fdff" stroke-width="5" opacity="0.85"/>' % (a + b))
    piece.write()


def vending_shrine():
    """A street vending machine: black body, a lit window of cans, neon trim and glyph stickers."""
    piece = Piece("vending_shrine", 1, 2, 330, "decor")
    out = piece.layer("shadow")
    spill(piece, out, 0.04, 0.04, 0.92, 1.92, CYAN, 0.1)
    out = piece.layer("machine")
    piece.box(out, 0.08, 0.1, 0.84, 1.8, 0, 270, INK, top=PLUM, outline="#0a0812")
    out = piece.layer("window")
    out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="4" stroke-linejoin="round"/>'
               % (piece.pts([(0.92, 0.25, 250), (0.92, 1.45, 250), (0.92, 1.45, 110), (0.92, 0.25, 110)]), piece.gradient("#fff6e0", "#bfe8ff"), METAL_LINE))
    colors = [MAGENTA, CYAN, AMBER, ACID, "#ff6a3d"]
    for row in range(3):
        for col in range(5):
            cx, cy = piece.p(0.92, 0.38 + col * 0.23, 225 - row * 44)
            c = colors[(row * 2 + col) % 5]
            out.append('<rect x="%.1f" y="%.1f" width="16" height="26" rx="5" fill="%s" stroke="%s" stroke-width="2"/>' % (cx - 8, cy - 13, c, shade(c, -0.5)))
    out.append('<polygon points="%s" fill="#0a0812"/>' % piece.pts([(0.92, 0.5, 80), (0.92, 1.2, 80), (0.92, 1.2, 40), (0.92, 0.5, 40)]))
    out = piece.layer("neon")
    neon(piece, out, [(0.92, 0.12, 266), (0.92, 1.88, 266)], MAGENTA, 4)
    neon(piece, out, [(0.92, 1.6, 230), (0.92, 1.6, 140)], CYAN, 4)
    for gy in (1.68, 1.76):
        a = piece.p(0.92, gy, 220)
        out.append('<path d="M %.1f %.1f l 0 18 m -6 -10 l 12 0 m -10 22 l 8 -6" stroke="%s" stroke-width="4" fill="none"/>' % (a[0], a[1], AMBER))
    sx, sy = piece.p(0.5, 1.9, 60)
    out.append('<rect x="%.1f" y="%.1f" width="40" height="26" rx="4" fill="%s" transform="rotate(-20 %.1f %.1f)"/>' % (sx, sy, ACID, sx, sy))
    piece.write()


def koi_tank():
    """A holo aquarium: a black frame, deep blue water and glowing cyber koi."""
    piece = Piece("koi_tank", 2, 2, 210, "decor")
    out = piece.layer("shadow")
    spill(piece, out, 0.04, 0.04, 1.92, 1.92, CYAN, 0.1)
    out = piece.layer("frame")
    piece.box(out, 0.06, 0.06, 1.88, 1.88, 0, 60, INK, top=PLUM, outline="#0a0812")
    neon(piece, out, [(0.06, 1.94, 54), (1.94, 1.94, 54), (1.94, 0.06, 54)], CYAN, 4)
    out = piece.layer("water")
    out.append('<polygon points="%s" fill="%s" opacity="0.6"/>' % (piece.pts([(0.12, 1.88, 60), (1.88, 1.88, 60), (1.88, 1.88, 150), (0.12, 1.88, 150)]),
                                                                    piece.gradient("#1a6fd6", "#0a1a5a")))
    out.append('<polygon points="%s" fill="%s" opacity="0.5"/>' % (piece.pts([(1.88, 0.12, 60), (1.88, 1.88, 60), (1.88, 1.88, 150), (1.88, 0.12, 150)]),
                                                                    piece.gradient("#1a4fa8", "#0a1a5a")))
    out.append('<polygon points="%s" fill="%s" opacity="0.85"/>' % (piece.pts([(0.12, 0.12, 150), (1.88, 0.12, 150), (1.88, 1.88, 150), (0.12, 1.88, 150)]),
                                                                     piece.gradient("#3fd0ff", "#1a4fa8")))
    for fx, fy, angle, color in ((0.7, 0.8, -20, MAGENTA), (1.3, 1.1, 160, CYAN), (0.9, 1.4, 40, AMBER)):
        x, y = piece.p(fx, fy, 150)
        out.append('<g transform="rotate(%d %.1f %.1f)"><ellipse cx="%.1f" cy="%.1f" rx="30" ry="12" fill="%s"/>'
                   '<path d="M %.1f %.1f l 20 -12 l 0 24 z" fill="%s"/><ellipse cx="%.1f" cy="%.1f" rx="44" ry="20" fill="%s" opacity="0.25"/></g>'
                   % (angle, x, y, x, y, color, x + 28, y, color, x, y, color))
    out = piece.layer("glass")
    out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="4" opacity="0.8"/>'
               % (piece.pts([(0.12, 1.88, 150), (0.12, 1.88, 60), (1.88, 1.88, 60), (1.88, 0.12, 60), (1.88, 0.12, 150)]), CHROME))
    piece.write()


def neon_mural():
    """A graffiti wall: a concrete slab with spray tags and a neon skull-heart."""
    piece = Piece("neon_mural", 2, 1, 290, "decor")
    out = piece.layer("shadow")
    spill(piece, out, 0.1, 0.3, 1.8, 0.4, MAGENTA, 0.1)
    out = piece.layer("wall")
    piece.box(out, 0.1, 0.45, 1.8, 0.16, 0, 250, "#3a3448", top="#4a4258", outline="#14111f")
    out = piece.layer("graffiti")
    for (y0, z0), color in (((0.25, 60), MAGENTA), ((0.9, 150), ACID), ((1.4, 70), AMBER)):
        a = piece.p(y0, 0.61, z0)
        out.append('<path d="M %.1f %.1f c 20 -30 40 10 60 -20 c 10 20 30 0 40 -10" fill="none" stroke="%s" stroke-width="9" opacity="0.85"/>' % (a[0], a[1], color))
    out.append('<path d="M %.1f %.1f l 0 -40" stroke="%s" stroke-width="4" opacity="0.6"/>' % (piece.p(0.4, 0.61, 60) + (MAGENTA,)))
    out = piece.layer("neon")
    hx, hy = piece.p(1.05, 0.61, 175)
    out.append('<path d="M %.1f %.1f c -34 -26 -48 8 0 38 c 48 -30 34 -64 0 -38 z" fill="none" stroke="%s" stroke-width="16" stroke-opacity="0.3" '
               'transform="rotate(26.6 %.1f %.1f)"/>' % (hx, hy, CYAN, hx, hy))
    out.append('<path d="M %.1f %.1f c -34 -26 -48 8 0 38 c 48 -30 34 -64 0 -38 z" fill="none" stroke="%s" stroke-width="6" '
               'transform="rotate(26.6 %.1f %.1f)"/>' % (hx, hy, CYAN, hx, hy))
    for dx in (-12, 12):
        out.append('<circle cx="%.1f" cy="%.1f" r="6" fill="%s"/>' % (hx + dx, hy + 4 + dx * 0.5, MAGENTA))
    scuffs(piece, out, 0.6, 0.61, 40, 4)
    piece.write()


def zen_garden():
    """A DJ booth: a black desk with two decks, glowing EQ bars and a speaker stack."""
    piece = Piece("zen_garden", 2, 2, 260, "decor")
    out = piece.layer("shadow")
    spill(piece, out, 0.04, 0.04, 1.92, 1.92, MAGENTA, 0.12)
    out = piece.layer("speakers")
    piece.box(out, 0.1, 0.1, 0.5, 0.5, 0, 200, INK, top=PLUM, outline="#0a0812")
    for z in (60, 140):
        x, y = piece.p(0.6, 0.35, z)
        out.append('<circle cx="%.1f" cy="%.1f" r="26" fill="#2a2236" stroke="%s" stroke-width="4"/>' % (x, y, GUNMETAL))
        out.append('<circle cx="%.1f" cy="%.1f" r="10" fill="%s"/>' % (x, y, MAGENTA))
    out = piece.layer("desk")
    piece.box(out, 0.5, 0.6, 1.4, 1.3, 0, 90, INK, top="#2a2236", outline="#0a0812")
    neon(piece, out, [(0.52, 1.9, 80), (1.9, 1.9, 80), (1.9, 0.62, 80)], CYAN, 4)
    for cx, cy in ((0.95, 1.05), (1.5, 1.45)):
        piece.disc(out, cx, cy, 90, 0.26, "#14111f", outline=GUNMETAL)
        piece.disc(out, cx, cy, 90, 0.18, "#2a2236", outline="#0a0812")
        x, y, rx, ry = piece.ellipse_xy(cx, cy, 90, 0.05)
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (x, y, rx, ry, AMBER))
    for i in range(6):
        bx, by = piece.p(1.55 + i * 0.06, 0.85 - i * 0.06, 90)
        h = 16 + (i * 13) % 30
        out.append('<rect x="%.1f" y="%.1f" width="8" height="%d" fill="%s"/>' % (bx - 4, by - h, h, [ACID, AMBER, MAGENTA][i % 3]))
    out = piece.layer("laptop")
    piece.box(out, 1.0, 0.7, 0.3, 0.22, 90, 6, GUNMETAL, outline=METAL_LINE)
    out.append('<polygon points="%s" fill="%s"/>' % (piece.pts([(1.0, 0.72, 96), (1.3, 0.72, 96), (1.3, 0.72, 140), (1.0, 0.72, 140)]), piece.gradient(MAGENTA, "#5a1f8a")))
    piece.write()


def pod():
    """A Sync Pod for the Pod bay: an industrial capsule on a hazard-striped base."""
    piece = Piece("pod", 1, 1, 340, "furniture")
    out = piece.layer("base")
    spill(piece, out, 0.18, 0.18, 0.64, 0.64, CYAN, 0.08)
    piece.cylinder(out, 0.5, 0.5, 0.3, 0, 28, GUNMETAL, top="#2b2f42", outline=METAL_LINE)
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 0, 0.3)
    for k in range(4):
        sx = x - rx + 18 + k * (2 * rx - 36) / 3
        out.append('<path d="M %.1f %.1f l 10 -18" stroke="%s" stroke-width="7"/>' % (sx - 5, y + ry * 0.7 - 6, AMBER))
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 28, 0.3)
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" opacity="0.6"/>' % (x, y, rx * 0.7, ry * 0.7, CYAN))
    out = piece.layer("glass")
    gx, top = rx * 0.82, y - 250
    out.append('<path d="M %.1f %.1f L %.1f %.1f A %.1f %.1f 0 0 1 %.1f %.1f L %.1f %.1f A %.1f %.1f 0 0 1 %.1f %.1f Z" fill="%s" '
               'stroke="%s" stroke-width="4" opacity="0.45"/>' % (x - gx, y, x - gx, top + gx, gx, gx, x + gx, top + gx, x + gx, y, gx, ry * 0.82, x - gx, y,
                                                                piece.gradient("#bff8ff", "#1a6fd6", vertical=False), CHROME))
    for side in (-1, 1):
        out.append('<path d="M %.1f %.1f L %.1f %.1f" stroke="%s" stroke-width="10"/>' % (x + side * gx, y - 6, x + side * gx, top + gx, GUNMETAL))
    out.append('<path d="M %.1f %.1f L %.1f %.1f" stroke="#ffffff" stroke-width="6" opacity="0.4"/>' % (x - gx * 0.55, y - 30, x - gx * 0.55, top + gx))
    out = piece.layer("cap")
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" stroke="%s" stroke-width="4"/>' % (x, top + gx * 0.35, gx * 0.95, gx * 0.4, GUNMETAL, METAL_LINE))
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="none" stroke="%s" stroke-width="4"/>' % (x, top + gx * 0.35, gx * 0.6, gx * 0.22, CYAN))
    out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="3" stroke-opacity="0.7"/>' % (x + gx - 2, y - 10, x + gx - 2, top + gx, RIM))
    piece.write()


# --- the room ---------------------------------------------------------------
WALL_HEIGHT = 288  # 72 px in the game


def floor_tile(name, color):
    """One floor tile: dark concrete slabs with a seam, scuffs and the odd neon reflection."""
    piece = Piece(name, 1, 1, 0, "room")
    out = piece.layer("concrete")
    out.append('<polygon points="%s" fill="%s"/>' % (piece.pts([(0, 0), (1, 0), (1, 1), (0, 1)]),
                                                     piece.gradient(shade(color, 0.08), shade(color, -0.1))))
    out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="3" opacity="0.5"/>' % (piece.pts([(0, 0.5), (1, 0.5)]), shade(color, -0.4)))
    out.append('<polygon points="%s" fill="none" stroke="%s" stroke-width="2" opacity="0.5"/>' % (piece.pts([(0, 0), (1, 0), (1, 1), (0, 1)]), shade(color, -0.5)))
    cx, cy = piece.p(0.3, 0.7)
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="38" ry="12" fill="#000000" opacity="0.18"/>' % (cx, cy))
    if name == "floor_b":
        rx_, ry_ = piece.p(0.7, 0.25)
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="46" ry="14" fill="%s" opacity="0.12"/>' % (rx_, ry_, MAGENTA))
    else:
        rx_, ry_ = piece.p(0.65, 0.3)
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="40" ry="12" fill="%s" opacity="0.1"/>' % (rx_, ry_, CYAN))
    piece.write()


def wall(name, kind):
    """One tile-wide segment of the back-left wall (the plane x = 0, seen from inside).
    The back-right wall is the same drawing mirrored."""
    piece = Piece(name, 1, 1, WALL_HEIGHT, "room")
    h = WALL_HEIGHT
    out = piece.layer("wall")
    out.append('<polygon points="%s" fill="%s"/>' % (piece.pts([(0, 0, h), (0, 1, h), (0, 1, 0), (0, 0, 0)]), piece.gradient("#2a2236", "#14111f")))
    for z in (60, 120, 180, 240):
        out.append('<polyline points="%s" fill="none" stroke="#0e0b17" stroke-width="3" opacity="0.6"/>' % piece.pts([(0, 0, z), (0, 1, z)]))
    for i, z in enumerate((30, 90, 150, 210)):
        t = 0.25 if i % 2 == 0 else 0.75
        out.append('<polyline points="%s" fill="none" stroke="#0e0b17" stroke-width="3" opacity="0.6"/>' % piece.pts([(0, t, z - 30), (0, t, z + 30)]))
    out = piece.layer("base")
    out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="3"/>' % (piece.pts([(0, 0, 40), (0, 1, 40), (0, 1, 0), (0, 0, 0)]),
                                                                                piece.gradient(STEEL, GUNMETAL), METAL_LINE))
    neon(piece, out, [(0, 0, 40), (0, 1, 40)], MAGENTA, 4)
    if kind == "window":
        out = piece.layer("window")
        frame = [(0, 0.16, 236), (0, 0.84, 236), (0, 0.84, 110), (0, 0.16, 110)]
        out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="7" stroke-linejoin="round"/>' % (piece.pts(frame), piece.gradient("#0a1030", "#3a1450"), GUNMETAL))
        for i, (y0, top, color) in enumerate(((0.22, 200, "#1a2050"), (0.36, 176, "#14183e"), (0.52, 214, "#1a2050"), (0.68, 168, "#14183e"))):
            out.append('<polygon points="%s" fill="%s"/>' % (piece.pts([(0, y0, top), (0, y0 + 0.12, top), (0, y0 + 0.12, 114), (0, y0, 114)]), color))
            for j in range(2):
                lx, ly = piece.p(0, y0 + 0.04 + j * 0.05, top - 16)
                out.append('<rect x="%.1f" y="%.1f" width="6" height="8" fill="%s"/>' % (lx, ly, [MAGENTA, CYAN][(i + j) % 2]))
        for k in range(7):
            ax, ay = piece.p(0, 0.2 + k * 0.09, 228)
            out.append('<path d="M %.1f %.1f l -6 18" stroke="#9fd8ff" stroke-width="2" opacity="0.5"/>' % (ax, ay))
        out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="4"/>' % (piece.pts([(0, 0.5, 236), (0, 0.5, 110)]), GUNMETAL))
    elif kind == "shelf":
        out = piece.layer("back_bar")
        for z in (130, 190):
            out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round"/>'
                       % (piece.pts([(0, 0.12, z), (0, 0.88, z), (0.12, 0.88, z), (0.12, 0.12, z)]), GUNMETAL, METAL_LINE))
            neon(piece, out, [(0.12, 0.12, z - 2), (0.12, 0.88, z - 2)], CYAN, 2)
            for i, color in enumerate((AMBER, ACID, MAGENTA, AMBER, CYAN)):
                bx, by = piece.p(0.06, 0.2 + i * 0.15, z)
                out.append('<path d="M %.1f %.1f l 0 -22 l 3 -4 l 0 -8 l 6 0 l 0 8 l 3 4 l 0 22 z" fill="%s" stroke="%s" stroke-width="2" opacity="0.92"/>'
                           % (bx - 6, by, color, shade(color, -0.5)))
                out.append('<circle cx="%.1f" cy="%.1f" r="12" fill="%s"/>' % (bx, by - 12, piece.glow(color)))
    elif kind == "plain":
        out = piece.layer("graffiti")
        gx, gy = piece.p(0, 0.3, 150)
        out.append('<path d="M %.1f %.1f c 14 -26 30 8 44 -16 c 6 14 22 4 30 -6" fill="none" stroke="%s" stroke-width="7" opacity="0.7"/>' % (gx, gy, ACID))
        px, py = piece.p(0, 0.75, 210)
        out.append('<path d="M %.1f %.1f l 0 -60" stroke="%s" stroke-width="10"/>' % (px, py, GUNMETAL))
        out.append('<path d="M %.1f %.1f l 0 -60" stroke="#ffffff" stroke-width="2" opacity="0.3"/>' % (px - 3, py))
    out = piece.layer("top")
    out.append('<polygon points="%s" fill="#0a0812"/>' % piece.pts([(0, 0, h), (0, 1, h), (0, 1, h - 12), (0, 0, h - 12)]))
    neon(piece, out, [(0, 0, h - 18), (0, 1, h - 18)], CYAN, 3)
    piece.write()


def door():
    """The bar door: a steel frame with a half-open shutter, a glass door and a neon cocktail glass."""
    piece = Piece("door", 1, 1, WALL_HEIGHT + 60, "room")
    out = piece.layer("frame")
    for y in (0.04, 0.96):
        out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="4" stroke-linejoin="round"/>'
                   % (piece.pts([(0, y - 0.04, 270), (0, y + 0.04, 270), (0, y + 0.04, 0), (0, y - 0.04, 0)]), piece.gradient(STEEL, GUNMETAL), METAL_LINE))
    out = piece.layer("glass")
    out.append('<polygon points="%s" fill="%s" opacity="0.3" stroke="%s" stroke-width="3"/>'
               % (piece.pts([(0, 0.1, 200), (0, 0.9, 200), (0, 0.9, 6), (0, 0.1, 6)]), piece.gradient("#bff8ff", "#1a6fd6", vertical=False), CHROME))
    out.append('<polyline points="%s" fill="none" stroke="#ffffff" stroke-width="5" opacity="0.4"/>' % piece.pts([(0, 0.22, 180), (0, 0.4, 100)]))
    out = piece.layer("shutter")
    out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="4"/>'
               % (piece.pts([(0, 0.06, 270), (0, 0.94, 270), (0, 0.94, 200), (0, 0.06, 200)]), piece.gradient(STEEL, GUNMETAL), METAL_LINE))
    for z in (212, 226, 240, 254):
        out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="3"/>' % (piece.pts([(0, 0.08, z), (0, 0.92, z)]), METAL_LINE))
    for k in range(5):
        ax, ay = piece.p(0, 0.12 + k * 0.18, 206)
        out.append('<path d="M %.1f %.1f l 10 -6 l 0 10 z" fill="%s" opacity="0.9"/>' % (ax, ay, AMBER if k % 2 == 0 else INK))
    out = piece.layer("sign")
    neon(piece, out, [(0, 0.3, 330), (0, 0.7, 330), (0, 0.5, 300), (0, 0.3, 330)], MAGENTA, 5)
    neon(piece, out, [(0, 0.5, 300), (0, 0.5, 282)], MAGENTA, 5)
    neon(piece, out, [(0, 0.4, 280), (0, 0.6, 280)], MAGENTA, 5)
    neon(piece, out, [(0, 0.62, 334), (0, 0.66, 344)], CYAN, 3)
    piece.write()


if __name__ == "__main__":
    seat("seat", "")
    seat("seat_far", "far")
    seat("seat_near", "near")
    table()
    stove()
    counter()
    bin_piece()
    register()
    potted_fern()
    bubble_lamp()
    glass_pod_plant()
    beanbag()
    led_sign()
    holo_menu()
    vending_shrine()
    koi_tank()
    neon_mural()
    zen_garden()
    pod()
    floor_tile("floor_a", "#2b2836")
    floor_tile("floor_b", "#26232f")
    wall("wall_plain", "plain")
    wall("wall_window", "window")
    wall("wall_shelf", "shelf")
    door()
    print("furniture and décor written to", os.path.normpath(ROOT))
