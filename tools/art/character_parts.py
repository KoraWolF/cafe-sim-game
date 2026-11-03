"""Splits the chibi template into rig parts, one SVG per part.

Run:  python tools/art/character_parts.py
Reads art/templates/chibi_office_worker_se.svg and writes
  art/characters/customers/office_worker/<part>.svg   (the customer's body)
  art/characters/synths/clerkbot/<part>.svg           (the Synth's tech parts)

Every part keeps the template's 256 x 440 canvas, so the parts line up on the
rig (src/ui/character_art.gd) with no offsets. The faces besides the
template's neutral one are drawn here: happy, angry, eat (chewing) and rest
(eyes closed).
"""
import os
import re

HERE = os.path.dirname(__file__)
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "art"))
TEMPLATE = os.path.join(ROOT, "templates", "chibi_office_worker_se.svg")

# Template layer id -> (folder, part name).
PARTS = {
    "shadow": ("customers/office_worker", "shadow"),
    "leg_back": ("customers/office_worker", "leg_back"),
    "arm_back": ("customers/office_worker", "arm_back"),
    "leg_front": ("customers/office_worker", "leg_front"),
    "torso": ("customers/office_worker", "torso"),
    "arm_front": ("customers/office_worker", "arm_front"),
    "prop_briefcase": ("customers/office_worker", "prop"),
    "head": ("customers/office_worker", "head"),
    "face": ("customers/office_worker", "face_neutral"),
    "hair": ("customers/office_worker", "hair"),
    "synth_glow": ("synths/clerkbot", "glow"),
    "synth_arm": ("synths/clerkbot", "arm_front"),
    "synth_visor": ("synths/clerkbot", "visor"),
}

BLUSH = ('<ellipse cx="100" cy="196" rx="13" ry="7" fill="#ff8fa3" opacity="0.55"/>'
         '<ellipse cx="196" cy="194" rx="14" ry="7" fill="#ff8fa3" opacity="0.55"/>')
EYES = ('<ellipse cx="118" cy="166" rx="12" ry="18" fill="#2b2238"/><ellipse cx="176" cy="164" rx="14" ry="19" fill="#2b2238"/>'
        '<circle cx="122" cy="158" r="5" fill="#fff"/><circle cx="181" cy="156" r="5.5" fill="#fff"/>')
FACES = {
    "face_happy": BLUSH.replace('opacity="0.55"', 'opacity="0.8"')
    + '<path d="M106,170 Q118,150 130,170 M162,168 Q176,148 190,168" fill="none" stroke="#2b2238" stroke-width="7" stroke-linecap="round"/>'
    + '<path d="M134,198 Q151,226 170,197 Z" fill="#7a3b3b" stroke="#7a3b3b" stroke-width="4" stroke-linejoin="round"/>'
    + '<path d="M142,206 Q151,214 162,205" fill="#ff8fa3"/>',
    "face_angry": BLUSH.replace("#ff8fa3", "#ff5a6a") + EYES.replace('ry="18"', 'ry="14"').replace('ry="19"', 'ry="15"')
    + '<path d="M102,140 L134,152 M194,138 L162,150" stroke="#3e2a22" stroke-width="7" stroke-linecap="round"/>'
    + '<path d="M138,214 Q151,202 164,214" fill="none" stroke="#7a3b3b" stroke-width="5" stroke-linecap="round"/>',
    "face_eat": BLUSH + EYES + '<ellipse cx="151" cy="208" rx="10" ry="8" fill="#7a3b3b" stroke="#5a2a2a" stroke-width="3"/>',
    "face_rest": BLUSH.replace('opacity="0.55"', 'opacity="0.35"')
    + '<path d="M106,166 Q118,178 130,166 M164,164 Q176,176 188,164" fill="none" stroke="#2b2238" stroke-width="6" stroke-linecap="round"/>'
    + '<path d="M144,206 Q151,210 158,206" fill="none" stroke="#7a3b3b" stroke-width="4" stroke-linecap="round"/>',
}


def main():
    text = open(TEMPLATE, encoding="utf-8").read()
    head = text[:text.index("<defs>")]
    head = head[head.index("<svg"):]
    defs = text[text.index("<defs>"):text.index("</defs>") + len("</defs>")]
    layers = {}
    for match in re.finditer(r'<g inkscape:groupmode="layer"[^>]*\bid="([^"]+)"[^>]*>(.*?)\n  </g>', text, re.S):
        layers[match.group(1)] = match.group(2)

    def write(folder, name, body):
        path = os.path.join(ROOT, "characters", folder)
        os.makedirs(path, exist_ok=True)
        svg = ('<?xml version="1.0" encoding="UTF-8"?>\n<!-- NanoBrew Café rig part: %s/%s. Made by tools/art/character_parts.py '
               'from art/templates/chibi_office_worker_se.svg (canvas 256 x 440, feet at 128, 430). -->\n%s\n  %s\n'
               '  <g inkscape:label="%s" stroke-linejoin="round">%s\n  </g>\n</svg>\n' % (folder, name, head.rstrip(), defs, name, body))
        with open(os.path.join(path, name + ".svg"), "w", encoding="utf-8", newline="\n") as f:
            f.write(svg)

    for layer_id, (folder, name) in PARTS.items():
        write(folder, name, layers[layer_id])
    for name, body in FACES.items():
        write("customers/office_worker", name, "\n    " + body)
    print("parts written to", os.path.join(ROOT, "characters"))


if __name__ == "__main__":
    main()
