"""Draws the café furniture and décor as layered SVGs in the art guide's style.

Run:  python tools/art/furniture_svg.py
Writes art/furniture/<id>.svg, art/decor/<id>.svg, art/furniture/pod.svg and the
room: art/room/floor_a.svg, floor_b.svg, wall_plain.svg, wall_window.svg,
wall_shelf.svg and door.svg.

Style (docs/art-guide.md): round soft shapes, outlines in a darker shade of each
material (no black), one gradient per material lit from the top-left, a flat
cel shadow, and a thin cyan rim light on the right edges.

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
RIM = "#38e1ff"
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


# --- the pieces -----------------------------------------------------------
WOOD = "#b9784a"
WOOD_DARK = "#6b4130"
STEEL = "#a3abc2"
CREAM = "#f1e4cc"
TEAL = "#3fa58f"
CUSHION = "#e98a4f"


def seat(name, back):
    """A round cushioned stool with a footrest ring; back = "" (none), "far" (upper-left edge) or "near" (lower-right edge)."""
    piece = Piece(name, 1, 1, 170, "furniture")
    out = piece.layer("shadow")
    piece.floor_shadow(out, 0.14, 0.14, 0.72, 0.72)
    if back == "far":
        backrest(piece, 0.12)
    out = piece.layer("stool")
    piece.disc(out, 0.5, 0.5, 2, 0.26, shade(STEEL, -0.25))
    piece.cylinder(out, 0.5, 0.5, 0.06, 0, 36, STEEL, rim=False)
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 16, 0.2)
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="none" stroke="%s" stroke-width="6"/>' % (x, y, rx, ry, shade(STEEL, -0.35)))
    piece.cylinder(out, 0.5, 0.5, 0.37, 34, 26, CUSHION, top=shade(CUSHION, 0.12))
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 60, 0.37)
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="none" stroke="%s" stroke-width="3" stroke-dasharray="10 8" opacity="0.7"/>'
               % (x, y, rx * 0.78, ry * 0.78, shade(CUSHION, -0.35)))
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#ffffff" opacity="0.2"/>' % (x - rx * 0.3, y - ry * 0.25, rx * 0.4, ry * 0.35))
    if back == "near":
        backrest(piece, 0.76)
    piece.write()


def backrest(piece, x0):
    """A wooden backrest with a cushion pad, along the edge at x0 (tiles)."""
    out = piece.layer("backrest")
    piece.box(out, x0, 0.18, 0.12, 0.64, 40, 112, WOOD_DARK)
    pad_x = x0 + 0.12 if x0 < 0.5 else x0 - 0.02
    out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round"/>'
               % (piece.pts([(pad_x, 0.26, 140), (pad_x, 0.74, 140), (pad_x, 0.74, 80), (pad_x, 0.26, 80)]),
                  piece.gradient(shade(CUSHION, 0.1), shade(CUSHION, -0.15)), shade(CUSHION, -0.5)))


def table():
    piece = Piece("table", 1, 1, 170, "furniture")
    piece.floor_shadow(piece.layer("shadow"), 0.06, 0.06, 0.88, 0.88)
    out = piece.layer("table")
    piece.disc(out, 0.5, 0.5, 2, 0.24, shade(WOOD_DARK, -0.2))
    piece.cylinder(out, 0.5, 0.5, 0.07, 4, 94, WOOD_DARK, rim=False)
    piece.cylinder(out, 0.5, 0.5, 0.46, 98, 12, WOOD, top=shade(WOOD, 0.25))
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 110, 0.46)
    for ring in (0.72, 0.45):
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="none" stroke="%s" stroke-width="3" opacity="0.4"/>'
                   % (x, y, rx * ring, ry * ring, shade(WOOD, -0.25)))
    out = piece.layer("vase")
    piece.cylinder(out, 0.22, 0.3, 0.05, 110, 26, CREAM, top="#4a8a5a", rim=False)
    vx, vy = piece.p(0.22, 0.3, 136)
    out.append('<path d="M %.1f %.1f q -4 -18 -12 -26 M %.1f %.1f q 4 -20 12 -24" fill="none" stroke="#3f9a52" stroke-width="4" stroke-linecap="round"/>'
               % (vx, vy, vx, vy))
    for dx, dy, color in ((-12, -28, "#ff6f91"), (12, -26, "#ffd36b"), (0, -36, "#ff6f91")):
        out.append('<circle cx="%.1f" cy="%.1f" r="8" fill="%s" stroke="%s" stroke-width="2"/>' % (vx + dx, vy + dy, color, shade(color, -0.45)))
    piece.write()


def stove():
    piece = Piece("stove", 1, 1, 230, "furniture")
    piece.floor_shadow(piece.layer("shadow"), 0.03, 0.03, 0.94, 0.94)
    out = piece.layer("body")
    piece.box(out, 0.03, 0.03, 0.94, 0.94, 0, 128, STEEL, top="#454b63")
    out = piece.layer("oven")
    out.append('<polygon points="%s" fill="#2a2e3f" stroke="#1c1f2c" stroke-width="3" stroke-linejoin="round"/>'
               % piece.pts([(0.97, 0.18, 96), (0.97, 0.82, 96), (0.97, 0.82, 14), (0.97, 0.18, 14)]))
    out.append('<polygon points="%s" fill="%s" opacity="0.9"/>'
               % (piece.pts([(0.97, 0.26, 80), (0.97, 0.74, 80), (0.97, 0.74, 30), (0.97, 0.26, 30)]), piece.gradient("#ffb35c", "#c4452a")))
    out.append('<polyline points="%s" fill="none" stroke="#d9dde8" stroke-width="6" stroke-linecap="round"/>'
               % piece.pts([(0.97, 0.28, 108), (0.97, 0.72, 108)]))
    out = piece.layer("knobs")
    for i in range(4):
        kx, ky = piece.p(0.16 + i * 0.22, 0.97, 104)
        out.append('<circle cx="%.1f" cy="%.1f" r="9" fill="#2a2e3f" stroke="#1c1f2c" stroke-width="3"/>' % (kx, ky))
        out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#ff8a3d" stroke-width="3"/>' % (kx, ky, kx, ky - 7))
    out.append('<polygon points="%s" fill="#38e1ff" opacity="0.85" stroke="#1d6f86" stroke-width="3"/>'
               % piece.pts([(0.3, 0.97, 78), (0.7, 0.97, 78), (0.7, 0.97, 58), (0.3, 0.97, 58)]))
    out = piece.layer("burners")
    for cx, cy in ((0.3, 0.3), (0.7, 0.3), (0.3, 0.7), (0.7, 0.7)):
        piece.disc(out, cx, cy, 128, 0.14, "#2a2e3f", outline="#1c1f2c")
        x, y, rx, ry = piece.ellipse_xy(cx, cy, 128, 0.1)
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="none" stroke="#ff8a3d" stroke-width="4" opacity="0.85"/>' % (x, y, rx, ry))
    out = piece.layer("pot")
    piece.cylinder(out, 0.3, 0.3, 0.16, 128, 40, "#c94f3d", top="#7a2a22")
    hx, hy, rx, ry = piece.ellipse_xy(0.3, 0.3, 160, 0.16)
    out.append('<rect x="%.1f" y="%.1f" width="22" height="8" rx="4" fill="#2a2e3f"/>' % (hx + rx - 4, hy - 4))
    for i in range(3):
        sx, sy = piece.p(0.22 + i * 0.08, 0.3, 172)
        out.append('<path d="M %.1f %.1f q -8 -10 0 -20 q 8 -10 0 -20" fill="none" stroke="#ffffff" stroke-width="5" stroke-linecap="round" opacity="0.55"/>' % (sx, sy))
    piece.write()


def counter():
    piece = Piece("counter", 1, 1, 170, "furniture")
    piece.floor_shadow(piece.layer("shadow"), 0.02, 0.02, 0.96, 0.96)
    out = piece.layer("cabinet")
    piece.box(out, 0.04, 0.04, 0.92, 0.92, 0, 108, WOOD)
    for z0, z1 in ((60, 96), (12, 52)):
        out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round" opacity="0.9"/>'
                   % (piece.pts([(0.12, 0.96, z1), (0.88, 0.96, z1), (0.88, 0.96, z0), (0.12, 0.96, z0)]), shade(WOOD, 0.08), shade(WOOD, -0.4)))
        hx0, hy0 = piece.p(0.4, 0.96, (z0 + z1) / 2)
        hx1, hy1 = piece.p(0.6, 0.96, (z0 + z1) / 2)
        out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#e9c48f" stroke-width="6" stroke-linecap="round"/>' % (hx0, hy0, hx1, hy1))
    out.append('<polygon points="%s" fill="none" stroke="%s" stroke-width="3" opacity="0.6"/>'
               % (piece.pts([(0.96, 0.14, 96), (0.96, 0.86, 96), (0.96, 0.86, 14), (0.96, 0.14, 14)]), shade(WOOD, -0.5)))
    out = piece.layer("top")
    piece.box(out, 0.0, 0.0, 1.0, 1.0, 108, 12, CREAM, top=shade(CREAM, 0.3))
    out = piece.layer("led")
    out.append('<polyline points="%s" fill="none" stroke="#ff4fd8" stroke-width="5" stroke-opacity="0.85" stroke-linecap="round"/>'
               % piece.pts([(0.06, 0.96, 4), (0.94, 0.96, 4)]))
    piece.write()


def bin_piece():
    piece = Piece("bin", 1, 1, 170, "furniture")
    piece.floor_shadow(piece.layer("shadow"), 0.16, 0.16, 0.68, 0.68)
    out = piece.layer("bin")
    piece.cylinder(out, 0.5, 0.5, 0.32, 0, 100, TEAL, top="#2f6f61")
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 46, 0.32)
    out.append('<path d="M %.1f %.1f A %.1f %.1f 0 0 0 %.1f %.1f L %.1f %.1f A %.1f %.1f 0 0 1 %.1f %.1f Z" fill="#e8fff6" opacity="0.85"/>'
               % (x - rx, y, rx, ry, x + rx, y, x + rx, y - 26, rx, ry, x - rx, y - 26))
    out.append('<path d="M %.1f %.1f l 12 -18 l 12 18 z" fill="none" stroke="%s" stroke-width="4" stroke-linejoin="round"/>' % (x - 12, y + ry - 8, TEAL))
    piece.cylinder(out, 0.5, 0.5, 0.34, 100, 12, shade(TEAL, -0.2), top=shade(TEAL, 0.05))
    hx, hy = piece.p(0.5, 0.5, 130)
    out.append('<path d="M %.1f %.1f q 22 -22 44 0" fill="none" stroke="%s" stroke-width="7" stroke-linecap="round"/>' % (hx - 22, hy + 6, shade(TEAL, -0.45)))
    piece.write()


def register():
    piece = Piece("register", 1, 1, 200, "furniture")
    piece.floor_shadow(piece.layer("shadow"), 0.04, 0.04, 0.92, 0.92)
    out = piece.layer("stand")
    piece.box(out, 0.06, 0.06, 0.88, 0.88, 0, 92, "#4b5aa8")
    out.append('<polyline points="%s" fill="none" stroke="#ffd36b" stroke-width="4" opacity="0.8"/>' % piece.pts([(0.1, 0.94, 70), (0.9, 0.94, 70)]))
    piece.box(out, 0.02, 0.02, 0.96, 0.96, 92, 10, CREAM, top=shade(CREAM, 0.3))
    out = piece.layer("terminal")
    piece.box(out, 0.32, 0.28, 0.4, 0.34, 102, 24, "#2a2e3f")
    out.append('<polygon points="%s" fill="#2a2e3f" stroke="#1c1f2c" stroke-width="4" stroke-linejoin="round"/>'
               % piece.pts([(0.3, 0.48, 126), (0.74, 0.48, 126), (0.74, 0.6, 186), (0.3, 0.6, 186)]))
    out.append('<polygon points="%s" fill="%s" opacity="0.95"/>'
               % (piece.pts([(0.34, 0.5, 132), (0.7, 0.5, 132), (0.7, 0.58, 180), (0.34, 0.58, 180)]), piece.gradient("#7ff0ff", "#1aa6d1")))
    for i in range(3):
        a = piece.p(0.4, 0.54, 166 - i * 12)
        b = piece.p(0.64 - i * 0.06, 0.54, 166 - i * 12)
        out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#0d3b52" stroke-width="4" stroke-linecap="round"/>' % (a + b))
    out = piece.layer("card_reader")
    piece.box(out, 0.74, 0.62, 0.14, 0.2, 102, 30, "#3a3f5a")
    rx_, ry_ = piece.p(0.81, 0.72, 132)
    out.append('<circle cx="%.1f" cy="%.1f" r="5" fill="#9cff6b"/>' % (rx_, ry_))
    out = piece.layer("tip_jar")
    piece.cylinder(out, 0.2, 0.72, 0.08, 102, 40, "#bfefff", top="#e8fbff", rim=False, top_opacity=0.6)
    for dx, dz, color in ((-6, 112, "#ffd36b"), (6, 118, "#e9c48f"), (0, 126, "#ffd36b")):
        cx, cy = piece.p(0.2, 0.72, dz)
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="8" ry="4" fill="%s" stroke="#a87a2a" stroke-width="2"/>' % (cx + dx, cy, color))
    piece.write()


def potted_fern():
    piece = Piece("potted_fern", 1, 1, 270, "decor")
    piece.floor_shadow(piece.layer("shadow"), 0.2, 0.2, 0.6, 0.6)
    out = piece.layer("pot")
    piece.cylinder(out, 0.5, 0.5, 0.27, 0, 70, "#d9774a", top="#5a3b2a")
    piece.cylinder(out, 0.5, 0.5, 0.29, 56, 14, "#e88a5a", top="#5a3b2a")
    out = piece.layer("fronds")
    x, y = piece.p(0.5, 0.5, 68)
    fronds = ((-160, 100, "#3f9a52"), (-20, 95, "#3f9a52"), (-140, 130, "#56b866"), (-40, 125, "#56b866"),
              (-120, 150, "#3f9a52"), (-60, 150, "#3f9a52"), (-100, 170, "#6ccf73"), (-80, 165, "#56b866"),
              (-150, 80, "#6ccf73"), (-30, 80, "#6ccf73"), (-90, 185, "#7bdc82"))
    for angle, length, color in fronds:
        a = math.radians(angle)
        tx, ty = x + math.cos(a) * length, y + math.sin(a) * length
        cx, cy = x + math.cos(a + 0.3) * length * 0.6, y + math.sin(a + 0.3) * length * 0.6 - 12
        out.append('<path d="M %.1f %.1f Q %.1f %.1f %.1f %.1f Q %.1f %.1f %.1f %.1f Z" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round"/>'
                   % (x, y, cx - 16, cy, tx, ty, cx + 16, cy + 10, x, y, color, shade(color, -0.45)))
        out.append('<path d="M %.1f %.1f Q %.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="2" opacity="0.6"/>'
                   % (x, y, cx, cy + 4, tx, ty, shade(color, -0.35)))
    piece.write()


def bubble_lamp():
    piece = Piece("bubble_lamp", 1, 1, 280, "decor")
    out = piece.layer("glow")
    x, y = piece.p(0.5, 0.5, 200)
    out.append('<circle cx="%.1f" cy="%.1f" r="130" fill="%s"/>' % (x, y, piece.glow("#ffd36b")))
    piece.floor_shadow(piece.layer("shadow"), 0.28, 0.28, 0.44, 0.44)
    out = piece.layer("lamp")
    piece.cylinder(out, 0.5, 0.5, 0.22, 0, 16, "#3a3550", rim=False)
    piece.cylinder(out, 0.5, 0.5, 0.03, 16, 150, "#c9a46a", rim=False)
    for dx, dy, r in ((-44, 24, 30), (40, 18, 34), (0, 0, 46)):
        out.append('<path d="M %.1f %.1f L %.1f %.1f" stroke="#c9a46a" stroke-width="5" stroke-linecap="round"/>' % (x, y + 40, x + dx, y + dy))
        out.append('<circle cx="%.1f" cy="%.1f" r="%d" fill="%s" stroke="#c98a3a" stroke-width="4"/>' % (x + dx, y + dy - r * 0.3, r, piece.gradient("#fff6cf", "#ffc04d")))
        out.append('<circle cx="%.1f" cy="%.1f" r="%d" fill="#ffffff" opacity="0.7"/>' % (x + dx - r * 0.35, y + dy - r * 0.65, max(r // 4, 5)))
    out.append('<path d="M %.1f %.1f A 46 46 0 0 1 %.1f %.1f" fill="none" stroke="%s" stroke-width="3" stroke-opacity="0.7"/>' % (x + 32, y - 47, x + 33, y + 18, RIM))
    piece.write()


def glass_pod_plant():
    piece = Piece("glass_pod_plant", 1, 1, 250, "decor")
    piece.floor_shadow(piece.layer("shadow"), 0.18, 0.18, 0.64, 0.64)
    out = piece.layer("base")
    piece.cylinder(out, 0.5, 0.5, 0.32, 0, 34, "#4a4f6a", top="#2c3045")
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 34, 0.32)
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="none" stroke="#3dffd0" stroke-width="5" opacity="0.9"/>' % (x, y + 16, rx, ry))
    out = piece.layer("plant")
    for dx, h, color in ((-34, 80, "#3f9a52"), (-14, 120, "#4fbf6a"), (8, 145, "#6ad97e"), (30, 100, "#3f9a52")):
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="16" ry="%.1f" fill="%s" stroke="%s" stroke-width="3"/>' % (x + dx, y - h / 2 - 4, h / 2, color, shade(color, -0.45)))
    for dx, dz in ((-30, 18), (24, 14)):
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="10" ry="7" fill="#3dffd0" stroke="#1d8f78" stroke-width="2"/>' % (x + dx, y - dz))
    out = piece.layer("glass")
    gx = rx * 0.92
    top = y - 190
    out.append('<path d="M %.1f %.1f L %.1f %.1f A %.1f %.1f 0 0 1 %.1f %.1f L %.1f %.1f A %.1f %.1f 0 0 1 %.1f %.1f Z" fill="%s" '
               'stroke="#9feaff" stroke-width="4" opacity="0.5"/>' % (x - gx, y, x - gx, top + gx, gx, gx,
                                                                   x + gx, top + gx, x + gx, y, gx, ry * 0.92, x - gx, y,
                                                                   piece.gradient("#d6fbff", "#5fd4ff", vertical=False)))
    out.append('<path d="M %.1f %.1f Q %.1f %.1f %.1f %.1f" fill="none" stroke="#ffffff" stroke-width="6" opacity="0.6" stroke-linecap="round"/>'
               % (x - gx * 0.65, y - 30, x - gx * 0.75, top + 44, x - gx * 0.2, top + 16))
    piece.write()


def beanbag():
    piece = Piece("beanbag", 1, 1, 140, "decor")
    piece.floor_shadow(piece.layer("shadow"), 0.06, 0.06, 0.88, 0.88)
    out = piece.layer("bag")
    x, y = piece.p(0.5, 0.5, 0)
    color = "#ff6f91"
    out.append('<path d="M %.1f %.1f C %.1f %.1f %.1f %.1f %.1f %.1f C %.1f %.1f %.1f %.1f %.1f %.1f C %.1f %.1f %.1f %.1f %.1f %.1f Z" '
               'fill="%s" stroke="%s" stroke-width="4" stroke-linejoin="round"/>'
               % (x - 135, y + 10, x - 155, y - 80, x - 65, y - 135, x, y - 112,
                  x + 65, y - 140, x + 160, y - 80, x + 135, y + 10,
                  x + 90, y + 56, x - 90, y + 56, x - 135, y + 10,
                  piece.gradient("#ff9ab3", "#d94f73"), shade(color, -0.55)))
    for path in ("M %.1f %.1f Q %.1f %.1f %.1f %.1f" % (x - 80, y - 46, x, y - 12, x + 80, y - 46),
                 "M %.1f %.1f Q %.1f %.1f %.1f %.1f" % (x - 10, y - 108, x - 20, y - 60, x - 4, y - 24),
                 "M %.1f %.1f Q %.1f %.1f %.1f %.1f" % (x - 110, y - 40, x - 60, y - 20, x - 40, y + 30)):
        out.append('<path d="%s" fill="none" stroke="%s" stroke-width="4" stroke-dasharray="10 8" opacity="0.7" stroke-linecap="round"/>' % (path, shade(color, -0.4)))
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="38" ry="18" fill="#ffffff" opacity="0.3"/>' % (x - 56, y - 90))
    out.append('<path d="M %.1f %.1f C %.1f %.1f %.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="3" stroke-opacity="0.7"/>'
               % (x + 112, y - 70, x + 156, y - 46, x + 146, y, x + 124, y + 18, RIM))
    piece.write()


def led_sign():
    piece = Piece("led_sign", 2, 1, 230, "decor")
    piece.floor_shadow(piece.layer("shadow"), 0.2, 0.4, 1.6, 0.25)
    out = piece.layer("stand")
    for px in (0.4, 1.6):
        piece.cylinder(out, px, 0.55, 0.05, 0, 70, "#3a3550", rim=False)
    out = piece.layer("panel")
    piece.box(out, 0.15, 0.48, 1.7, 0.14, 70, 120, "#241c3d", top="#3a2f5e")
    out = piece.layer("neon")
    a = piece.p(0.3, 0.62, 160)
    b = piece.p(1.7, 0.62, 160)
    c = piece.p(1.7, 0.62, 86)
    d = piece.p(0.3, 0.62, 86)
    out.append('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="none" stroke="#ff4fd8" stroke-width="6" stroke-linejoin="round" opacity="0.95"/>'
               % (a + b + c + d))
    # A neon coffee cup with steam, and a heart (no text: SVG fonts don't travel).
    cup = [(0.55, 0.62, 145), (0.85, 0.62, 145), (0.8, 0.62, 100), (0.6, 0.62, 100)]
    out.append('<polygon points="%s" fill="none" stroke="#38e1ff" stroke-width="6" stroke-linejoin="round"/>' % piece.pts(cup))
    for i in range(2):
        sx, sy = piece.p(0.64 + i * 0.12, 0.62, 152)
        out.append('<path d="M %.1f %.1f q -6 -8 0 -16" fill="none" stroke="#38e1ff" stroke-width="5" stroke-linecap="round"/>' % (sx, sy))
    hx, hy = piece.p(1.3, 0.62, 118)
    out.append('<path d="M %.1f %.1f c -24 -18 -34 6 0 26 c 34 -20 24 -44 0 -26 z" fill="none" stroke="#ffd36b" stroke-width="6" '
               'stroke-linejoin="round" transform="rotate(26.6 %.1f %.1f)"/>' % (hx, hy, hx, hy))
    piece.write()


def holo_menu():
    piece = Piece("holo_menu", 1, 1, 260, "decor")
    piece.floor_shadow(piece.layer("shadow"), 0.3, 0.3, 0.4, 0.4)
    out = piece.layer("pedestal")
    piece.cylinder(out, 0.5, 0.5, 0.18, 0, 50, "#3a3f5a", top="#2c3045")
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 50, 0.12)
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#38e1ff" opacity="0.9"/>' % (x, y, rx, ry))
    out = piece.layer("hologram")
    out.append('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="#38e1ff" opacity="0.18"/>' % (x - rx, y, x + rx, y, x + 70, y - 90, x - 70, y - 90))
    panel = [piece.p(0.2, 0.5, 220), piece.p(0.8, 0.5, 220), piece.p(0.8, 0.5, 100), piece.p(0.2, 0.5, 100)]
    out.append('<polygon points="%s" fill="%s" stroke="#9feaff" stroke-width="4" stroke-linejoin="round" opacity="0.75"/>'
               % (" ".join("%.1f,%.1f" % q for q in panel), piece.gradient("#7ff0ff", "#1a7fd1")))
    for i in range(4):
        a = piece.p(0.28, 0.5, 200 - i * 26)
        b = piece.p(0.62 - (i % 2) * 0.12, 0.5, 200 - i * 26)
        out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#e8fdff" stroke-width="6" stroke-linecap="round" opacity="0.85"/>' % (a + b))
    piece.write()


def vending_shrine():
    piece = Piece("vending_shrine", 1, 2, 330, "decor")
    piece.floor_shadow(piece.layer("shadow"), 0.04, 0.04, 0.92, 1.92)
    out = piece.layer("machine")
    piece.box(out, 0.08, 0.1, 0.84, 1.8, 0, 250, "#e8e2f0", top="#ffffff")
    out = piece.layer("window")
    out.append('<polygon points="%s" fill="%s" stroke="#5a6a9a" stroke-width="4" stroke-linejoin="round"/>'
               % (piece.pts([(0.92, 0.25, 230), (0.92, 1.45, 230), (0.92, 1.45, 90), (0.92, 0.25, 90)]), piece.gradient("#2c3a6a", "#1a2244")))
    colors = ["#ff4fd8", "#38e1ff", "#ffd36b", "#9cff6b", "#ff8a3d"]
    for row in range(3):
        for col in range(5):
            cx, cy = piece.p(0.92, 0.38 + col * 0.23, 205 - row * 44)
            out.append('<rect x="%.1f" y="%.1f" width="16" height="26" rx="5" fill="%s" stroke="%s" stroke-width="2"/>'
                       % (cx - 8, cy - 13, colors[(row + col) % 5], shade(colors[(row + col) % 5], -0.5)))
    out.append('<polygon points="%s" fill="#2a2e3f"/>' % piece.pts([(0.92, 0.5, 60), (0.92, 1.2, 60), (0.92, 1.2, 30), (0.92, 0.5, 30)]))
    out = piece.layer("roof")
    piece.box(out, 0.0, 0.0, 1.0, 2.0, 250, 16, "#d6453d", top="#ff6b5f")
    for py in (0.2, 1.8):
        piece.box(out, 0.85, py - 0.05, 0.1, 0.1, 266, 34, "#d6453d")
    piece.box(out, 0.83, 0.05, 0.14, 1.9, 300, 12, "#d6453d", top="#ff6b5f")
    piece.write()


def koi_tank():
    piece = Piece("koi_tank", 2, 2, 170, "decor")
    piece.floor_shadow(piece.layer("shadow"), 0.04, 0.04, 1.92, 1.92)
    out = piece.layer("stone_rim")
    piece.box(out, 0.06, 0.06, 1.88, 1.88, 0, 70, "#8d8aa3", top="#b3b0c8")
    out = piece.layer("water")
    out.append('<polygon points="%s" fill="%s" opacity="0.92"/>' % (piece.pts([(0.2, 0.2, 70), (1.8, 0.2, 70), (1.8, 1.8, 70), (0.2, 1.8, 70)]),
                                                                     piece.gradient("#5fd4ff", "#1f6fb3")))
    for fx, fy, angle, color in ((0.7, 0.8, -20, "#ff8a3d"), (1.3, 1.1, 160, "#ffffff"), (0.9, 1.4, 40, "#ff8a3d")):
        x, y = piece.p(fx, fy, 70)
        out.append('<g transform="rotate(%d %.1f %.1f)"><ellipse cx="%.1f" cy="%.1f" rx="30" ry="12" fill="%s" stroke="#c4552a" stroke-width="3"/>'
                   '<path d="M %.1f %.1f l 20 -12 l 0 24 z" fill="%s" stroke="#c4552a" stroke-width="3" stroke-linejoin="round"/></g>'
                   % (angle, x, y, x, y, color, x + 28, y, color))
    for px, py in ((0.5, 1.5), (1.5, 0.5)):
        x, y, rx, ry = piece.ellipse_xy(px, py, 70, 0.16)
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#6ccf73" stroke="#3f9a52" stroke-width="3"/>' % (x, y, rx, ry))
    x, y = piece.p(1.0, 1.0, 70)
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="60" ry="14" fill="#ffffff" opacity="0.25"/>' % (x - 80, y - 40))
    piece.write()


def neon_mural():
    piece = Piece("neon_mural", 2, 1, 290, "decor")
    piece.floor_shadow(piece.layer("shadow"), 0.1, 0.4, 1.8, 0.3)
    out = piece.layer("wall")
    piece.box(out, 0.1, 0.45, 1.8, 0.16, 0, 250, "#2b2246", top="#43386a")
    out = piece.layer("neon")
    cup = [(0.55, 0.61, 200), (0.95, 0.61, 200), (0.9, 0.61, 110), (0.6, 0.61, 110)]
    out.append('<polygon points="%s" fill="none" stroke="#38e1ff" stroke-width="7" stroke-linejoin="round"/>' % piece.pts(cup))
    hx, hy = piece.p(0.97, 0.61, 175)
    out.append('<path d="M %.1f %.1f q 26 6 18 34" fill="none" stroke="#38e1ff" stroke-width="7" stroke-linecap="round"/>' % (hx, hy))
    for i in range(3):
        a = piece.p(0.62 + i * 0.1, 0.61, 215)
        out.append('<path d="M %.1f %.1f q -10 -14 0 -28 q 10 -14 0 -28" fill="none" stroke="#ff4fd8" stroke-width="6" stroke-linecap="round"/>' % a)
    for i in range(3):
        a = piece.p(1.15, 0.61, 200 - i * 34)
        b = piece.p(1.75, 0.61, 200 - i * 34)
        out.append('<path d="M %.1f %.1f Q %.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="6" stroke-linecap="round"/>'
                   % (a[0], a[1], (a[0] + b[0]) / 2, (a[1] + b[1]) / 2 - 22, b[0], b[1], ["#ff4fd8", "#ffd36b", "#9cff6b"][i]))
    piece.write()


def zen_garden():
    piece = Piece("zen_garden", 2, 2, 190, "decor")
    piece.floor_shadow(piece.layer("shadow"), 0.02, 0.02, 1.96, 1.96)
    out = piece.layer("frame")
    piece.box(out, 0.04, 0.04, 1.92, 1.92, 0, 26, WOOD)
    out = piece.layer("sand")
    out.append('<polygon points="%s" fill="%s"/>' % (piece.pts([(0.14, 0.14, 26), (1.86, 0.14, 26), (1.86, 1.86, 26), (0.14, 1.86, 26)]),
                                                     piece.gradient("#fbf1dc", "#e6d3ad")))
    for i in range(1, 6):
        t = i / 6.0
        out.append('<polyline points="%s" fill="none" stroke="#cdb789" stroke-width="3" opacity="0.8"/>'
                   % piece.pts([(0.2, 0.14 + t * 1.72, 26), (1.8, 0.14 + t * 1.72, 26)]))
    out = piece.layer("stones")
    for sx, sy, r in ((0.6, 0.7, 0.16), (1.3, 1.2, 0.2), (1.45, 0.55, 0.1)):
        x, y, rx, ry = piece.ellipse_xy(sx, sy, 26, r)
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" stroke="#4a4760" stroke-width="4"/>'
                   % (x, y - ry, rx, ry * 1.5, piece.gradient("#a7a4bd", "#6c6984")))
    out = piece.layer("bonsai")
    x, y = piece.p(0.55, 1.45, 26)
    out.append('<path d="M %.1f %.1f q 6 -40 -10 -70" fill="none" stroke="#6b4130" stroke-width="10" stroke-linecap="round"/>' % (x, y))
    for dx, dy in ((-30, -80), (10, -95), (-4, -60)):
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="30" ry="18" fill="#56b866" stroke="#2f7a40" stroke-width="3"/>' % (x + dx, y + dy))
    piece.write()


def pod():
    """A Sync Pod for the Pod bay: drawn standing, its base centre at the bottom middle (see PieceArt.POD_ANCHOR)."""
    piece = Piece("pod", 1, 1, 330, "furniture")
    out = piece.layer("base")
    piece.floor_shadow(out, 0.18, 0.18, 0.64, 0.64)
    piece.cylinder(out, 0.5, 0.5, 0.3, 0, 26, "#4a5888", top="#3a4a7a")
    x, y, rx, ry = piece.ellipse_xy(0.5, 0.5, 26, 0.3)
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#38e1ff" opacity="0.5"/>' % (x, y, rx * 0.7, ry * 0.7))
    out = piece.layer("glass")
    gx, top = rx * 0.82, y - 250
    out.append('<path d="M %.1f %.1f L %.1f %.1f A %.1f %.1f 0 0 1 %.1f %.1f L %.1f %.1f A %.1f %.1f 0 0 1 %.1f %.1f Z" fill="%s" '
               'stroke="#9feaff" stroke-width="4" opacity="0.5"/>' % (x - gx, y, x - gx, top + gx, gx, gx, x + gx, top + gx, x + gx, y, gx, ry * 0.82, x - gx, y,
                                                                    piece.gradient("#d6fbff", "#38a8ff", vertical=False)))
    out.append('<path d="M %.1f %.1f L %.1f %.1f" stroke="#ffffff" stroke-width="7" opacity="0.5" stroke-linecap="round"/>' % (x - gx * 0.6, y - 30, x - gx * 0.6, top + gx))
    out = piece.layer("cap")
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#5a6a9a" stroke="#2c3560" stroke-width="4"/>' % (x, top + gx * 0.35, gx * 0.85, gx * 0.35))
    out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="3" stroke-opacity="0.7"/>' % (x + gx - 2, y - 10, x + gx - 2, top + gx, RIM))
    piece.write()



# --- the room ---------------------------------------------------------------
WALL_HEIGHT = 288  # 72 px in the game
PLUM = "#3d2c5c"


def floor_tile(name, color):
    """One floor tile: warm wood planks running down-right."""
    piece = Piece(name, 1, 1, 0, "room")
    out = piece.layer("planks")
    out.append('<polygon points="%s" fill="%s"/>' % (piece.pts([(0, 0), (1, 0), (1, 1), (0, 1)]),
                                                     piece.gradient(shade(color, 0.06), shade(color, -0.06))))
    for i in range(1, 4):
        t = i / 4.0
        out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="3" opacity="0.55"/>'
                   % (piece.pts([(0, t), (1, t)]), shade(color, -0.3)))
    for i, (t, a, b) in enumerate(((0.125, 0.2, 0.2), (0.375, 0.65, 0.65), (0.625, 0.35, 0.35), (0.875, 0.8, 0.8))):
        out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="3" opacity="0.4"/>'
                   % (piece.pts([(a, t - 0.125), (b, t + 0.125)]), shade(color, -0.3)))
    out.append('<polygon points="%s" fill="none" stroke="%s" stroke-width="2" opacity="0.35"/>'
               % (piece.pts([(0, 0), (1, 0), (1, 1), (0, 1)]), shade(color, -0.45)))
    piece.write()


def wall(name, kind):
    """One tile-wide segment of the back-left wall (the plane x = 0, seen from inside).
    The back-right wall is the same drawing mirrored."""
    piece = Piece(name, 1, 1, WALL_HEIGHT, "room")
    h = WALL_HEIGHT
    out = piece.layer("wall")
    out.append('<polygon points="%s" fill="%s"/>' % (piece.pts([(0, 0, h), (0, 1, h), (0, 1, 0), (0, 0, 0)]),
                                                     piece.gradient(shade(PLUM, 0.08), shade(PLUM, -0.2))))
    out = piece.layer("wainscot")
    out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round"/>'
               % (piece.pts([(0, 0, 92), (0, 1, 92), (0, 1, 0), (0, 0, 0)]), piece.gradient("#a06a46", "#7a4e33"), "#4e3122"))
    for t in (0.25, 0.5, 0.75):
        out.append('<polyline points="%s" fill="none" stroke="#5e3b28" stroke-width="3" opacity="0.6"/>' % piece.pts([(0, t, 8), (0, t, 84)]))
    out.append('<polyline points="%s" fill="none" stroke="#e9c48f" stroke-width="7" stroke-linecap="round"/>' % piece.pts([(0, 0, 94), (0, 1, 94)]))
    if kind == "window":
        out = piece.layer("window")
        frame = [(0, 0.16, 236), (0, 0.84, 236), (0, 0.84, 124), (0, 0.16, 124)]
        out.append('<polygon points="%s" fill="%s" stroke="#e9c48f" stroke-width="8" stroke-linejoin="round"/>'
                   % (piece.pts(frame), piece.gradient("#1b2350", "#3a2a6a")))
        for i, (y0, top, color) in enumerate(((0.22, 200, "#2c3a78"), (0.36, 180, "#25306a"), (0.52, 214, "#2c3a78"), (0.68, 170, "#25306a"))):
            out.append('<polygon points="%s" fill="%s"/>' % (piece.pts([(0, y0, top), (0, y0 + 0.12, top), (0, y0 + 0.12, 128), (0, y0, 128)]), color))
            for j in range(2):
                lx, ly = piece.p(0, y0 + 0.04 + j * 0.05, top - 16)
                out.append('<rect x="%.1f" y="%.1f" width="6" height="8" fill="%s"/>' % (lx, ly, ["#ffd36b", "#38e1ff"][(i + j) % 2]))
        sx, sy = piece.p(0, 0.6, 222)
        out.append('<circle cx="%.1f" cy="%.1f" r="24" fill="%s"/>' % (sx, sy, piece.glow("#ff4fd8")))
        out.append('<polyline points="%s" fill="none" stroke="#e9c48f" stroke-width="5"/>' % piece.pts([(0, 0.5, 236), (0, 0.5, 124)]))
    elif kind == "shelf":
        out = piece.layer("shelf")
        out.append('<polygon points="%s" fill="#c98b55" stroke="#6b4130" stroke-width="3" stroke-linejoin="round"/>'
                   % piece.pts([(0, 0.18, 168), (0, 0.82, 168), (0.12, 0.82, 168), (0.12, 0.18, 168)]))
        out.append('<polygon points="%s" fill="#8a5a3c"/>' % piece.pts([(0.12, 0.18, 168), (0.12, 0.82, 168), (0.12, 0.82, 160), (0.12, 0.18, 160)]))
        for i, color in enumerate(("#f1e4cc", "#38e1ff", "#f1e4cc", "#ff8a3d")):
            cx, cy = piece.p(0.06, 0.26 + i * 0.15, 168)
            out.append('<path d="M %.1f %.1f l 4 -24 h 20 l 4 24 z" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round"/>'
                       % (cx - 14, cy, color, shade(color, -0.5)))
        lx, ly = piece.p(0, 0.5, 220)
        out.append('<circle cx="%.1f" cy="%.1f" r="20" fill="%s"/>' % (lx, ly, piece.glow("#ffd36b")))
        out.append('<circle cx="%.1f" cy="%.1f" r="8" fill="#fff1b8" stroke="#c98a3a" stroke-width="3"/>' % (lx, ly))
    out = piece.layer("neon_trim")
    out.append('<polyline points="%s" fill="none" stroke="#38e1ff" stroke-width="5" stroke-linecap="round" opacity="0.85"/>'
               % piece.pts([(0, 0, 262), (0, 1, 262)]))
    out.append('<polygon points="%s" fill="#2a1f42"/>' % piece.pts([(0, 0, h), (0, 1, h), (0, 1, h - 10), (0, 0, h - 10)]))
    piece.write()


def door():
    """The café door: a glass door with a striped awning, in the plane x = 0 of its
    tile (the game puts it on the front-right edge, by the last row)."""
    piece = Piece("door", 1, 1, WALL_HEIGHT + 40, "room")
    out = piece.layer("frame")
    for y in (0.04, 0.96):
        out.append('<polygon points="%s" fill="%s" stroke="#4e3122" stroke-width="4" stroke-linejoin="round"/>'
                   % (piece.pts([(0, y - 0.04, 270), (0, y + 0.04, 270), (0, y + 0.04, 0), (0, y - 0.04, 0)]), piece.gradient("#b07a50", "#7a4e33")))
    out.append('<polygon points="%s" fill="%s" stroke="#4e3122" stroke-width="4" stroke-linejoin="round"/>'
               % (piece.pts([(0, 0, 286), (0, 1, 286), (0, 1, 262), (0, 0, 262)]), piece.gradient("#b07a50", "#7a4e33")))
    out = piece.layer("glass")
    out.append('<polygon points="%s" fill="%s" opacity="0.35" stroke="#9feaff" stroke-width="3"/>'
               % (piece.pts([(0, 0.1, 258), (0, 0.9, 258), (0, 0.9, 6), (0, 0.1, 6)]), piece.gradient("#d6fbff", "#38a8ff", vertical=False)))
    out.append('<polyline points="%s" fill="none" stroke="#ffffff" stroke-width="6" opacity="0.5" stroke-linecap="round"/>'
               % piece.pts([(0, 0.22, 230), (0, 0.4, 140)]))
    hx, hy = piece.p(0, 0.78, 120)
    out.append('<rect x="%.1f" y="%.1f" width="8" height="36" rx="4" fill="#e9c48f" stroke="#7a4e33" stroke-width="2"/>' % (hx - 4, hy - 18))
    out = piece.layer("awning")
    for i in range(4):
        y0, y1 = i * 0.25, (i + 1) * 0.25
        color = "#3fa58f" if i % 2 == 0 else "#f1e4cc"
        out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round"/>'
                   % (piece.pts([(0, y0, 300), (0, y1, 300), (0.22, y1, 262), (0.22, y0, 262)]), color, shade(color, -0.45)))
    out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="3" stroke-opacity="0.7"/>' % (piece.pts([(0.22, 0, 262), (0.22, 1, 262)]), RIM))
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
    floor_tile("floor_a", "#a8724a")
    floor_tile("floor_b", "#9a6844")
    wall("wall_plain", "")
    wall("wall_window", "window")
    wall("wall_shelf", "shelf")
    door()
    print("furniture and décor written to", os.path.normpath(ROOT))
