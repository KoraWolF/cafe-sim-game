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

When the first character's parts exist, I'll add a sprite layer to the café and battle views. For each customer type or Synth species, if its folder exists the game uses the rigged parts, otherwise the current placeholder. So art can arrive one character at a time, and nothing breaks while it's incomplete. Furniture and décor work the same way.
