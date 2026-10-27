# Art guide: customers, Synths and furniture

How to make the characters and furniture for NanoBrew Café and plug them into the game. Everything on screen today is placeholder shapes drawn in code (`src/ui/cafe_view.gd`, `src/ui/battle_view.gd`). Real art replaces them without changing any game rules.

## 1. What kind of model

**2D cut-out sprites, rigged with bones in Godot.** This is what the GDD asks for ("layered 2D sprites animated with bones, so one rig serves many skins").

Each character is drawn as separate parts: head, hair, face, body, arms, legs and accessories. Each part is its own transparent PNG. In Godot the parts hang on a `Skeleton2D` with `Bone2D` nodes, and an `AnimationPlayer` moves the bones. This is built into Godot and free.

Why parts instead of whole-frame animation:
- **One rig, many characters.** All six customer types and all six Synth species share one chibi skeleton. A new character is a new set of part images, not new animations.
- **Skins are cheap.** Synth outfits (the "fashion progression" you asked for) swap one part's texture, such as the visor, the jacket or the arm mod. You never redraw every frame.
- **Smooth motion at any zoom.** The café camera zooms, and bone animation stays smooth where frame animation would need many frames.

Alternatives, if you prefer:
- **Spine** (paid, about $70–$350). Better rigging tools and mesh deformation, and it has a Godot runtime. Use it if you already know it.
- **Frame-by-frame sprite sheets** (Aseprite, `AnimatedSprite2D`). Simplest to learn, but every skin means redrawing every frame.

## 2. Size, view and directions

| Item | Value |
| --- | --- |
| Camera | Isometric 3/4 view, a 2:1 diamond grid |
| Floor tile | 96 × 48 px in the game world |
| Character on screen | about 64 px wide × 110 px tall at 1× zoom (a chibi is about 2.3 heads tall) |
| Draw at | **2×**: a 128 × 220 px canvas per character, so it stays sharp when zoomed in |
| Pivot (origin) | **between the feet, at the bottom centre.** The game places characters by their feet |
| Directions | Draw **2**: facing down-right (SE) and up-right (NE). The game mirrors them for down-left and up-left |
| Battle view | Side view, facing right. One extra pose set: idle, attack, hit, knocked out |

## 3. Files and folders

```
art/
  source/                      ← your working files (.kra, .psd, .clip, .spine), stored in Git LFS
  characters/
    rig/chibi_rig.tscn         ← the shared Skeleton2D rig (I can build this from your first character)
    customers/office_worker/   ← one folder per customer type
      head_se.png  head_ne.png
      hair_se.png  hair_ne.png
      face_neutral_se.png  face_happy_se.png  face_angry_se.png
      torso_se.png  torso_ne.png
      arm_front_se.png  arm_back_se.png
      leg_front_se.png  leg_back_se.png
    synths/clerkbot/           ← same parts, plus the tech parts below
      visor_se.png  robot_arm_se.png  screen_face_*.png  glow_se.png
  furniture/
    seat_1x1.png  stove_2x1.png  stove_2x1_rot.png  pod_1x2.png  counter_2x1.png
  decor/
    potted_fern.png  koi_tank.png  …
```

Rules:
- **PNG with a real transparent background** (no white or checkerboard), sRGB colour.
- **Names are lowercase with underscores** and match the game's ids: `office_worker`, `clerkbot`, `potted_fern`. The game finds art by these names.
- **Every part of a character uses the same canvas size and the same pivot point**, so the parts line up when they're assembled.
- **Glow is its own white or grey layer** (`glow_*.png`). The game tints it with the species colour (Clerkbot blue, Bulkform orange, …), so you draw it once.
- Big source files go through Git LFS. That's already set up for `.psd`, `.kra`, `.png`, `.spine` and others.

## 4. The animations each character needs

| Animation | Used by | Notes |
| --- | --- | --- |
| idle | everyone | gentle 1–2 s breathing loop |
| walk | everyone | 0.6 s loop (entering through the door, servers carrying dishes) |
| sit, eat | customers | eat loops while the eating bar fills |
| happy (star) | customers | short hop when they get a star |
| angry_leave | customers | stomp out |
| carry | servers | walk with a tray |
| cook | chefs | stirring loop at a stove |
| wave | greeters | loop by the door |
| convert | customer → Synth | about 1 s transformation; the game adds the burst effect |
| attack, hit, ko | Synths and MegaBean staff (battle) | side view |

## 5. Furniture and décor

- One image per piece, drawn in the same isometric view. A 1×1 piece sits on a 96 × 48 diamond, a 2×1 piece on two diamonds, and so on. Make the image taller than the diamond for the piece's height.
- **Pivot: the top corner of its top-left tile.**
- Pieces that can be rotated need a second image (`_rot`) for the turned version.
- Keep the tags readable at a glance: plants green, lights warm yellow, tech cyan, cozy warm orange. The game's colour coding already uses these.

## 6. Making your own style (a one-page style bible)

Write these down once and check every new drawing against them:

1. **Shape language:** round, soft chibi shapes. Big head (about 45% of the height), tiny body, stubby hands. Customers are told apart by **silhouette**: office worker has a briefcase and a neat hair block, gym fan wide shoulders, gamer a hoodie and headset, influencer big hair and a phone, grandparent a cane and a cardigan, alien tourist antennae and a camera.
2. **Synths keep the human silhouette plus tech:** a glowing visor, a robot arm, cable "hair" or a screen face showing emotes. One signature glow colour per species (the colours in `src/ui/ui_theme.gd` → `SPECIES_GLOW`).
3. **Line and colour:** a bold dark outline (about 3 px at 2×, colour `#1a1428`), flat fill colours, **one** shadow tone per colour, light from the top-left.
4. **Palette roles:** warm café interior (browns, cream, soft orange), cool neon city accents (cyan `#38e1ff`, magenta `#ff4fd8`), MegaBean corporate (charcoal, coffee brown, red ties).
5. **Detail density:** if a detail disappears at 110 px tall, cut it.

**Workflow that keeps the style consistent:**
1. Draw **one hero character** first: the office worker and its Clerkbot version.
2. Send me the parts. I'll build the rig and show it in the café at real size next to the placeholder shapes.
3. Fix whatever doesn't read in-game (outline too thin, face too small, …).
4. Only then draw the rest as a family, reusing the hero's proportions, outline, palette and light direction.

Tools: **Krita** (free) or Clip Studio or Photoshop for drawing; Aseprite if you go pixel art. If you want AI-generated drafts for concepts, I can help write prompts. Treat the results as drafts to redraw cleanly: generated images often have fake transparency, drifting proportions and inconsistent outlines.

## 7. Hooking it into the game

When the first character's files exist, I'll add a sprite layer to the café and battle views. For each customer type or Synth species, if `art/characters/.../<id>/` exists the game uses the rigged sprite, otherwise the current placeholder. So art can arrive one character at a time, and nothing breaks while it's incomplete. Furniture and décor work the same way, from `art/furniture/` and `art/decor/`.
