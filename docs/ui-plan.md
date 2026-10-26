# UI plan (agreed 2026-10-26)

## Decisions

- **Art:** placeholder art first. Shapes, flat-colour tiles and icon sprites at the final sizes and layer order, so real art can be swapped in without code changes.
- **Platform:** PC, mouse and keyboard first. 1920×1080 base resolution, scaling with `canvas_items` / `expand` (already set in `project.godot`).
- **Shift:** click things in the café, Zombie Cafe style:
  - Clicking a stove opens a recipe picker.
  - Clicking a starred customer converts them.
  - Clicking a Synth shows its card (level, XP, battery, trait) and lets you change its role.
  - The HUD shows coins, NanoBrew, Nano Cores, Power, day, shift timer, speed buttons (pause, 1×, 2×, 4×), Suspicion and Influence.
- **Night:** a hub with tabs. When the shift ends a summary appears first, then the tabs: Menu, Upgrades & Décor, Staff and Night Ops (targets, squad, defense chance, Audit warning), and finally "End night".
- **Battles:** a short animated scene (10–20 s) played from the recorded hits, with Skip and 2× buttons. The first branch shows only a result screen.
- **Camera:** the whole floor fits the screen by default. Mouse-wheel zoom and drag-to-pan, because the floor grows to 14 rows.
- **Language:** English, with every string going through Godot translation keys from day one so more languages can be added without code changes.
- **Scope:** the playable loop first, then follow-up branches.

## How the UI talks to the game

The UI never changes `GameState` directly. It calls `GameLoop` actions, shows the error codes they return as friendly messages, and reacts to the returned `Shift.Events` and `NightOps.Report`. The logic has no positions for customers or Synths, so the UI handles all movement:
- It gives each seated customer one of the placed seats, in a stable order.
- It moves a server from the counter to the table using `task_remaining`.

The logic stays headless-tested. UI-only helpers, such as the error message table and the seat assignment, get their own tests.

## Branches

1. **`ui-playable-loop`:**
   - main menu (new game, continue, load slot)
   - café view (isometric floor, furniture, customers, Synths, icons above heads)
   - shift HUD with stove, star and Synth clicks
   - night hub (summary, Menu, Upgrades and a décor shop list, Staff, Night Ops)
   - battle result screen
   - autosave and save slots

   Playable from start to finish.
2. **`ui-floor-editing`:** an edit mode at night on the café view. Drag pieces from storage, move, rotate, pick up and sell, with a footprint preview and a live Vibe and adjacency preview.
3. **`ui-battle-playback`:** the animated battle scene, played from `Battle.Report.hits`.
4. **`ui-polish`:** feedback effects (tip pop-ups, conversion burst, level-up), tooltips, settings menu (resolution, volume, language) and audio buses.

Not decided yet (I'll ask before branch 4): music and SFX style, the settings menu contents, and whether there's a tutorial or first-day guidance.
