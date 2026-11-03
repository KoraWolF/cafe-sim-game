# Art guide: customers, Synths and furniture (2D vector, digital illustration)

How to make the characters and furniture for NanoBrew Café yourself and plug them into the game. Everything on screen today is placeholder shapes drawn in code (`src/ui/cafe_view.gd`, `src/ui/battle_view.gd`). Real art replaces them without changing any game rules.

**Style (decided 2026-10-27): 2D vector shapes with a digital-illustration finish.** Clean, scalable shapes, soft gradients, cel-shadow shapes and a neon rim light, instead of hand-painted pixels or black comic outlines.

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

These are the rules the template follows. Change them once here if you want a different look, then keep every drawing consistent with them.

1. **Shapes:** round, soft chibi shapes. Big head, small body, stubby limbs, rounded corners everywhere (round line joins).
2. **Outlines:** no pure black. Each shape is outlined in a **darker shade of its own colour**, 4 px on the 4× canvas (skin → `#c98a68`, jacket → `#1e2852`).
3. **Shading:** one **soft gradient** per material (light from the top-left), plus **one cel-shadow shape**, a flat darker shape at about 35–45% opacity under the arm or on the far cheek.
4. **Neon rim light:** a thin cyan stroke (`#38e1ff`, about 70% opacity) on the right edge of the head and body: the neon city outside. Synths also get a soft glow in their species colour behind them.
5. **Faces:** big dark eyes with one white highlight, a small mouth and soft blush. Faces are separate layers (`face_neutral`, `face_happy`, `face_angry`), so expressions just swap.
6. **Silhouettes tell customers apart:**
   - office worker: briefcase, neat hair block
   - gym fan: wide shoulders, tank top
   - gamer: hoodie, headset
   - influencer: big hair, phone
   - grandparent: cardigan, cane
   - alien tourist: antennae, camera
7. **Synths keep the human silhouette plus tech:** visor, robot arm, cable hair or a screen face, plus one glow colour per species:
   - Clerkbot `#4fb3ff`
   - Bulkform `#ff8a3d`
   - Glitchling `#c46bff`
   - Hypeform `#ff4fd8`
   - Steady-unit `#9cff6b`
   - Xeno `#3dffd0`
8. **Palette roles:** a warm café interior (browns, cream, soft orange), cool neon accents (cyan, magenta), and MegaBean corporate (charcoal, coffee brown, red ties).
9. **Check at game size:** the template's 1× preview is 64 × 110 px. If a detail vanishes at that size, simplify it.

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
- `floor_a` / `floor_b`: wood-plank tiles, alternating;
- `wall_plain`, `wall_window`, `wall_shelf`: one tile-wide segment of the back-left wall. The back-right wall is the same drawings mirrored, with a window every third segment and a shelf now and then;
- `door`: a glass door with a striped awning.

**How they're made.** They come from `tools/art/furniture_svg.py`. It draws every piece from the same iso parts (boxes, cylinders, discs, floor shadows), so the style rules above hold everywhere.
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

**Characters (v1.7): the rig is in, with all six customer types and their Synths.**

*The cast.* `python tools/art/characters_svg.py` draws the other five on the template's body shapes, each with its own clothes, hair, skin, prop and tech:

| Customer | Look | Prop | Synth | Tech |
| --- | --- | --- | --- | --- |
| gym_fan | tank top, bare arms, headband, shorts | water bottle | bulkform | piston arm, eye band, jaw guard |
| gamer | hoodie, headset | handheld console | glitchling | pixel-screen visor, cable arm |
| influencer | big hair, cropped jacket, shades on the head | phone | hypeform | heart LED shades, ring-light arm |
| grandparent | cardigan, bun, glasses | cane | steady_unit | monocle scanner, sturdy arm |
| alien_tourist | antennae, lavender skin, flower shirt, camera strap | camera | xeno | crystal tiara, segmented arm |

*MegaBean staff* are in `art/characters/megabean/<combat class>/`, made by the same script in the corporate palette (charcoal, coffee brown, red ties, the bean logo). Guards, raiders and auditors all use them by combat class:

| Class | Look | Weapon |
| --- | --- | --- |
| fighter | security: charcoal suit, red tie, brown bean cap | stun baton |
| tank | bouncer: wide brown uniform, sunglasses, earpiece | riot shield |
| ranged | barista: cream shirt, brown apron, visor | espresso blaster |
| fragile | intern: white shirt, red lanyard, ID badge | clipboard |

*Parts.* `python tools/art/character_parts.py` splits the template into one SVG per part, all on the same 256 × 440 canvas:
- `art/characters/customers/office_worker/`: shadow, leg_back, arm_back, leg_front, torso, arm_front, prop, head, hair, and faces `face_neutral`, `face_happy`, `face_angry`, `face_eat`, `face_rest`;
- `art/characters/synths/clerkbot/`: glow, arm_front (replaces the customer's), visor.

*How a Synth is built.* A Synth is its customer type's body plus its species' parts. The Clerkbot is the office worker with a visor, a robot arm and a glow, and no briefcase.

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

*Still to come:*
- the back view (NE), for walking away;
- outfits drawn on the rig (hats are still drawn as shapes above the head).
