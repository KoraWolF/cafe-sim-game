"""Draws every customer type, Synth species and MegaBean look as rig parts, in
the art guide's style: chibi cyborgs for a cyberpunk dive bar.

Run:  python tools/art/characters_svg.py
Writes art/characters/customers/<type>/<part>.svg for every customer type,
art/characters/synths/<species>/{glow, arm_front, visor}.svg for every species, and
art/characters/megabean/<class>/<part>.svg for MegaBean's staff, one look per
combat class (fighter, tank, ranged, fragile).

Hats and outfits (data/items.json "fashion") are drawn as parts too, in
art/characters/fashion/<id>/, to wear on the rig.

Each type also has back-view parts (torso_ne, head_ne, hair_ne; a Synth's
visor_ne) for walking away; legs, arms and props are shared with the front.

Every part uses the template's 256 x 440 canvas with the feet at (128, 430) and
the same joints (hips 128,340; neck 130,244; shoulders 72,262 and 190,262), so
the shared rig (src/ui/character_art.gd) poses them all the same way. Body
shapes follow art/templates/chibi_office_worker_se.svg; each type changes its
clothes, hair, skin and prop, so they read apart by silhouette.
Re-running overwrites these files.
"""
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "art", "characters"))
RIM = "#19f0ff"


def shade(hex_color, amount):
    hex_color = hex_color.lstrip("#")
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (0, 2, 4))
    if amount >= 0:
        r, g, b = (round(c + (255 - c) * amount) for c in (r, g, b))
    else:
        r, g, b = (round(c * (1 + amount)) for c in (r, g, b))
    return "#%02x%02x%02x" % (r, g, b)


def grad(gid, color, light=0.15, dark=-0.25, horizontal=False):
    x2, y2 = ("1", "0") if horizontal else ("1", "1")
    return ('<linearGradient id="%s" x1="0" y1="0" x2="%s" y2="%s"><stop offset="0" stop-color="%s"/>'
            '<stop offset="1" stop-color="%s"/></linearGradient>' % (gid, x2, y2, shade(color, light), shade(color, dark)))


def write(folder, name, defs, body):
    path = os.path.join(ROOT, folder)
    os.makedirs(path, exist_ok=True)
    svg = ('<?xml version="1.0" encoding="UTF-8"?>\n<!-- NanoBrew Café rig part: %s/%s. Made by tools/art/characters_svg.py '
           '(canvas 256 x 440, feet at 128, 430). -->\n<svg xmlns="http://www.w3.org/2000/svg" '
           'xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" width="256" height="440" viewBox="0 0 256 440">\n'
           '  <defs>%s</defs>\n  <g inkscape:label="%s" stroke-linejoin="round" stroke-linecap="round">\n    %s\n  </g>\n</svg>\n'
           % (folder, name, "".join(defs), name, "\n    ".join(body)))
    with open(os.path.join(path, name + ".svg"), "w", encoding="utf-8", newline="\n") as f:
        f.write(svg)


# --- a customer type ------------------------------------------------------
def customer(type_id, look, folder=None):
    folder = folder or "customers/" + type_id
    skin, skin_line = look["skin"], shade(look["skin"], -0.3)
    top, bottom, shoes = look["top"], look["bottom"], look.get("shoes", "#22202e")
    sleeve = skin if look.get("bare_arms") else look.get("sleeve", top)
    arm_w = 34 if look.get("bare_arms") else 30
    skin_g = grad("skin", skin, 0.25, -0.05)

    write(folder, "shadow", [], ['<ellipse cx="130" cy="425" rx="72" ry="15" fill="#000" opacity="0.22"/>'])

    leg_h = 60 if look.get("shorts") else 76
    def leg(x, y, w, shoe_x, shoe_y, rx, ry):
        body = ['<rect x="%d" y="%d" width="%d" height="%d" rx="13" fill="url(#bottom)" stroke="%s" stroke-width="4"/>'
                % (x, y, w, leg_h, shade(bottom, -0.55))]
        if look.get("shorts"):
            body.append('<rect x="%d" y="%d" width="%d" height="%d" rx="10" fill="url(#skin)" stroke="%s" stroke-width="4"/>'
                        % (x + 4, y + leg_h - 8, w - 8, 80 - leg_h + 4, skin_line))
        body.append('<ellipse cx="%d" cy="%d" rx="%d" ry="%d" fill="%s" stroke="%s" stroke-width="4"/>'
                    % (shoe_x, shoe_y, rx, ry, shoes, shade(shoes, -0.5)))
        if shoes != "#22202e":
            body.append('<path d="M%d,%d l%d,0" stroke="%s" stroke-width="4"/>' % (shoe_x - rx + 6, shoe_y + 4, 2 * rx - 12, shade(shoes, -0.35)))
        return body
    write(folder, "leg_back", [grad("bottom", bottom), skin_g], leg(98, 336, 30, 110, 414, 22, 11))
    write(folder, "leg_front", [grad("bottom", bottom), skin_g], leg(134, 338, 32, 154, 418, 24, 12))

    def arm(x, w, angle, pivot, hand, r):
        return ['<rect x="%d" y="258" width="%d" height="82" rx="15" fill="url(#sleeve)" stroke="%s" stroke-width="4" transform="rotate(%d %s)"/>'
                % (x, w, shade(sleeve, -0.45 if sleeve != skin else -0.3), angle, pivot),
                '<circle cx="%d" cy="%d" r="%d" fill="url(#skin)" stroke="%s" stroke-width="4"/>' % (hand[0], hand[1], r, skin_line)]
    write(folder, "arm_back", [grad("sleeve", shade(sleeve, -0.2) if sleeve != skin else sleeve, 0.1, -0.3), skin_g],
          arm(58 - (arm_w - 28) // 2, arm_w, 8, "72 258", (66, 342), 14))
    write(folder, "arm_front", [grad("sleeve", sleeve, 0.15, -0.25), skin_g], arm(176 - (arm_w - 30) // 2, arm_w, -6, "191 258", (198, 344), 15))

    wide = look.get("wide", 0)
    torso = ['<path d="M%d,250 Q128,230 %d,250 L%d,346 Q128,364 %d,346 Z" fill="url(#top)" stroke="%s" stroke-width="4"/>'
             % (78 - wide, 182 + wide, 196 + wide // 2, 62 - wide // 2, shade(top, -0.5)),
             '<path d="M%d,250 Q74,300 66,344 Q86,352 104,355 Q92,300 96,252 Z" fill="%s" opacity="0.35"/>' % (78 - wide, shade(top, -0.55))]
    torso += look["torso_details"]
    torso.append('<path d="M%d,262 L%d,340" stroke="%s" stroke-width="5" opacity="0.75"/>' % (184 + wide, 194 + wide // 2, RIM))
    write(folder, "torso", [grad("top", top), skin_g] + look.get("torso_defs", []), torso)

    head = ['<ellipse cx="54" cy="166" rx="16" ry="20" fill="url(#skin)" stroke="%s" stroke-width="4"/>' % skin_line
            if not look.get("no_ears") else "",
            '<ellipse cx="130" cy="152" rx="92" ry="88" fill="url(#skin)" stroke="%s" stroke-width="4"/>' % skin_line,
            '<path d="M44,150 Q44,215 92,236 Q60,200 66,150 Z" fill="%s" opacity="0.45"/>' % shade(skin, -0.12),
            '<path d="M214,120 Q226,160 212,198" stroke="%s" stroke-width="5" fill="none" opacity="0.7"/>' % RIM]
    write(folder, "head", [skin_g], head)
    write(folder, "hair", look.get("hair_defs", []), look["hair"])
    write(folder, "prop", look.get("prop_defs", []), look["prop"])
    faces(folder, look.get("eyes", "#2b2238"), look.get("big_eyes", False))

    # The back view (walking away, facing up-right): the back of the clothes, of
    # the head (both ears, no face) and of the hair. Legs, arms and prop are shared.
    back = ['<path d="M%d,250 Q128,230 %d,250 L%d,346 Q128,364 %d,346 Z" fill="url(#top)" stroke="%s" stroke-width="4"/>'
            % (78 - wide, 182 + wide, 196 + wide // 2, 62 - wide // 2, shade(top, -0.5)),
            '<path d="M%d,250 Q74,300 66,344 Q86,352 104,355 Q92,300 96,252 Z" fill="%s" opacity="0.35"/>' % (78 - wide, shade(top, -0.55)),
            '<path d="M128,246 L128,350" stroke="%s" stroke-width="3" opacity="0.5"/>' % shade(top, -0.5)]
    back += BACK_TORSO.get(folder, [])
    back.append('<path d="M%d,262 L%d,340" stroke="%s" stroke-width="5" opacity="0.75"/>' % (184 + wide, 194 + wide // 2, RIM))
    write(folder, "torso_ne", [grad("top", top), skin_g] + look.get("torso_defs", []), back)
    ears = "" if look.get("no_ears") else ('<ellipse cx="54" cy="166" rx="16" ry="20" fill="url(#skin)" stroke="%s" stroke-width="4"/>'
                                           '<ellipse cx="206" cy="166" rx="16" ry="20" fill="url(#skin)" stroke="%s" stroke-width="4"/>' % (skin_line, skin_line))
    write(folder, "head_ne", [skin_g], [ears,
          '<ellipse cx="130" cy="152" rx="92" ry="88" fill="url(#skin)" stroke="%s" stroke-width="4"/>' % skin_line,
          '<path d="M44,150 Q44,215 92,236 Q60,200 66,150 Z" fill="%s" opacity="0.45"/>' % shade(skin, -0.12),
          '<path d="M214,120 Q226,160 212,198" stroke="%s" stroke-width="5" fill="none" opacity="0.7"/>' % RIM])
    write(folder, "hair_ne", look.get("hair_defs", []) + [CHROME_DEF], BACK_HAIR[folder])


def faces(folder, eye, big):
    s = 1.25 if big else 1.0
    def eyes(open_scale=1.0):
        return ('<ellipse cx="118" cy="166" rx="%.0f" ry="%.0f" fill="%s"/><ellipse cx="176" cy="164" rx="%.0f" ry="%.0f" fill="%s"/>'
                '<circle cx="122" cy="158" r="%.1f" fill="#fff"/><circle cx="181" cy="156" r="%.1f" fill="#fff"/>'
                % (12 * s, 18 * s * open_scale, eye, 14 * s, 19 * s * open_scale, eye, 5 * s, 5.5 * s))
    blush = ('<ellipse cx="100" cy="196" rx="13" ry="7" fill="#ff8fa3" opacity="%s"/>'
             '<ellipse cx="196" cy="194" rx="14" ry="7" fill="#ff8fa3" opacity="%s"/>')
    mouth = '<path d="M140,204 Q151,214 162,203" fill="none" stroke="#7a3b3b" stroke-width="4"/>'
    write(folder, "face_neutral", [], [eyes(), blush % ("0.55", "0.55"), mouth])
    write(folder, "face_happy", [], [blush % ("0.8", "0.8"),
          '<path d="M106,170 Q118,150 130,170 M162,168 Q176,148 190,168" fill="none" stroke="%s" stroke-width="7"/>' % eye,
          '<path d="M134,198 Q151,226 170,197 Z" fill="#7a3b3b" stroke="#7a3b3b" stroke-width="4"/>',
          '<path d="M142,206 Q151,214 162,205" fill="#ff8fa3"/>'])
    write(folder, "face_angry", [], [blush.replace("#ff8fa3", "#ff5a6a") % ("0.55", "0.55"), eyes(0.78),
          '<path d="M102,140 L134,152 M194,138 L162,150" stroke="#3e2a22" stroke-width="7"/>',
          '<path d="M138,214 Q151,202 164,214" fill="none" stroke="#7a3b3b" stroke-width="5"/>'])
    write(folder, "face_eat", [], [blush % ("0.55", "0.55"), eyes(),
          '<ellipse cx="151" cy="208" rx="10" ry="8" fill="#7a3b3b" stroke="#5a2a2a" stroke-width="3"/>'])
    write(folder, "face_rest", [], [blush % ("0.35", "0.35"),
          '<path d="M106,166 Q118,178 130,166 M164,164 Q176,176 188,164" fill="none" stroke="%s" stroke-width="6"/>' % eye,
          '<path d="M144,206 Q151,210 158,206" fill="none" stroke="#7a3b3b" stroke-width="4"/>'])


MAGENTA = "#ff2fb4"
CYAN = "#19f0ff"
ACID = "#b6ff3b"
AMBER = "#ffb03b"
CHROME_LINE = "#2a3046"


def led(points, color, width=4):
    """An LED line (tattoo, trim): a soft halo and a bright core."""
    return ('<path d="%s" fill="none" stroke="%s" stroke-width="%d" stroke-opacity="0.35"/>'
            '<path d="%s" fill="none" stroke="%s" stroke-width="%d"/>' % (points, color, width * 3, points, color, width))


def cheek_plate(color):
    """A chrome plate on the right cheek with two LEDs."""
    return ('<path d="M190,176 L214,170 L216,196 L196,204 Z" fill="url(#chrome)" stroke="%s" stroke-width="3"/>'
            '<circle cx="203" cy="182" r="3" fill="%s"/><circle cx="208" cy="192" r="3" fill="%s"/>' % (CHROME_LINE, color, color))


CHROME_DEF = grad("chrome", "#dfe6f2", 0.2, -0.35)

CUSTOMERS = {
    "office_worker": {  # corp drone: dark suit, LED tie, earpiece
        "skin": "#f4c7a5", "top": "#262a3e", "bottom": "#1c1f2e", "shoes": "#14111f",
        "torso_details": ['<path d="M108,246 L128,292 L150,246 Q128,238 108,246 Z" fill="#d9dde8" stroke="#8d96ab" stroke-width="3"/>',
                          '<path d="M123,262 L134,262 L139,312 L128,326 L118,312 Z" fill="#14111f" stroke="#0a0812" stroke-width="3"/>',
                          led("M128,268 L128,316", CYAN, 3),
                          '<path d="M164,276 l14 0" stroke="%s" stroke-width="5"/>' % MAGENTA],
        "hair": ['<path d="M38,162 C28,84 88,46 140,50 C200,54 234,98 222,152 C204,122 164,104 122,110 C96,114 72,128 62,166 Z" fill="url(#hair)" stroke="#0e0b17" stroke-width="4"/>',
                 led("M150,62 C178,66 204,86 210,112", CYAN, 3),
                 '<rect x="40" y="150" width="18" height="30" rx="6" fill="url(#chrome)" stroke="%s" stroke-width="3"/>' % CHROME_LINE,
                 '<circle cx="49" cy="160" r="4" fill="%s"/>' % CYAN],
        "hair_defs": [grad("hair", "#2a2438", 0.1, -0.3), CHROME_DEF],
        "prop": ['<path d="M186,338 Q198,322 212,338" fill="none" stroke="#14111f" stroke-width="5"/>',
                 '<rect x="170" y="340" width="60" height="44" rx="7" fill="url(#case)" stroke="#0a0812" stroke-width="4"/>',
                 led("M176,362 L224,362", CYAN, 3)],
        "prop_defs": [grad("case", "#3a3f5c", 0.15, -0.3)],
    },
    "gym_fan": {  # street brawler: neon tank top, buzz cut, chrome jaw, energy can
        "skin": "#c98a5e", "top": "#1f1a2e", "bottom": "#2b2f42", "shoes": "#ff2fb4", "bare_arms": True, "wide": 10, "shorts": True,
        "torso_details": ['<path d="M100,244 Q128,280 156,244 Q128,238 100,244 Z" fill="url(#skin)" stroke="#8a5a3a" stroke-width="3"/>',
                          led("M98,296 L128,282 L158,296 L128,322 Z", ACID, 4)],
        "hair": ['<path d="M44,150 C40,90 90,58 140,58 C196,60 230,96 220,148 C200,124 160,116 124,118 C96,120 70,130 58,152 Z" fill="url(#hair)" stroke="#0e0b17" stroke-width="4"/>',
                 led("M60,100 Q132,72 214,98", MAGENTA, 5),
                 '<path d="M118,226 Q152,244 192,222 L196,236 Q152,258 114,240 Z" fill="url(#chrome)" stroke="%s" stroke-width="3"/>' % CHROME_LINE,
                 '<path d="M76,180 l10 -6 l4 14 M84,196 l10 -4" stroke="%s" stroke-width="3" fill="none"/>' % MAGENTA],
        "hair_defs": [grad("hair", "#2a2026", 0.1, -0.3), CHROME_DEF],
        "prop": ['<rect x="184" y="318" width="28" height="48" rx="8" fill="url(#can)" stroke="#2a3046" stroke-width="4"/>',
                 led("M188,334 L208,334", ACID, 3),
                 '<ellipse cx="198" cy="318" rx="14" ry="5" fill="#c9d2e3" stroke="#2a3046" stroke-width="2"/>'],
        "prop_defs": [grad("can", "#1f1a2e", 0.2, -0.2)],
    },
    "gamer": {  # netrunner: LED hoodie, headset, cyberdeck
        "skin": "#ffe0c7", "top": "#2a2045", "bottom": "#1c1f2e",
        "torso_details": ['<path d="M84,254 Q128,212 176,254 Q128,280 84,254 Z" fill="#221a3a" stroke="#120e22" stroke-width="4"/>',
                          led("M118,268 L114,300 M140,268 L144,300", CYAN, 3),
                          led("M82,330 L176,330", MAGENTA, 3),
                          '<path d="M96,318 Q128,330 162,318 L158,344 Q128,350 100,344 Z" fill="#221a3a" stroke="#120e22" stroke-width="3"/>'],
        "hair": ['<path d="M38,162 C24,84 92,40 140,46 C204,50 238,100 222,156 C214,124 190,110 170,116 C176,100 160,92 150,104 C140,90 118,96 116,110 C92,108 70,124 62,166 Z" fill="url(#hair)" stroke="#0e0b17" stroke-width="4"/>',
                 '<path d="M150,60 l18 30 l-10 0 l14 24" fill="none" stroke="%s" stroke-width="5"/>' % CYAN,
                 '<path d="M34,152 Q30,46 130,40 Q230,44 226,150" fill="none" stroke="#14111f" stroke-width="12"/>',
                 '<rect x="208" y="130" width="28" height="44" rx="12" fill="#14111f" stroke="#0a0812" stroke-width="4"/>',
                 '<rect x="214" y="138" width="16" height="28" rx="6" fill="%s"/>' % MAGENTA,
                 '<path d="M222,172 Q214,206 180,212" fill="none" stroke="#14111f" stroke-width="6"/>',
                 '<circle cx="178" cy="212" r="7" fill="%s"/>' % CYAN],
        "hair_defs": [grad("hair", "#1f2a5a", 0.15, -0.2)],
        "prop": ['<rect x="164" y="326" width="70" height="36" rx="8" fill="#14111f" stroke="#0a0812" stroke-width="4"/>',
                 '<rect x="172" y="332" width="54" height="16" rx="3" fill="%s"/>' % CYAN,
                 '<path d="M176,354 l8 0 m4 0 l8 0 m4 0 l8 0 m4 0 l8 0" stroke="#7a829c" stroke-width="4"/>'],
    },
    "influencer": {  # neon idol: two-tone hair, holo jacket, LED face tattoo, holo phone
        "skin": "#e9b38c", "top": "#c9d2e3", "bottom": "#14111f", "shoes": "#19f0ff",
        "torso_details": ['<path d="M104,246 L128,300 L152,246 Q128,238 104,246 Z" fill="#14111f" stroke="#0a0812" stroke-width="3"/>',
                          '<path d="M82,262 L176,300 M78,304 L180,340" stroke="#ff2fb4" stroke-width="6" opacity="0.5"/>',
                          '<path d="M86,286 L178,320" stroke="#19f0ff" stroke-width="6" opacity="0.5"/>',
                          led("M108,262 Q128,286 150,262", MAGENTA, 3)],
        "hair": ['<path d="M26,190 C2,110 54,36 132,34 C214,34 254,104 234,192 C226,168 214,146 196,122 C170,108 120,104 92,118 C70,130 50,160 46,206 Z" fill="url(#hairl)" stroke="#6a1a5a" stroke-width="4"/>',
                 '<path d="M132,34 C214,34 254,104 234,192 C226,168 214,146 196,122 C176,110 150,104 132,106 Z" fill="url(#hairr)" stroke="#0a6f86" stroke-width="4"/>',
                 '<path d="M30,180 Q20,240 52,264 Q46,222 56,190 Z" fill="url(#hairl)" stroke="#6a1a5a" stroke-width="4"/>',
                 '<path d="M226,180 Q238,236 210,262 Q218,222 210,188 Z" fill="url(#hairr)" stroke="#0a6f86" stroke-width="4"/>',
                 led("M196,182 l8 10 l-8 10", CYAN, 3), led("M92,200 l-10 6", MAGENTA, 3)],
        "hair_defs": [grad("hairl", "#ff4fd8", 0.2, -0.2), grad("hairr", "#19f0ff", 0.2, -0.3)],
        "prop": ['<rect x="186" y="290" width="30" height="52" rx="7" fill="#14111f" stroke="#0a0812" stroke-width="4"/>',
                 '<rect x="190" y="296" width="22" height="38" rx="3" fill="url(#screen)"/>',
                 '<path d="M170,262 L232,262 L216,294 L186,294 Z" fill="#19f0ff" opacity="0.25"/>'],
        "prop_defs": [grad("screen", "#ff4fd8", 0.3, -0.1)],
    },
    "grandparent": {  # retro cyborg grandma: chrome bun, LED glasses, circuit cardigan, cane
        "skin": "#f7d2bd", "top": "#3a4a5a", "bottom": "#2b2236", "shoes": "#14111f",
        "torso_details": ['<path d="M108,246 L128,290 L148,246 Q128,238 108,246 Z" fill="#d9dde8" stroke="#8d96ab" stroke-width="3"/>',
                          '<path d="M128,292 L128,350" stroke="#22303e" stroke-width="3"/>',
                          '<circle cx="134" cy="306" r="5" fill="%s"/><circle cx="134" cy="326" r="5" fill="%s"/>' % (ACID, ACID),
                          led("M84,286 L100,286 L106,300 L120,300", ACID, 2), led("M176,310 L160,310 L154,322", ACID, 2)],
        "hair": ['<path d="M40,170 C30,96 86,62 138,62 C196,64 232,100 222,160 C212,130 178,112 134,112 C98,114 70,132 62,170 Z" fill="url(#hair)" stroke="#8d96ab" stroke-width="4"/>',
                 '<circle cx="132" cy="50" r="30" fill="url(#chrome)" stroke="%s" stroke-width="4"/>' % CHROME_LINE,
                 '<path d="M108,40 Q132,30 156,40" fill="none" stroke="%s" stroke-width="3"/>' % ACID,
                 '<rect x="92" y="150" width="54" height="30" rx="10" fill="%s" opacity="0.35" stroke="%s" stroke-width="5"/>' % (ACID, "#2a3046"),
                 '<rect x="152" y="148" width="56" height="32" rx="10" fill="%s" opacity="0.35" stroke="%s" stroke-width="5"/>' % (ACID, "#2a3046"),
                 '<path d="M146,164 L152,164" stroke="#2a3046" stroke-width="5"/>'],
        "hair_defs": [grad("hair", "#d9dde8", 0.2, -0.2), CHROME_DEF],
        "prop": ['<path d="M206,330 L220,428" stroke="#2a3046" stroke-width="9"/>',
                 '<path d="M190,334 Q196,310 214,318 Q222,322 220,336" fill="none" stroke="#2a3046" stroke-width="9"/>',
                 '<circle cx="220" cy="428" r="8" fill="%s"/>' % ACID, led("M210,350 L218,412", ACID, 2)],
    },
    "alien_tourist": {  # off-world tourist: lavender skin, glowing antennae, flight jacket, holo camera
        "skin": "#b9a7f0", "top": "#3a2a5a", "bottom": "#2b2f42", "shoes": "#c9d2e3", "shorts": True, "no_ears": True,
        "eyes": "#0a1a3a", "big_eyes": True,
        "torso_details": ['<path d="M108,246 L128,276 L148,246 Q128,238 108,246 Z" fill="#c9d2e3" stroke="#7a829c" stroke-width="3"/>',
                          '<rect x="150" y="270" width="22" height="16" rx="3" fill="%s"/>' % AMBER,
                          led("M84,320 L176,320", CYAN, 3),
                          '<path d="M96,250 L178,326" stroke="#14111f" stroke-width="5"/>'],
        "hair": ['<path d="M96,74 Q80,30 64,18" fill="none" stroke="#7a62c8" stroke-width="7"/>',
                 '<path d="M166,72 Q186,28 204,16" fill="none" stroke="#7a62c8" stroke-width="7"/>',
                 '<circle cx="62" cy="16" r="16" fill="%s" opacity="0.35"/><circle cx="62" cy="16" r="10" fill="%s"/>' % (MAGENTA, MAGENTA),
                 '<circle cx="206" cy="14" r="16" fill="%s" opacity="0.35"/><circle cx="206" cy="14" r="10" fill="%s"/>' % (CYAN, CYAN)],
        "prop": ['<rect x="168" y="326" width="58" height="40" rx="8" fill="#14111f" stroke="#0a0812" stroke-width="4"/>',
                 '<circle cx="197" cy="346" r="13" fill="#2a3046" stroke="#0a0812" stroke-width="3"/>',
                 '<circle cx="197" cy="346" r="6" fill="%s"/>' % MAGENTA,
                 '<path d="M226,330 L250,316 L250,370 L226,356 Z" fill="%s" opacity="0.25"/>' % CYAN],
    },
}


# --- a Synth species' tech parts --------------------------------------------
def synth(species_id, color, arm, visor):
    folder = "synths/" + species_id
    write(folder, "glow", ['<radialGradient id="glow" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="%s" stop-opacity="0.6"/>'
                           '<stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient>' % (color, color)],
          ['<ellipse cx="128" cy="300" rx="128" ry="150" fill="url(#glow)"/>'])
    metal = grad("metal", "#c9d2e3", 0.3, -0.4)
    write(folder, "arm_front", [metal, grad("lit", color, 0.3, -0.2)], arm)
    write(folder, "visor", [metal, grad("lit", color, 0.4, -0.25, horizontal=True)], visor)
    write(folder, "visor_ne", [metal, grad("lit", color, 0.4, -0.25, horizontal=True)], VISOR_BACK[species_id])


def mech_arm(color, extra=""):
    """A chrome mechanical arm with a glowing elbow, piston lines and claw fingers."""
    return ['<rect x="176" y="254" width="32" height="48" rx="8" fill="url(#metal)" stroke="#2a3046" stroke-width="4"/>',
            '<path d="M182,264 L202,264 M182,276 L202,276" stroke="#2a3046" stroke-width="3"/>',
            '<circle cx="192" cy="306" r="12" fill="url(#lit)" stroke="#2a3046" stroke-width="4"/>',
            '<circle cx="192" cy="306" r="18" fill="%s" opacity="0.25"/>' % color,
            '<rect x="181" y="308" width="24" height="36" rx="6" fill="url(#metal)" stroke="#2a3046" stroke-width="4"/>',
            '<path d="M186,316 L186,336" stroke="%s" stroke-width="4"/>' % color,
            '<path d="M182,344 l-6,14 M193,346 l0,16 M204,344 l6,14" stroke="#2a3046" stroke-width="6"/>',
            '<path d="M204,262 L204,298" stroke="%s" stroke-width="3" opacity="0.9"/>' % CYAN] + ([extra] if extra else [])


def jack(color):
    """A chrome ear jack with a status LED (on the far side of the head)."""
    return ('<rect x="40" y="148" width="22" height="34" rx="6" fill="url(#metal)" stroke="#2a3046" stroke-width="4"/>'
            '<circle cx="51" cy="158" r="4" fill="%s"/>' % color)


SYNTHS = {
    "clerkbot": ("#4fb3ff", mech_arm("#4fb3ff"),
        ['<rect x="84" y="140" width="130" height="44" rx="12" fill="url(#lit)" stroke="#123a7a" stroke-width="4"/>',
         '<path d="M96,152 L150,152" stroke="#ffffff" stroke-width="5" opacity="0.8"/>',
         '<path d="M84,184 L60,196 M214,184 L226,198" stroke="#2a3046" stroke-width="5"/>', jack("#4fb3ff")]),
    "bulkform": ("#ff8a3d", mech_arm("#ff8a3d", '<rect x="166" y="334" width="52" height="34" rx="10" fill="url(#metal)" stroke="#2a3046" stroke-width="4"/>'),
        ['<path d="M70,150 Q130,132 214,146 L214,166 Q130,152 70,170 Z" fill="url(#lit)" stroke="#8a3a10" stroke-width="4"/>',
         '<path d="M112,214 Q150,236 192,212 L196,230 Q150,254 110,232 Z" fill="url(#metal)" stroke="#2a3046" stroke-width="4"/>',
         '<path d="M128,226 l0,12 M146,230 l0,12 M164,228 l0,12" stroke="#2a3046" stroke-width="3"/>', jack("#ff8a3d")]),
    "glitchling": ("#c46bff", mech_arm("#c46bff"),
        ['<rect x="80" y="134" width="138" height="58" rx="12" fill="#0a0812" stroke="#5a1f8a" stroke-width="4"/>',
         '<rect x="104" y="150" width="18" height="18" fill="#c46bff"/><rect x="170" y="150" width="18" height="18" fill="#c46bff"/>',
         '<rect x="88" y="174" width="40" height="5" fill="#19f0ff"/><rect x="150" y="142" width="56" height="4" fill="#ff2fb4"/>',
         '<path d="M60,120 Q40,80 70,60 M200,110 Q230,80 214,52" fill="none" stroke="#2a3046" stroke-width="6"/>', jack("#c46bff")]),
    "hypeform": ("#ff4fd8", mech_arm("#ff4fd8", '<circle cx="193" cy="352" r="20" fill="none" stroke="#ff4fd8" stroke-width="6"/>'),
        ['<path d="M86,160 C86,138 118,136 122,156 C126,136 156,138 152,162 C150,180 122,192 118,196 C112,190 86,178 86,160 Z" fill="url(#lit)" stroke="#8a1a6a" stroke-width="4"/>',
         '<path d="M148,160 C148,138 180,136 184,156 C188,136 218,138 214,162 C212,180 184,192 180,196 C174,190 148,178 148,160 Z" fill="url(#lit)" stroke="#8a1a6a" stroke-width="4"/>',
         '<path d="M146,158 L154,158" stroke="#8a1a6a" stroke-width="5"/>',
         '<path d="M190,200 l14 6 l-4 14" fill="none" stroke="#19f0ff" stroke-width="4"/>', jack("#ff4fd8")]),
    "steady_unit": ("#9cff6b", mech_arm("#9cff6b"),
        ['<circle cx="178" cy="164" r="30" fill="url(#lit)" stroke="#2a3046" stroke-width="6" opacity="0.9"/>',
         '<circle cx="178" cy="164" r="12" fill="#14111f"/><circle cx="178" cy="164" r="5" fill="#9cff6b"/>',
         '<path d="M208,160 L228,140 L228,100" fill="none" stroke="#2a3046" stroke-width="5"/><circle cx="228" cy="96" r="8" fill="#9cff6b"/>',
         '<path d="M96,186 L120,180 L124,200 L100,206 Z" fill="url(#metal)" stroke="#2a3046" stroke-width="3"/>', jack("#9cff6b")]),
    "xeno": ("#3dffd0", ['<path d="M188,256 Q206,276 192,300 Q178,322 196,342" fill="none" stroke="#2a3046" stroke-width="26"/>',
                        '<path d="M188,256 Q206,276 192,300 Q178,322 196,342" fill="none" stroke="url(#metal)" stroke-width="18"/>',
                        '<circle cx="196" cy="270" r="6" fill="#3dffd0"/><circle cx="188" cy="306" r="6" fill="#3dffd0"/><circle cx="190" cy="334" r="6" fill="#3dffd0"/>',
                        '<path d="M196,344 l-8,16 M196,346 l2,18 M198,344 l10,14" stroke="#2a3046" stroke-width="6"/>'],
        ['<path d="M62,120 Q130,92 210,118 L204,134 Q130,108 68,136 Z" fill="url(#metal)" stroke="#2a3046" stroke-width="4"/>',
         '<path d="M130,108 L118,74 L130,60 L142,74 Z" fill="url(#lit)" stroke="#0a6f5a" stroke-width="4"/>',
         '<path d="M96,118 L88,96 L100,92 Z M164,116 L172,94 L160,90 Z" fill="url(#lit)" stroke="#0a6f5a" stroke-width="3"/>']),
}


# --- MegaBean staff: corporate black and red enforcers, with the bean logo -------
BEAN = ('<ellipse cx="%d" cy="%d" rx="9" ry="12" fill="#d62f45" stroke="#f1e4cc" stroke-width="3" transform="rotate(25 %d %d)"/>'
        '<path d="M%d,%d q4,8 0,16" fill="none" stroke="#f1e4cc" stroke-width="2"/>')


def bean(x, y):
    return BEAN % (x, y, x, y, x - 1, y - 8)


RED = "#d62f45"
VISOR = '<rect x="86" y="146" width="130" height="30" rx="10" fill="#0a0812" stroke="#2a3046" stroke-width="4"/>' \
        '<rect x="96" y="156" width="110" height="8" rx="4" fill="#d62f45"/>' \
        '<rect x="96" y="156" width="110" height="8" rx="4" fill="none" stroke="#d62f45" stroke-width="10" stroke-opacity="0.3"/>'

STAFF = {
    "fighter": {  # enforcer with a shock baton
        "skin": "#e8b48f", "top": "#16141c", "bottom": "#16141c", "shoes": "#0a0812",
        "torso_details": ['<path d="M96,256 L160,256 L166,300 L90,300 Z" fill="#2a2834" stroke="#0a0812" stroke-width="3"/>',
                          led("M90,300 L166,300", RED, 3), bean(128, 278)],
        "hair": ['<path d="M40,150 C34,92 86,56 136,56 C192,58 228,92 222,146 C206,120 166,108 126,110 C96,112 70,126 60,152 Z" fill="#14111f" stroke="#0a0812" stroke-width="4"/>',
                 VISOR],
        "prop": ['<path d="M200,334 L222,276" stroke="#2a2834" stroke-width="12"/>',
                 '<path d="M219,284 L226,264" stroke="%s" stroke-width="12"/>' % CYAN,
                 '<path d="M226,262 l8,-10 l-4,10 l8,-6" fill="none" stroke="%s" stroke-width="3"/>' % CYAN],
    },
    "tank": {  # riot cyborg with a heavy shield
        "skin": "#a8714a", "top": "#16141c", "bottom": "#16141c", "wide": 16,
        "torso_details": ['<path d="M80,256 L178,256 L184,330 L74,330 Z" fill="url(#armor)" stroke="#0a0812" stroke-width="4"/>',
                          led("M86,300 L172,300", RED, 4), bean(128, 278)],
        "torso_defs": [grad("armor", "#3a3846", 0.15, -0.3)],
        "hair": ['<path d="M42,140 C42,74 92,48 134,48 C182,48 224,74 222,140 Z" fill="url(#helm)" stroke="#0a0812" stroke-width="4"/>',
                 VISOR],
        "hair_defs": [grad("helm", "#3a3846", 0.2, -0.3)],
        "prop": ['<rect x="166" y="244" width="76" height="134" rx="14" fill="url(#shield)" stroke="#0a0812" stroke-width="5"/>',
                 '<rect x="176" y="256" width="56" height="40" rx="6" fill="#19f0ff" opacity="0.25"/>',
                 led("M172,318 L236,318", RED, 4),
                 bean(204, 346).replace('rx="9" ry="12"', 'rx="14" ry="18"')],
        "prop_defs": [grad("shield", "#2a2834", 0.25, -0.25)],
    },
    "ranged": {  # gunner with a caffeine rifle
        "skin": "#f2c9a8", "top": "#16141c", "bottom": "#16141c",
        "torso_details": ['<path d="M100,250 L156,330" stroke="%s" stroke-width="8"/>' % RED, bean(108, 300)],
        "hair": ['<path d="M42,160 C34,92 88,58 138,58 C194,60 230,96 222,150 C204,124 164,110 124,112 C96,114 72,128 62,160 Z" fill="#d62f45" stroke="#6a1020" stroke-width="4"/>',
                 '<rect x="160" y="150" width="50" height="26" rx="8" fill="#0a0812" stroke="#2a3046" stroke-width="3"/>',
                 '<circle cx="186" cy="163" r="8" fill="%s"/>' % RED],
        "prop": ['<rect x="168" y="324" width="72" height="22" rx="6" fill="#2a2834" stroke="#0a0812" stroke-width="4"/>',
                 '<rect x="236" y="328" width="18" height="12" rx="3" fill="#0a0812"/>',
                 '<rect x="180" y="344" width="14" height="22" rx="4" fill="#2a2834"/>',
                 led("M176,330 L226,330", RED, 3)],
    },
    "fragile": {  # corporate hacker intern with a holo tablet
        "skin": "#ffe0c7", "top": "#2a2834", "bottom": "#16141c",
        "torso_details": ['<path d="M104,250 L124,312 M154,250 L134,312" stroke="%s" stroke-width="5"/>' % RED,
                          '<rect x="114" y="308" width="30" height="36" rx="4" fill="#f4f6fb" stroke="#8d96ab" stroke-width="3"/>',
                          '<rect x="120" y="314" width="18" height="10" fill="%s"/>' % RED],
        "hair": ['<path d="M36,166 C22,90 84,44 140,48 C202,52 240,100 222,160 C214,130 196,116 180,122 C186,104 168,96 158,110 C150,94 128,98 124,112 C98,110 72,126 62,166 Z" fill="#e0e4ee" stroke="#8d96ab" stroke-width="4"/>',
                 '<path d="M90,150 L210,150" stroke="#0a0812" stroke-width="4"/>',
                 '<circle cx="118" cy="166" r="22" fill="none" stroke="#0a0812" stroke-width="5"/>',
                 '<circle cx="178" cy="164" r="22" fill="none" stroke="#0a0812" stroke-width="5"/>'],
        "prop": ['<rect x="174" y="302" width="54" height="62" rx="6" fill="#14111f" stroke="#0a0812" stroke-width="4"/>',
                 '<rect x="180" y="308" width="42" height="50" rx="3" fill="%s" opacity="0.85"/>' % RED,
                 '<path d="M186,320 l28,0 M186,332 l20,0 M186,344 l26,0" stroke="#ffffff" stroke-width="3" opacity="0.8"/>'],
    },
}


# --- the back view ----------------------------------------------------------
# Hair covering the back of the head (head ellipse: centre 130,152, 92 x 88).
CAP = "M38,166 C28,84 88,48 132,48 C190,50 236,90 222,170 Q214,206 184,214 Q132,226 80,214 Q50,206 38,166 Z"


def cap(fill, line):
    return '<path d="%s" fill="%s" stroke="%s" stroke-width="4"/>' % (CAP, fill, line)


STRAP = ('<path d="M40,168 Q130,186 222,166 L222,182 Q130,202 40,184 Z" fill="#14111f" stroke="#0a0812" stroke-width="3"/>'
         '<circle cx="130" cy="186" r="5" fill="%s"/>')

BACK_HAIR = {
    "customers/office_worker": [cap("url(#hair)", "#0e0b17"), led("M150,62 C178,66 204,86 210,112", CYAN, 3),
                                '<rect x="200" y="150" width="18" height="30" rx="6" fill="url(#chrome)" stroke="%s" stroke-width="3"/>' % CHROME_LINE],
    "customers/gym_fan": ['<path d="M44,160 C40,90 90,58 140,58 C196,60 232,96 220,160 Q210,190 132,196 Q54,190 44,160 Z" fill="url(#hair)" stroke="#0e0b17" stroke-width="4"/>',
                          led("M46,118 Q132,92 220,116", MAGENTA, 5)],
    "customers/gamer": [cap("url(#hair)", "#0e0b17"), '<path d="M34,152 Q30,46 130,40 Q230,44 226,150" fill="none" stroke="#14111f" stroke-width="12"/>',
                        '<rect x="18" y="130" width="28" height="44" rx="12" fill="#14111f" stroke="#0a0812" stroke-width="4"/>',
                        '<rect x="214" y="130" width="28" height="44" rx="12" fill="#14111f" stroke="#0a0812" stroke-width="4"/>',
                        '<rect x="220" y="138" width="16" height="28" rx="6" fill="%s"/>' % MAGENTA],
    "customers/influencer": ['<path d="M24,200 C2,110 54,36 132,34 L132,262 Q70,272 36,244 Z" fill="url(#hairl)" stroke="#6a1a5a" stroke-width="4"/>',
                             '<path d="M132,34 C214,34 256,104 236,200 Q222,252 132,262 Z" fill="url(#hairr)" stroke="#0a6f86" stroke-width="4"/>',
                             led("M132,40 L132,256", "#ffffff", 2)],
    "customers/grandparent": [cap("url(#hair)", "#8d96ab"), '<circle cx="132" cy="50" r="30" fill="url(#chrome)" stroke="%s" stroke-width="4"/>' % CHROME_LINE,
                              '<path d="M60,166 Q130,176 204,164" fill="none" stroke="#2a3046" stroke-width="4"/>'],
    "customers/alien_tourist": ['<path d="M96,74 Q80,30 64,18" fill="none" stroke="#7a62c8" stroke-width="7"/>',
                                '<path d="M166,72 Q186,28 204,16" fill="none" stroke="#7a62c8" stroke-width="7"/>',
                                '<circle cx="62" cy="16" r="10" fill="%s"/><circle cx="206" cy="14" r="10" fill="%s"/>' % (MAGENTA, CYAN)],
    "megabean/fighter": [cap("#14111f", "#0a0812"), STRAP % "#d62f45"],
    "megabean/tank": ['<path d="M40,170 C30,80 90,46 134,46 C182,46 234,80 224,170 Q132,204 40,170 Z" fill="url(#helm)" stroke="#0a0812" stroke-width="4"/>',
                      led("M50,150 Q132,170 214,148", "#d62f45", 4)],
    "megabean/ranged": [cap("#d62f45", "#6a1020"), STRAP % "#d62f45"],
    "megabean/fragile": [cap("#e0e4ee", "#8d96ab"), '<path d="M50,164 Q130,176 210,162" fill="none" stroke="#0a0812" stroke-width="3"/>'],
}

BACK_TORSO = {
    "customers/office_worker": ['<path d="M128,300 L128,346" stroke="#14111f" stroke-width="4"/>', led("M92,262 L164,262", CYAN, 2)],
    "customers/gym_fan": ['<path d="M100,248 Q128,262 156,248" fill="none" stroke="#8a5a3a" stroke-width="4"/>', led("M104,300 L152,300", ACID, 4)],
    "customers/gamer": ['<path d="M84,252 Q128,226 174,252 Q162,292 128,298 Q94,292 84,252 Z" fill="#221a3a" stroke="#120e22" stroke-width="4"/>',
                        led("M100,316 L156,316", CYAN, 3)],
    "customers/influencer": ['<path d="M82,262 L176,300 M78,304 L180,340" stroke="#ff2fb4" stroke-width="6" opacity="0.5"/>',
                             '<path d="M86,286 L178,320" stroke="#19f0ff" stroke-width="6" opacity="0.5"/>'],
    "customers/grandparent": [led("M90,280 L110,280 L116,296 L140,296 L146,280 L166,280", ACID, 2)],
    "customers/alien_tourist": ['<rect x="104" y="280" width="48" height="30" rx="6" fill="%s" stroke="#8a5a1a" stroke-width="3"/>' % AMBER],
    "megabean/fighter": [bean(128, 290).replace('rx="9" ry="12"', 'rx="14" ry="18"'), led("M90,330 L166,330", "#d62f45", 3)],
    "megabean/tank": ['<path d="M80,256 L178,256 L184,330 L74,330 Z" fill="url(#armor)" stroke="#0a0812" stroke-width="4"/>',
                      bean(128, 292).replace('rx="9" ry="12"', 'rx="16" ry="21"')],
    "megabean/ranged": ['<path d="M156,250 L100,330" stroke="#d62f45" stroke-width="8"/>', bean(128, 300)],
    "megabean/fragile": ['<path d="M104,250 Q128,270 154,250" fill="none" stroke="#d62f45" stroke-width="5"/>'],
}

VISOR_BACK = {
    "clerkbot": [STRAP % "#4fb3ff", '<rect x="200" y="148" width="22" height="34" rx="6" fill="url(#metal)" stroke="#2a3046" stroke-width="4"/>'],
    "bulkform": [STRAP % "#ff8a3d", '<rect x="200" y="148" width="22" height="34" rx="6" fill="url(#metal)" stroke="#2a3046" stroke-width="4"/>'],
    "glitchling": [STRAP % "#c46bff", '<path d="M60,120 Q40,80 70,60 M200,110 Q230,80 214,52" fill="none" stroke="#2a3046" stroke-width="6"/>',
                   '<path d="M90,190 Q100,230 80,260 M170,190 Q160,230 180,260" fill="none" stroke="#c46bff" stroke-width="4"/>'],
    "hypeform": [STRAP % "#ff4fd8"],
    "steady_unit": [STRAP % "#9cff6b", '<path d="M208,160 L228,140 L228,100" fill="none" stroke="#2a3046" stroke-width="5"/><circle cx="228" cy="96" r="8" fill="#9cff6b"/>'],
    "xeno": ['<path d="M62,120 Q130,92 210,118 L204,134 Q130,108 68,136 Z" fill="url(#metal)" stroke="#2a3046" stroke-width="4"/>',
             '<path d="M130,108 L118,74 L130,60 L142,74 Z" fill="url(#lit)" stroke="#0a6f5a" stroke-width="4"/>'],
}


# --- fashion: hats and outfits worn on the rig ---------------------------------
# One folder per item in data/items.json ("fashion"), in the item's colour:
#   art/characters/fashion/<id>/hat.svg, hat_ne.svg        (a hat, over the hair)
#   art/characters/fashion/<id>/torso.svg, torso_ne.svg     (an outfit, over the body's torso)
#   art/characters/fashion/<id>/arm_back.svg                (its sleeve; a Synth's front arm is its own)
TORSO = "M74,250 Q128,228 186,250 L200,348 Q128,368 58,348 Z"
SLEEVE = '<rect x="56" y="258" width="32" height="82" rx="15" fill="url(#cloth)" stroke="%s" stroke-width="4" transform="rotate(8 72 258)"/>'


def hat(item_id, color, front, back):
    folder = "fashion/" + item_id
    defs = [grad("cloth", color, 0.2, -0.3), CHROME_DEF]
    write(folder, "hat", defs, front)
    write(folder, "hat_ne", defs, back)


def outfit(item_id, color, front, back, sleeve=True):
    folder = "fashion/" + item_id
    line = shade(color, -0.55)
    defs = [grad("cloth", color, 0.15, -0.3), CHROME_DEF]
    body = '<path d="%s" fill="url(#cloth)" stroke="%s" stroke-width="4"/>' % (TORSO, line)
    shadow = '<path d="M74,250 Q70,300 62,346 Q84,354 102,357 Q90,300 94,252 Z" fill="%s" opacity="0.35"/>' % line
    rim = '<path d="M188,262 L198,340" stroke="%s" stroke-width="5" opacity="0.75"/>' % RIM
    write(folder, "torso", defs, [body, shadow] + front + [rim])
    write(folder, "torso_ne", defs, [body, shadow, '<path d="M128,246 L128,352" stroke="%s" stroke-width="3" opacity="0.5"/>' % line] + back + [rim])
    if sleeve:
        write(folder, "arm_back", defs, [SLEEVE % line])


def fashion_parts():
    import json
    items = json.load(open(os.path.join(ROOT, "..", "..", "data", "items.json"), encoding="utf-8"))["fashion"]
    colors = {item["id"]: "#" + item["color"] for item in items}
    c = colors.get
    cap_dome = "M44,132 C44,62 92,34 134,34 C184,34 222,64 222,128 Q132,106 44,132 Z"
    if "neon_cap" in colors:
        hat("neon_cap", c("neon_cap"),
            ['<path d="%s" fill="#1f1a2e" stroke="#0a0812" stroke-width="4"/>' % cap_dome,
             led("M48,122 Q132,98 218,120", c("neon_cap"), 4),
             '<path d="M150,118 Q218,106 256,128 Q216,144 150,134 Z" fill="#14111f" stroke="#0a0812" stroke-width="4"/>',
             led("M156,128 Q214,120 248,130", c("neon_cap"), 3),
             '<circle cx="132" cy="40" r="7" fill="%s"/>' % c("neon_cap")],
            ['<path d="%s" fill="#1f1a2e" stroke="#0a0812" stroke-width="4"/>' % cap_dome,
             led("M48,122 Q132,98 218,120", c("neon_cap"), 4),
             '<path d="M112,124 Q132,108 152,124" fill="none" stroke="#0a0812" stroke-width="6"/>'])
    beanie = "M38,142 C38,58 92,28 132,28 C178,28 226,58 226,142 Z"
    if "beanie" in colors:
        ribs = "".join('<path d="M%d,%d L%d,140" stroke="%s" stroke-width="3" opacity="0.5"/>' % (x, 56 if 70 < x < 196 else 90, x, shade(c("beanie"), -0.4))
                       for x in range(56, 216, 18))
        parts = ['<path d="%s" fill="url(#cloth)" stroke="%s" stroke-width="4"/>' % (beanie, shade(c("beanie"), -0.55)), ribs,
                 '<path d="M36,126 Q132,108 228,126 L228,150 Q132,132 36,150 Z" fill="%s" stroke="%s" stroke-width="4"/>' % (shade(c("beanie"), -0.25), shade(c("beanie"), -0.6)),
                 led("M44,140 Q132,124 220,140", CYAN, 3),
                 '<path d="M132,28 L132,10" stroke="#2a3046" stroke-width="4"/><circle cx="132" cy="8" r="8" fill="%s"/>' % CYAN]
        hat("beanie", c("beanie"), parts, parts)
    if "top_hat" in colors:
        top = ['<ellipse cx="132" cy="96" rx="104" ry="20" fill="url(#cloth)" stroke="#0a0812" stroke-width="4"/>',
               '<path d="M74,94 L80,6 Q132,-4 184,6 L190,94 Q132,108 74,94 Z" fill="url(#cloth)" stroke="#0a0812" stroke-width="4"/>',
               '<path d="M77,64 Q132,74 187,64 L188,82 Q132,92 76,82 Z" fill="url(#chrome)" stroke="#2a3046" stroke-width="3"/>',
               led("M80,74 Q132,84 186,74", MAGENTA, 3),
               '<path d="M96,14 L94,58" stroke="#ffffff" stroke-width="5" opacity="0.25"/>']
        hat("top_hat", c("top_hat"), top, top)
    if "teal_jacket" in colors:
        outfit("teal_jacket", c("teal_jacket"),
               ['<path d="M100,244 Q128,262 156,244 L156,256 Q128,274 100,256 Z" fill="#14111f" stroke="#0a0812" stroke-width="3"/>',
                '<path d="M128,262 L128,350" stroke="#c9d2e3" stroke-width="4"/>',
                led("M66,320 L92,322 M164,322 L190,318", MAGENTA, 3),
                '<path d="M62,338 Q128,356 194,338 L196,350 Q128,368 60,350 Z" fill="#14111f" opacity="0.85"/>'],
               ['<path d="M100,244 Q128,262 156,244 L156,256 Q128,274 100,256 Z" fill="#14111f" stroke="#0a0812" stroke-width="3"/>',
                led("M92,292 L164,292", MAGENTA, 3),
                '<path d="M62,338 Q128,356 194,338 L196,350 Q128,368 60,350 Z" fill="#14111f" opacity="0.85"/>'])
    if "barista_apron" in colors:
        apron = c("barista_apron")
        outfit("barista_apron", "#2a2836",
               ['<path d="M110,246 L128,280 L146,246" fill="none" stroke="#c9d2e3" stroke-width="4"/>',
                '<path d="M92,286 L166,286 L174,354 Q128,366 84,354 Z" fill="%s" stroke="%s" stroke-width="4"/>' % (apron, shade(apron, -0.55)),
                '<path d="M100,254 L92,286 M156,254 L166,286" stroke="%s" stroke-width="5"/>' % shade(apron, -0.3),
                '<rect x="110" y="306" width="38" height="24" rx="4" fill="%s" stroke="%s" stroke-width="3"/>' % (shade(apron, -0.2), shade(apron, -0.55)),
                led("M88,294 L170,294", AMBER, 2)],
               ['<path d="M92,300 L166,300" stroke="%s" stroke-width="8"/>' % apron,
                '<path d="M120,300 l-12,24 M136,300 l12,24" stroke="%s" stroke-width="6"/>' % apron], sleeve=False)
    if "hoodie" in colors:
        hood = c("hoodie")
        outfit("hoodie", hood,
               ['<path d="M84,252 Q128,214 176,252 Q128,282 84,252 Z" fill="%s" stroke="%s" stroke-width="4"/>' % (shade(hood, -0.2), shade(hood, -0.6)),
                led("M116,268 L112,304 M142,268 L146,304", CYAN, 3),
                '<path d="M94,318 Q128,332 164,318 L160,346 Q128,354 98,346 Z" fill="%s" stroke="%s" stroke-width="3"/>' % (shade(hood, -0.15), shade(hood, -0.6))],
               ['<path d="M82,252 Q128,226 176,252 Q164,296 128,302 Q92,296 82,252 Z" fill="%s" stroke="%s" stroke-width="4"/>' % (shade(hood, -0.2), shade(hood, -0.6)),
                led("M98,320 L158,320", CYAN, 3)])


if __name__ == "__main__":
    for type_id, look in CUSTOMERS.items():
        customer(type_id, look)
    for class_id, look in STAFF.items():
        customer(class_id, look, "megabean/" + class_id)
    fashion_parts()
    for species_id, (color, arm, visor) in SYNTHS.items():
        synth(species_id, color, arm, visor)
    print("characters written to", ROOT)
