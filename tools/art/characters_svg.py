"""Draws the customer types and Synth species beyond the template's office worker
and Clerkbot, as rig parts in the art guide's style.

Run:  python tools/art/characters_svg.py
Writes art/characters/customers/<type>/<part>.svg for gym_fan, gamer, influencer,
grandparent and alien_tourist, art/characters/synths/<species>/{glow,
arm_front,visor}.svg for bulkform, glitchling, hypeform, steady_unit and xeno, and
art/characters/megabean/<class>/<part>.svg for MegaBean's staff, one look per
combat class (fighter, tank, ranged, fragile).

Every part uses the template's 256 x 440 canvas with the feet at (128, 430) and
the same joints (hips 128,340; neck 130,244; shoulders 72,262 and 190,262), so
the shared rig (src/ui/character_art.gd) poses them all the same way. Body
shapes follow art/templates/chibi_office_worker_se.svg; each type changes its
clothes, hair, skin and prop, so they read apart by silhouette.
Re-running overwrites these files (not the office worker or the Clerkbot).
"""
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "art", "characters"))
RIM = "#38e1ff"


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


CUSTOMERS = {
    "gym_fan": {
        "skin": "#d9976a", "top": "#e3485a", "bottom": "#3a3f5c", "shoes": "#f1f1f5", "bare_arms": True, "wide": 10, "shorts": True,
        "torso_details": ['<path d="M100,244 Q128,280 156,244 Q128,238 100,244 Z" fill="url(#skin)" stroke="#a86a46" stroke-width="3"/>',
                          '<path d="M92,300 L164,300" stroke="#ffffff" stroke-width="6" opacity="0.8"/>'],
        "hair": ['<path d="M44,150 C40,90 90,58 140,58 C196,60 230,96 220,148 C200,124 160,116 124,118 C96,120 70,130 58,152 Z" fill="url(#hair)" stroke="#2a1b15" stroke-width="4"/>',
                 '<path d="M44,128 Q130,92 222,124 L222,142 Q130,110 46,146 Z" fill="#e3485a" stroke="#9c2434" stroke-width="4"/>',
                 '<path d="M150,70 C176,74 198,90 206,108" stroke="#a37a62" stroke-width="5" fill="none" opacity="0.6"/>'],
        "hair_defs": [grad("hair", "#4a3226", 0.1, -0.3)],
        "prop": ['<rect x="186" y="318" width="26" height="54" rx="10" fill="url(#bottle)" stroke="#1d6f86" stroke-width="4"/>',
                 '<rect x="190" y="306" width="18" height="14" rx="4" fill="#f1f1f5" stroke="#8d96ab" stroke-width="3"/>',
                 '<path d="M193,330 L193,360" stroke="#ffffff" stroke-width="4" opacity="0.7"/>'],
        "prop_defs": [grad("bottle", "#4fd0ff", 0.25, -0.2)],
    },
    "gamer": {
        "skin": "#ffe0c7", "top": "#6a4fc4", "bottom": "#2c3046",
        "torso_details": ['<path d="M84,254 Q128,212 176,254 Q128,280 84,254 Z" fill="#5a40ad" stroke="#33236e" stroke-width="4"/>',
                          '<path d="M118,268 L114,300 M140,268 L144,300" stroke="#f1e4cc" stroke-width="4"/>',
                          '<path d="M96,318 Q128,330 162,318 L158,344 Q128,350 100,344 Z" fill="#5a40ad" stroke="#33236e" stroke-width="3"/>'],
        "hair": ['<path d="M38,162 C24,84 92,40 140,46 C204,50 238,100 222,156 C214,124 190,110 170,116 C176,100 160,92 150,104 C140,90 118,96 116,110 C92,108 70,124 62,166 Z" fill="url(#hair)" stroke="#16141f" stroke-width="4"/>',
                 '<path d="M34,152 Q30,46 130,40 Q230,44 226,150" fill="none" stroke="#2a2e3f" stroke-width="12"/>',
                 '<rect x="208" y="130" width="28" height="44" rx="12" fill="#2a2e3f" stroke="#16141f" stroke-width="4"/>',
                 '<rect x="214" y="138" width="16" height="28" rx="6" fill="#9cff6b" opacity="0.85"/>',
                 '<path d="M222,172 Q214,206 180,212" fill="none" stroke="#2a2e3f" stroke-width="6"/>',
                 '<circle cx="178" cy="212" r="7" fill="#2a2e3f"/>'],
        "hair_defs": [grad("hair", "#2f2a40", 0.15, -0.2)],
        "prop": ['<rect x="166" y="326" width="66" height="34" rx="12" fill="#2a2e3f" stroke="#16141f" stroke-width="4"/>',
                 '<rect x="184" y="332" width="30" height="22" rx="3" fill="#38e1ff"/>',
                 '<circle cx="175" cy="343" r="5" fill="#ff4fd8"/><circle cx="223" cy="343" r="5" fill="#9cff6b"/>'],
    },
    "influencer": {
        "skin": "#e9b38c", "top": "#ff6fb5", "bottom": "#f1ecf7", "shoes": "#ff6fb5",
        "torso_details": ['<path d="M104,246 L128,300 L152,246 Q128,238 104,246 Z" fill="#ffffff" stroke="#d6c8e0" stroke-width="3"/>',
                          '<path d="M108,262 Q128,286 150,262" fill="none" stroke="#ffd36b" stroke-width="4"/>',
                          '<circle cx="128" cy="282" r="6" fill="#ffd36b" stroke="#c9a03a" stroke-width="2"/>'],
        "hair": ['<path d="M26,190 C2,110 54,36 132,34 C214,34 254,104 234,192 C226,168 214,146 196,122 C170,108 120,104 92,118 C70,130 50,160 46,206 Z" fill="url(#hair)" stroke="#b5643a" stroke-width="4"/>',
                 '<path d="M30,180 Q20,240 52,264 Q46,222 56,190 Z M226,180 Q238,236 210,262 Q218,222 210,188 Z" fill="url(#hair)" stroke="#b5643a" stroke-width="4"/>',
                 '<path d="M120,46 C170,44 206,66 222,96" stroke="#fff1c9" stroke-width="7" fill="none" opacity="0.7"/>',
                 '<rect x="96" y="76" width="54" height="20" rx="9" fill="#2a2e3f" stroke="#16141f" stroke-width="3" transform="rotate(-8 123 86)"/>',
                 '<rect x="156" y="70" width="54" height="20" rx="9" fill="#2a2e3f" stroke="#16141f" stroke-width="3" transform="rotate(8 183 80)"/>'],
        "hair_defs": [grad("hair", "#ffc07a", 0.2, -0.25)],
        "prop": ['<rect x="186" y="290" width="30" height="52" rx="7" fill="#2a2e3f" stroke="#16141f" stroke-width="4"/>',
                 '<rect x="190" y="296" width="22" height="38" rx="3" fill="url(#screen)"/>',
                 '<path d="M196,306 l10,0 M196,314 l6,0" stroke="#ffffff" stroke-width="3" opacity="0.8"/>'],
        "prop_defs": [grad("screen", "#ff4fd8", 0.3, -0.1)],
    },
    "grandparent": {
        "skin": "#f7d2bd", "top": "#8fb08a", "bottom": "#7a5a44", "shoes": "#5e3d26",
        "torso_details": ['<path d="M108,246 L128,290 L148,246 Q128,238 108,246 Z" fill="#f4f0e6" stroke="#c9c0a8" stroke-width="3"/>',
                          '<path d="M128,292 L128,350" stroke="#5e7a58" stroke-width="3"/>',
                          '<circle cx="134" cy="306" r="5" fill="#f1e4cc" stroke="#8a7a5a" stroke-width="2"/>',
                          '<circle cx="134" cy="326" r="5" fill="#f1e4cc" stroke="#8a7a5a" stroke-width="2"/>',
                          '<path d="M80,280 L176,280" stroke="#a9c4a4" stroke-width="3" opacity="0.6"/>'],
        "hair": ['<path d="M40,170 C30,96 86,62 138,62 C196,64 232,100 222,160 C212,130 178,112 134,112 C98,114 70,132 62,170 Z" fill="url(#hair)" stroke="#8d8aa3" stroke-width="4"/>',
                 '<circle cx="132" cy="50" r="30" fill="url(#hair)" stroke="#8d8aa3" stroke-width="4"/>',
                 '<circle cx="118" cy="166" r="24" fill="none" stroke="#6b4130" stroke-width="5"/>',
                 '<circle cx="178" cy="164" r="25" fill="none" stroke="#6b4130" stroke-width="5"/>',
                 '<path d="M142,164 L153,164" stroke="#6b4130" stroke-width="5"/>',
                 '<path d="M110,150 L124,148" stroke="#ffffff" stroke-width="3" opacity="0.6"/>'],
        "hair_defs": [grad("hair", "#e6e4ef", 0.2, -0.15)],
        "prop": ['<path d="M206,330 L220,428" stroke="#6b4130" stroke-width="9"/>',
                 '<path d="M190,334 Q196,310 214,318 Q222,322 220,336" fill="none" stroke="#6b4130" stroke-width="9"/>',
                 '<path d="M208,340 L218,420" stroke="#a87a52" stroke-width="3" opacity="0.7"/>'],
    },
    "alien_tourist": {
        "skin": "#b9a7f0", "top": "#3fa58f", "bottom": "#c9b48a", "shoes": "#f1e4cc", "shorts": True, "no_ears": True,
        "eyes": "#1a2a4a", "big_eyes": True,
        "torso_details": ['<path d="M108,246 L128,276 L148,246 Q128,238 108,246 Z" fill="#f1e4cc" stroke="#c9b48a" stroke-width="3"/>',
                          '<circle cx="96" cy="292" r="10" fill="#ff8fa3"/><circle cx="160" cy="312" r="10" fill="#ffd36b"/>',
                          '<circle cx="112" cy="334" r="8" fill="#ff8fa3"/><circle cx="170" cy="276" r="7" fill="#ffffff"/>',
                          '<path d="M96,250 L178,326" stroke="#2a2e3f" stroke-width="5"/>'],
        "hair": ['<path d="M96,74 Q80,30 64,18" fill="none" stroke="#9a86d8" stroke-width="7"/>',
                 '<path d="M166,72 Q186,28 204,16" fill="none" stroke="#9a86d8" stroke-width="7"/>',
                 '<circle cx="62" cy="16" r="12" fill="#3dffd0" stroke="#1d8f78" stroke-width="3"/>',
                 '<circle cx="206" cy="14" r="12" fill="#3dffd0" stroke="#1d8f78" stroke-width="3"/>'],
        "prop": ['<rect x="168" y="326" width="58" height="40" rx="8" fill="#2a2e3f" stroke="#16141f" stroke-width="4"/>',
                 '<circle cx="197" cy="346" r="13" fill="#5a6a9a" stroke="#16141f" stroke-width="3"/>',
                 '<circle cx="197" cy="346" r="6" fill="#9feaff"/>',
                 '<rect x="174" y="318" width="16" height="10" rx="3" fill="#2a2e3f"/>'],
    },
}


# --- a Synth species' tech parts --------------------------------------------
def synth(species_id, color, arm, visor):
    folder = "synths/" + species_id
    write(folder, "glow", ['<radialGradient id="glow" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="%s" stop-opacity="0.55"/>'
                           '<stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient>' % (color, color)],
          ['<ellipse cx="128" cy="300" rx="128" ry="150" fill="url(#glow)"/>'])
    metal = grad("metal", "#c9cfdc", 0.3, -0.3)
    write(folder, "arm_front", [metal, grad("lit", color, 0.3, -0.2)], arm)
    write(folder, "visor", [metal, grad("lit", color, 0.4, -0.25, horizontal=True)], visor)


SYNTHS = {
    "bulkform": ("#ff8a3d",
        ['<rect x="172" y="250" width="40" height="52" rx="14" fill="url(#metal)" stroke="#5b647a" stroke-width="4"/>',
         '<rect x="186" y="262" width="8" height="30" rx="4" fill="#ff8a3d"/>',
         '<circle cx="192" cy="306" r="13" fill="url(#lit)" stroke="#a8541f" stroke-width="4"/>',
         '<rect x="178" y="308" width="30" height="34" rx="9" fill="url(#metal)" stroke="#5b647a" stroke-width="4"/>',
         '<rect x="170" y="336" width="46" height="30" rx="12" fill="url(#metal)" stroke="#5b647a" stroke-width="4"/>',
         '<path d="M178,344 L208,344 M178,354 L208,354" stroke="#8d96ab" stroke-width="4"/>',
         '<path d="M208,262 L210,334" stroke="#38e1ff" stroke-width="3" opacity="0.9"/>'],
        ['<path d="M70,150 Q130,132 214,146 L214,166 Q130,152 70,170 Z" fill="url(#lit)" stroke="#a8541f" stroke-width="4"/>',
         '<path d="M100,152 L150,146" stroke="#ffffff" stroke-width="4" opacity="0.8"/>',
         '<path d="M112,214 Q150,236 192,212 L196,228 Q150,252 110,230 Z" fill="url(#metal)" stroke="#5b647a" stroke-width="4"/>',
         '<path d="M128,226 l0,10 M146,230 l0,10 M164,228 l0,10" stroke="#5b647a" stroke-width="3"/>',
         '<rect x="44" y="150" width="20" height="30" rx="6" fill="url(#metal)" stroke="#5b647a" stroke-width="4"/>']),
    "glitchling": ("#c46bff",
        ['<rect x="180" y="256" width="24" height="44" rx="10" fill="url(#metal)" stroke="#5b647a" stroke-width="4"/>',
         '<path d="M182,270 Q196,278 202,268 M182,286 Q196,294 202,284" stroke="#c46bff" stroke-width="4" fill="none"/>',
         '<circle cx="192" cy="304" r="10" fill="url(#lit)" stroke="#7a3aa8" stroke-width="4"/>',
         '<rect x="183" y="306" width="20" height="34" rx="8" fill="url(#metal)" stroke="#5b647a" stroke-width="4"/>',
         '<path d="M184,342 l-4,12 M193,344 l0,14 M202,342 l4,12" stroke="#c46bff" stroke-width="5"/>',
         '<path d="M200,262 L200,296" stroke="#38e1ff" stroke-width="3" opacity="0.9"/>'],
        ['<rect x="80" y="134" width="138" height="58" rx="16" fill="#1a1428" stroke="#7a3aa8" stroke-width="4"/>',
         '<rect x="104" y="150" width="18" height="18" fill="#c46bff"/><rect x="170" y="150" width="18" height="18" fill="#c46bff"/>',
         '<rect x="88" y="174" width="40" height="5" fill="#38e1ff" opacity="0.8"/><rect x="150" y="142" width="56" height="4" fill="#ff4fd8" opacity="0.7"/>',
         '<rect x="44" y="150" width="20" height="30" rx="6" fill="url(#metal)" stroke="#5b647a" stroke-width="4"/>']),
    "hypeform": ("#ff4fd8",
        ['<rect x="178" y="256" width="28" height="44" rx="10" fill="url(#metal)" stroke="#5b647a" stroke-width="4"/>',
         '<circle cx="192" cy="304" r="11" fill="url(#lit)" stroke="#a82a8c" stroke-width="4"/>',
         '<rect x="182" y="306" width="22" height="34" rx="8" fill="url(#metal)" stroke="#5b647a" stroke-width="4"/>',
         '<circle cx="193" cy="352" r="18" fill="none" stroke="#ffd9f4" stroke-width="7"/>',
         '<circle cx="193" cy="352" r="18" fill="none" stroke="#ff4fd8" stroke-width="3"/>',
         '<path d="M200,262 L200,296" stroke="#38e1ff" stroke-width="3" opacity="0.9"/>'],
        ['<path d="M86,160 C86,138 118,136 122,156 C126,136 156,138 152,162 C150,180 122,192 118,196 C112,190 86,178 86,160 Z" fill="url(#lit)" stroke="#a82a8c" stroke-width="4"/>',
         '<path d="M148,160 C148,138 180,136 184,156 C188,136 218,138 214,162 C212,180 184,192 180,196 C174,190 148,178 148,160 Z" fill="url(#lit)" stroke="#a82a8c" stroke-width="4"/>',
         '<path d="M146,158 L154,158" stroke="#a82a8c" stroke-width="5"/>',
         '<path d="M98,150 L110,146" stroke="#ffffff" stroke-width="4" opacity="0.8"/>']),
    "steady_unit": ("#9cff6b",
        ['<rect x="176" y="256" width="32" height="46" rx="14" fill="url(#metal)" stroke="#5b647a" stroke-width="4"/>',
         '<circle cx="192" cy="306" r="14" fill="url(#lit)" stroke="#4f8a2f" stroke-width="4"/>',
         '<rect x="180" y="310" width="26" height="32" rx="12" fill="url(#metal)" stroke="#5b647a" stroke-width="4"/>',
         '<circle cx="193" cy="350" r="15" fill="url(#metal)" stroke="#5b647a" stroke-width="4"/>',
         '<path d="M202,262 L202,296" stroke="#38e1ff" stroke-width="3" opacity="0.9"/>'],
        ['<circle cx="178" cy="164" r="28" fill="url(#lit)" stroke="#4f8a2f" stroke-width="5" opacity="0.55"/>',
         '<circle cx="178" cy="164" r="28" fill="none" stroke="#5b647a" stroke-width="6"/>',
         '<path d="M206,160 L226,140" stroke="#5b647a" stroke-width="5"/>',
         '<path d="M226,140 L226,104" stroke="#8d96ab" stroke-width="4"/><circle cx="226" cy="100" r="7" fill="#9cff6b"/>',
         '<rect x="44" y="150" width="20" height="30" rx="6" fill="url(#metal)" stroke="#5b647a" stroke-width="4"/>']),
    "xeno": ("#3dffd0",
        ['<path d="M188,256 Q206,276 192,300 Q178,322 196,342" fill="none" stroke="#5b647a" stroke-width="26"/>',
         '<path d="M188,256 Q206,276 192,300 Q178,322 196,342" fill="none" stroke="url(#metal)" stroke-width="18"/>',
         '<circle cx="196" cy="270" r="6" fill="#3dffd0"/><circle cx="188" cy="306" r="6" fill="#3dffd0"/><circle cx="190" cy="334" r="6" fill="#3dffd0"/>',
         '<path d="M196,344 l-8,16 M196,346 l2,18 M198,344 l10,14" stroke="#5b647a" stroke-width="6"/>'],
        ['<path d="M62,120 Q130,92 210,118 L204,132 Q130,108 68,134 Z" fill="url(#metal)" stroke="#5b647a" stroke-width="4"/>',
         '<path d="M130,108 L118,74 L130,60 L142,74 Z" fill="url(#lit)" stroke="#1d8f78" stroke-width="4"/>',
         '<path d="M96,118 L88,96 L100,92 Z M164,116 L172,94 L160,90 Z" fill="url(#lit)" stroke="#1d8f78" stroke-width="3"/>']),
}


# --- MegaBean staff: corporate charcoal, coffee brown and red ties --------------
BEAN = ('<ellipse cx="%d" cy="%d" rx="9" ry="12" fill="#6b4a2f" stroke="#f1e4cc" stroke-width="3" transform="rotate(25 %d %d)"/>'
        '<path d="M%d,%d q4,8 0,16" fill="none" stroke="#f1e4cc" stroke-width="2"/>')


def bean(x, y):
    return BEAN % (x, y, x, y, x - 1, y - 8)


STAFF = {
    "fighter": {  # security
        "skin": "#e8b48f", "top": "#2b2d3a", "bottom": "#23263a",
        "torso_details": ['<path d="M108,246 L128,292 L150,246 Q128,238 108,246 Z" fill="#f4f6fb" stroke="#b9c0d6" stroke-width="3"/>',
                          '<path d="M123,262 L134,262 L139,312 L128,326 L118,312 Z" fill="#e3485a" stroke="#9c2434" stroke-width="3"/>',
                          bean(164, 282)],
        "hair": ['<path d="M40,150 C34,92 86,56 136,56 C192,58 228,92 222,146 C206,120 166,108 126,110 C96,112 70,126 60,152 Z" fill="#2a1b15" stroke="#16100c" stroke-width="4"/>',
                 '<path d="M40,124 C40,64 92,40 134,40 C186,40 226,66 226,122 Z" fill="#6b4a2f" stroke="#3e2a1c" stroke-width="4"/>',
                 '<path d="M150,118 Q210,112 250,128 Q212,140 150,132 Z" fill="#5a3b26" stroke="#3e2a1c" stroke-width="4"/>',
                 bean(132, 80)],
        "prop": ['<path d="M200,334 L222,276" stroke="#2a2e3f" stroke-width="12"/>',
                 '<path d="M219,284 L226,264" stroke="#e3485a" stroke-width="12"/>',
                 '<circle cx="227" cy="262" r="7" fill="#ffd36b" opacity="0.9"/>'],
    },
    "tank": {  # bouncer with a riot shield
        "skin": "#a8714a", "top": "#3e2a22", "bottom": "#23263a", "wide": 16,
        "torso_details": ['<path d="M112,246 L128,272 L144,246 Q128,240 112,246 Z" fill="#2b2d3a"/>',
                          '<path d="M86,300 L172,300" stroke="#6b4a2f" stroke-width="10"/>', bean(128, 300)],
        "hair": ['<path d="M48,130 C52,84 96,64 134,64 C178,64 214,86 216,128 C196,112 164,104 132,104 C100,104 72,112 48,130 Z" fill="#1c1410" stroke="#0e0a08" stroke-width="4"/>',
                 '<rect x="88" y="146" width="126" height="34" rx="12" fill="#16141f" stroke="#0a0910" stroke-width="4"/>',
                 '<path d="M100,154 L140,154" stroke="#5a6a9a" stroke-width="5" opacity="0.8"/>',
                 '<path d="M54,170 Q46,200 70,214" fill="none" stroke="#2a2e3f" stroke-width="4"/>',
                 '<rect x="46" y="158" width="14" height="20" rx="5" fill="#2a2e3f"/>'],
        "prop": ['<rect x="166" y="244" width="74" height="132" rx="16" fill="url(#shield)" stroke="#2a2e3f" stroke-width="5"/>',
                 '<rect x="176" y="256" width="54" height="40" rx="6" fill="#9feaff" opacity="0.4"/>',
                 bean(203, 330).replace('rx="9" ry="12"', 'rx="16" ry="21"')],
        "prop_defs": [grad("shield", "#5a6a8a", 0.25, -0.25)],
    },
    "ranged": {  # barista with an espresso blaster
        "skin": "#f2c9a8", "top": "#f1e4cc", "bottom": "#2b2d3a", "sleeve": "#f1e4cc",
        "torso_details": ['<path d="M88,262 L168,262 L176,350 Q128,362 80,350 Z" fill="#6b4a2f" stroke="#3e2a1c" stroke-width="4"/>',
                          '<path d="M100,262 Q128,236 156,262" fill="none" stroke="#6b4a2f" stroke-width="6"/>',
                          '<path d="M110,306 L146,306 L144,330 L112,330 Z" fill="#5a3b26" stroke="#3e2a1c" stroke-width="3"/>',
                          bean(128, 286)],
        "hair": ['<path d="M42,160 C34,92 88,58 138,58 C194,60 230,96 222,150 C204,124 164,110 124,112 C96,114 72,128 62,160 Z" fill="#7a4a2a" stroke="#3e2410" stroke-width="4"/>',
                 '<path d="M44,124 Q134,96 222,120 L222,136 Q134,110 44,140 Z" fill="#6b4a2f" stroke="#3e2a1c" stroke-width="4"/>',
                 '<path d="M150,128 Q212,124 248,140 Q210,150 150,142 Z" fill="#5a3b26" stroke="#3e2a1c" stroke-width="4"/>'],
        "prop": ['<rect x="178" y="322" width="54" height="30" rx="8" fill="#2b2d3a" stroke="#16141f" stroke-width="4"/>',
                 '<path d="M224,326 L246,318 L246,340 L224,346 Z" fill="#6b4a2f" stroke="#3e2a1c" stroke-width="4"/>',
                 '<rect x="186" y="350" width="14" height="22" rx="4" fill="#2b2d3a"/>',
                 '<circle cx="200" cy="337" r="6" fill="#ff8a3d"/>'],
    },
    "fragile": {  # intern
        "skin": "#ffe0c7", "top": "#f4f6fb", "bottom": "#3a3f5c",
        "torso_details": ['<path d="M108,246 Q128,262 150,246" fill="none" stroke="#c9cfdc" stroke-width="4"/>',
                          '<path d="M104,250 L124,312 M154,250 L134,312" stroke="#e3485a" stroke-width="5"/>',
                          '<rect x="114" y="308" width="30" height="36" rx="4" fill="#ffffff" stroke="#8d96ab" stroke-width="3"/>',
                          '<rect x="120" y="314" width="18" height="10" fill="#6b4a2f"/><path d="M120,332 l18,0" stroke="#8d96ab" stroke-width="3"/>'],
        "hair": ['<path d="M36,166 C22,90 84,44 140,48 C202,52 240,100 222,160 C214,130 196,116 180,122 C186,104 168,96 158,110 C150,94 128,98 124,112 C98,110 72,126 62,166 Z" fill="#e0a85a" stroke="#9a6a2a" stroke-width="4"/>',
                 '<path d="M126,50 Q120,30 136,24 M150,52 Q160,30 176,34" fill="none" stroke="#9a6a2a" stroke-width="5"/>'],
        "prop": ['<rect x="176" y="300" width="50" height="64" rx="5" fill="#b07a50" stroke="#6b4130" stroke-width="4"/>',
                 '<rect x="184" y="312" width="34" height="46" fill="#ffffff"/>',
                 '<rect x="192" y="294" width="18" height="12" rx="3" fill="#8d96ab" stroke="#5b647a" stroke-width="2"/>',
                 '<path d="M190,324 l22,0 M190,334 l22,0 M190,344 l14,0" stroke="#8d96ab" stroke-width="3"/>'],
    },
}


if __name__ == "__main__":
    for type_id, look in CUSTOMERS.items():
        customer(type_id, look)
    for class_id, look in STAFF.items():
        customer(class_id, look, "megabean/" + class_id)
    for species_id, (color, arm, visor) in SYNTHS.items():
        synth(species_id, color, arm, visor)
    print("characters written to", ROOT)
