# Art guide: customers, Synths and furniture (2D vector, digital illustration)

How to make the characters and furniture for NanoBrew Bar yourself and plug them into the game. Everything on screen today is placeholder shapes drawn in code (`src/ui/cafe_view.gd`, `src/ui/battle_view.gd`). Real art replaces them without changing any game rules.

**Style (decided 2026-10-27): 2D vector shapes with a digital-illustration finish.** Clean, scalable shapes, soft gradients, cel-shadow shapes and a neon rim light, instead of hand-painted pixels or black comic outlines. **Theme (2026-11-03): a cyberpunk dive bar with chibi cyborgs** (see section 4).

![Template: the office worker (customer) and the Clerkbot (Synth) from one file](images/chibi_template_preview.png)

**Start from the template:** `art/templates/chibi_office_worker_se.svg`. It's an office worker, with the Clerkbot Synth parts as hidden layers. Open it in Inkscape and every part is its own layer.

## 1. How vector art works in Godot

You draw in a vector program (shapes and curves, not pixels), so the art can be any size without getting blurry. Godot **imports each SVG file as an image at a size you choose**. Set the import "Scale" to 2 or 4 and it renders crisp at that resolution. In the game it's then an ordinary sprite.

To animate, the character is split into **parts**: head, hair, face, torso, arms, legs, props. Each part is its own SVG (or a layer exported from one SVG). In Godot the parts hang on a `Skeleton2D` with `Bone2D` nodes, and an `AnimationPlayer` moves the bones. This "cut-out" animation is built into Godot and free.

Why parts:
- **One rig for everyone.** All customer types and Synth species share one chibi skeleton. A new character is a new set of part drawings, not new animations.
- **Outfits are cheap.** Synth fashion (your outfit progression) swaps one part, such as the visor, the jacket or the arm mod.
- **Customer to Synth is mostly adding parts.** The template shows it: the Clerkbot is the office worker plus a visor, an ear module, a robot arm (replacing the hand with the briefcase) and a glow.

## 2. Tools

| Tool | Cost | Notes |
| --- | --- | --- |
| **Inkscape** | free | Recommended to start. Opens the template with all layers. **File → Export** can export each layer as its own SVG or PNG |
| Affinity Designer 2 | one-time, about $70 | Very nice vector tool; export each layer with the Export persona |
| Adobe Illustrator | subscription | Industry standard; Asset Export panel for parts |
| Figma | free tier | Works well for flat vector; export each frame or group |

Animation stays in Godot (`Skeleton2D` + `AnimationPlayer`). You don't need Spine for this style.

## 3. Size, view and pivot

| Item | Value |
| --- | --- |
| Camera | Isometric 3/4 view (2:1 diamond grid) |
| Floor tile | 96 × 48 px in the game world |
| Character in game | about 64 × 110 px at 1× zoom (chibi, head about 45% of the height) |
| **Drawing canvas** | **256 × 440** (4× the game size), like the template |
| **Pivot** | between the feet, at **(128, 430)** on the canvas. The hidden "guides" layer in the template marks it |
| Directions | Draw **2**: down-right (SE, the template) and up-right (NE, the back view). The game mirrors them for the other two |
| Battle | Side view facing right: idle, attack, hit, knocked out |

Every part of one character uses **the same 256 × 440 canvas and the same pivot**, even a small part like an eye. Then the parts line up automatically when assembled.

## 4. The style rules (your style bible)

**Theme (changed 2026-11-03): a cyberpunk dive bar with chibi cyborgs.** The vector style stays (clean shapes, gradients, tinted outlines), but the world is now a dark neon bar in the megacity and everyone wears tech. Change these rules once here, then keep every drawing consistent with them.

1. **Shapes:** chibi proportions (big head, small body, stubby limbs) with harder edges on tech: chrome plates, panel seams, cables, bolts. Rounded joins on skin and cloth, sharper corners on metal.
2. **Outlines:** no pure black. Each shape is outlined in a darker shade of its own colour, 4 px on the 4× canvas. Metal is outlined in a deep steel blue (`#2a3046`).
3. **Shading:** one gradient per material, lit from the top-left, plus one flat cel-shadow shape. Metal gets a sharp white highlight line on its lit edge.
4. **Neon:** a cyan rim light (`#19f0ff`) on the right edges, and magenta (`#ff2fb4`) neon spill underneath things (bar undersides, stool rings, floor edges).
5. **Grime:** a dive bar, not a showroom: dark stains, scratches, worn edges, sticker and graffiti marks. Keep it subtle so pieces still read at game size.
6. **Palette roles:**
   - the bar: near-black and dark plum (`#14111f`, `#1f1a2e`), gunmetal steel (`#4a5068`), chrome (`#c9d2e3`), oxblood vinyl (`#8a1f3a`);
   - the neon: magenta `#ff2fb4`, cyan `#19f0ff`, acid green `#b6ff3b`, amber `#ffb03b` (bottles and warm lights);
   - MegaBean: corporate black and red (`#16141c`, `#d62f45`), with the bean logo.
7. **Characters are chibi cyborgs.**
   - **Customers:** street style plus small implants (a cheek plate, an LED tattoo, an earpiece, a cyber eye).
   - **Synths:** heavy chrome on top of that: a visor, a mechanical arm, glowing seams, and one glow colour per species: Clerkbot `#4fb3ff`, Bulkform `#ff8a3d`, Glitchling `#c46bff`, Hypeform `#ff4fd8`, Steady-unit `#9cff6b`, Xeno `#3dffd0`.
   - **Silhouettes still tell customer types apart:**
     - office worker: corp suit, LED tie, briefcase;
     - gym fan: brawler build, tank top, energy can;
     - gamer: netrunner hoodie, headset, cyberdeck;
     - influencer: neon idol with two-tone hair and a holo phone;
     - grandparent: chrome bun, LED glasses, a cane;
     - alien tourist: antennae and a holo camera.
8. **Faces:** big dark eyes with one white highlight, a small mouth and soft blush, so the cute read stays under the tech. Faces are separate parts (`face_neutral`, `face_happy`, `face_angry`, `face_eat`, `face_rest`).
9. **Check at game size:** a character is about 97 × 60 px and a tile is 96 × 48. If a detail vanishes at that size, simplify it.

### The UI

The menus follow the same theme. Everything comes from one Theme in `src/ui/ui_theme.gd`, built from Godot style boxes, so there are no image files:
- **Panels:** near-black glass with a glowing cyan edge, sharp top-left and bottom-right corners and rounded others.
- **Buttons:** slanted (`BUTTON_SLANT`), edged in magenta; they glow cyan on hover and magenta when pressed.
- **Tabs and fields:** tabs get a neon underline, text fields a cyan underline, and scroll bars a slim neon grabber.
- **Titles:** labels of 26 px and up get a neon halo in their own colour.
- **Round buttons:** the Menu and Night buttons are glowing neon rings.
- **Main menu:** `src/ui/menu_backdrop.gd` draws a rainy skyline behind it.

Change a colour or the slant there, and every screen follows.

## 5. Making a character yourself, step by step

1. **Copy the template** (`art/templates/chibi_office_worker_se.svg`) and rename it, for example `gym_fan_se.svg`.
2. **Keep the layer names and the canvas.** Redraw inside each layer: change the hair shape, the clothes and the prop. Keep the head size and the feet position.
3. **Use the template's gradients and outline colours** as your palette, or change them in one place in the file's gradient list.
4. **Make the Synth version** in the same file: draw its tech parts (visor, arm, …) on the hidden "synth_" layers. In Inkscape, show or hide layers with the eye icon.
5. **Draw the back view (NE)** the same way: same canvas, same pivot, back of the head, no face.
6. **Export each layer as its own SVG** into the game folders below. In Inkscape: Edit → Select All in All Layers, then File → Export, choose "Batch export" and "Layers".
7. **Send it to me** (or drop it in the folder). I'll build the rig and show it in the café at real size. Fix what doesn't read, then do the next character.

## 6. Folders and names

```
art/
  templates/chibi_office_worker_se.svg   ← start here
  source/                                ← your full working files (.svg, .afdesign, .ai)
  characters/
    customers/office_worker/   head_se.svg  hair_se.svg  face_neutral_se.svg  torso_se.svg
                               arm_front_se.svg  arm_back_se.svg  leg_front_se.svg  leg_back_se.svg
                               prop_briefcase_se.svg  (… and the same with _ne)
    synths/clerkbot/           synth_visor_se.svg  synth_arm_se.svg  synth_glow_se.svg  …
  furniture/   seat.svg  stove.svg  stove_rot.svg  pod.svg  counter.svg
  decor/       potted_fern.svg  koi_tank.svg  …
```

- Names are lowercase with underscores and **match the game's ids** (`office_worker`, `clerkbot`, `potted_fern`), because the game finds art by these names.
- SVG is text, so it's stored in git normally. Exported PNGs and big source files go through Git LFS (already set up).
- Synth glow can be drawn in white and tinted in the game per species, or drawn in its colour; either works.

## 7. Animations each character needs

| Animation | Used by | Notes |
| --- | --- | --- |
| idle | everyone | gentle 1–2 s breathing loop |
| walk | everyone | 0.6 s loop (walking in through the door, servers carrying dishes) |
| sit, eat | customers | eat loops while the eating bar fills |
| happy (star) | customers | short hop |
| angry_leave | customers | stomp out |
| carry, cook, wave | server, chef, greeter | work loops |
| convert | customer → Synth | about 1 s; tech parts pop on, the game adds the burst effect |
| attack, hit, ko | battle (side view) | Synths and MegaBean staff |

You don't animate these in the drawing program. You draw the parts; the animations are made once on the shared rig in Godot.

## 8. Furniture and décor

- One SVG per piece, drawn in the same isometric view. A 1×1 piece sits on a 96 × 48 diamond (draw at 4×: a 384 × 192 diamond), a 2×1 piece on two diamonds, and so on. Make the drawing taller than the diamond for the piece's height.
- **Pivot: the top corner of its top-left tile.**
- Pieces that can rotate need a second drawing (`_rot`).
- Same rules: tinted outlines, one gradient per material, a cel shadow and a cyan rim light. Tag colours stay readable: plants green, lights warm yellow, tech cyan, cozy orange.

## 9. How it plugs into the game

**Furniture and décor are in (v1.7, 2026-11-03).** Every piece in `data/pieces.json`, plus the Sync Pod, has an SVG:

- `art/furniture/`: `seat`, `seat_far`, `seat_near`, `table`, `stove`, `counter`, `bin`, `register`, `pod`;
- `art/decor/`: every décor piece.

**The room** is in `art/room/`:
- `floor_a` / `floor_b`: dark concrete slabs with scuffs and neon reflections, alternating;
- `wall_cracked` (the starter), `wall_brick`, `wall_steel`, `wall_graffiti`, `wall_neon_panel`: one tile-wide wall panel, 3 grid cells high (`art/room/`). The back-right wall is the same drawings mirrored.
- `wall_window`, `wall_bottles`, `wall_neon_sign`, `wall_poster`, `wall_screen`, `wall_vent`: wall décor (`art/decor/`), drawn on the same canvas from the bottom cell. The game lifts each piece 24 world px per row.
- `door`: a steel frame with a half-open shutter, a glass door and a neon cocktail-glass sign.

**How they're made.** They come from `tools/art/furniture_svg.py`, drawn as a cyberpunk dive bar since 2026-11-03. It draws every piece from the same iso parts (boxes, cylinders, discs, floor shadows), so the style rules above hold everywhere.
- Run `python tools/art/furniture_svg.py` to rebuild them all. A file edited by hand is overwritten when you rebuild, so either change the script or stop using it for that piece.
- Each file has named layers (shadow, body, neon, …) for Inkscape.
- Run `godot --headless --path . -s res://tools/art/preview_sheet.gd -- sheet.png` for a contact sheet at 2× and at game size.

**Canvas rule.** The canvas is 4× the game size, so a tile is a 384 × 192 diamond. For a footprint of w × d tiles:
- the canvas is (w + d) × 192 + 32 wide;
- the top corner of the top-left tile sits at (d × 192 + 16, canvas height − (w + d) × 96 − 16).

**Rotation and seats.** A rotated piece uses the same drawing mirrored. Seats have three drawings:
- `seat`: no table;
- `seat_far`: the backrest on the far edge, used for a table down-right (mirrored: down-left);
- `seat_near`: the backrest on the near edge, used for a table up-left (mirrored: up-right).

**Import.** Each SVG's `.import` uses `svg/scale=0.5` (a 2× texture) and mipmaps, so it stays smooth when the café is zoomed out. A new SVG needs the same two settings, or it draws at the wrong size.

**In the game.** `src/ui/piece_art.gd` finds a piece's art by its id, and the café and battle views draw it in place of the placeholder block. A piece with no SVG keeps its block, so new pieces can arrive one at a time. Drawn décor shows its name only while arranging.

**Characters (v1.7, cyborg theme 2026-11-03): the rig is in, with every customer type, Synth species and MegaBean look.**

*Parts.* `python tools/art/characters_svg.py` draws them all on the template's 256 × 440 canvas, using its body shapes and joints. Each type has its own clothes, hair, skin, implants, prop and five faces:
- `art/characters/customers/<type>/`: shadow, leg_back, arm_back, leg_front, torso, arm_front, prop, head, hair, `face_neutral`, `face_happy`, `face_angry`, `face_eat`, `face_rest`;
- `art/characters/synths/<species>/`: glow, arm_front (replaces the customer's), visor.

| Customer | Look | Prop | Synth | Tech |
| --- | --- | --- | --- | --- |
| office_worker | corp drone: dark suit, LED tie, ear jack | briefcase with an LED strip | clerkbot | blue visor, chrome arm |
| gym_fan | brawler: neon tank top, LED headband, chrome jaw, cheek tattoo, shorts | energy can | bulkform | eye band, jaw guard, heavy fist |
| gamer | netrunner: LED hoodie, lightning-streak hair, headset | cyberdeck | glitchling | pixel-screen visor, head cables |
| influencer | neon idol: pink and cyan hair, holo jacket, face LEDs | holo phone | hypeform | heart LED shades, ring-light arm |
| grandparent | chrome bun, LED glasses, circuit cardigan | cane with a glowing tip | steady_unit | scanner eye, cheek plate |
| alien_tourist | lavender skin, glowing antennae, flight jacket | holo camera | xeno | crystal tiara, segmented arm |

*How a Synth is built.* A Synth is its customer type's body plus its species' parts: a mechanical arm (instead of the customer's arm and prop), a visor or other head tech, and a glow in its species colour.

*MegaBean staff* are in `art/characters/megabean/<combat class>/`: black-and-red corporate enforcers with red visor strips and the bean logo. Guards, raiders and auditors all use them by combat class:

| Class | Look | Weapon |
| --- | --- | --- |
| fighter | enforcer: black suit, red visor | shock baton |
| tank | riot cyborg: armour, helmet | heavy shield |
| ranged | gunner: red hair, eye scope, sash | caffeine rifle |
| fragile | hacker intern: lanyard, glasses | holo tablet |

*The rig.* `src/ui/character_art.gd` hangs the parts on joints (hips, neck, shoulders, hips for each leg) and poses them by time, so no animation files are needed:
- in the café: idle, walk, carry (with a tray), sit, eat, cook, rest (eyes closed), happy, angry;
- in battles: attack, cast, hurt, down.

*In the game.*
- **Café.** A character walks whenever it moves and faces the way it last went: the art faces right and is mirrored for left. Customers sit while waiting and eat with the eating face; angry customers stomp out. Synths carry trays, stir at a cooking stove, and close their eyes in the Pod.
- **Battles.** Rigged Synths use the same rig.
- **Fallback.** Any customer type, species or MegaBean class without parts keeps the old placeholder.

*Check by eye.* `tools/art/rig_sheet.gd` draws two sheets. It needs a window, not `--headless`:
- `godot --path . --resolution 1600x900 -s res://tools/art/rig_sheet.gd -- rig.png`: every animation for the office worker and the Clerkbot;
- `godot --path . --resolution 1700x1300 -s res://tools/art/rig_sheet.gd -- cast.png cast`: every customer type beside its Synth, in several poses;
- `godot --path . --resolution 1300x900 -s res://tools/art/rig_sheet.gd -- staff.png staff`: MegaBean's staff in their battle animations.

*The back view.* Every body also has `torso_ne`, `head_ne` (both ears, no face) and `hair_ne`, and every species has `visor_ne` (its strap or tiara from behind). Legs, arms and props are shared with the front.
- The rig uses the back parts and hides the face when the pose has `"back": true`.
- **Café:** a character shows its back while walking up the screen (away from the camera), and a Bartender shows it while working its mixer.
- **Battles:** a unit shows its back whenever it faces up the board.
- **Mirroring:** the art faces up-right and is mirrored for up-left, like the front.
- **Check sheet:** `godot --path . --resolution 1700x1300 -s res://tools/art/rig_sheet.gd -- back.png back` draws every body walking away.

*Hats and outfits.* Every fashion item in `data/items.json` is drawn in its own colour by the same script, in `art/characters/fashion/<id>/`:
- a hat is `hat.svg` and `hat_ne.svg`;
- an outfit is `torso.svg`, `torso_ne.svg` and, with sleeves, `arm_back.svg`. The Synth's front arm is its own mechanical arm.

The rig wears them through the pose's `hat` and `outfit`:
- the outfit goes over the body's torso and back sleeve;
- the hat goes on last, over the hair and visor.

| Item | Look |
| --- | --- |
| neon_cap (Neon Cap) | dark cap with a cyan LED band and brim |
| beanie (LED Beanie) | ribbed pink beanie with a glowing antenna |
| top_hat (Chrome Top Hat) | top hat with a chrome band and magenta neon |
| teal_jacket (Neon Bomber) | teal bomber with a zip and magenta piping |
| barista_apron (Bartender Apron) | brown apron over a dark vest |
| hoodie (Glow Hoodie) | purple hoodie with LED drawstrings |

A Synth in the bar or in a battle wears what it has on. A new fashion item needs its drawing added in `fashion_parts()`; until then it isn't drawn on the rig. `rig_sheet.gd -- fashion.png fashion` shows every Synth in each look.
