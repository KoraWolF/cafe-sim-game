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

1. **`ui-playable-loop` (built 2026-10-27):**
   - main menu (new game, continue, load slot)
   - café view (isometric floor, furniture, customers, Synths, icons above heads)
   - shift HUD with stove, star and Synth clicks
   - night hub (summary, Menu, Upgrades and a décor shop list, Staff, Night Ops)
   - battle result screen
   - autosave and save slots

   Playable from start to finish.
2. **`ui-floor-editing` (built 2026-10-27):** an edit mode at night on the café view. Drag pieces from storage, move, rotate, pick up and sell, with a footprint preview and a live Vibe and adjacency preview.
3. **`ui-battle-playback`:** the animated battle scene, played from `Battle.Report.hits`.
4. **`ui-polish`:** feedback effects (tip pop-ups, conversion burst, level-up), tooltips, settings menu (resolution, volume, language) and audio buses.

Not decided yet (I'll ask before branch 4): music and SFX style, the settings menu contents, and whether there's a tutorial or first-day guidance.

## Running it

- Play: open the project in Godot 4.7 and press Play, or run `godot --path .`. Shortcuts: Space pauses or resumes, 1/2/3 set the speed, Esc opens the pause menu (save to a slot, main menu).
- Floor editing (night): press Arrange Floor in the night hub. Click a piece to pick it up and click again to drop it, or take one from Storage in the side panel. The ghost turns green or red, shows the Vibe change, and outlines the pieces it would combine with. R rotates, right-click puts the piece back, Esc leaves. The panel has Rotate, Put back, Store and Sell (décor only, 50% back). The rules are the game's own (`FloorEditor` goes through `GameLoop`), so a busy stove or a Pod a Synth needs stays put.
- Shift: click a stove to cook, click a starred customer to convert them (needs a NanoBrew and a free Pod), click a Synth for its card and role. Wheel zooms; right-drag or middle-drag pans (a left drag on empty floor pans too).
- Screenshot check: `godot --path . --resolution 1920x1080 -s res://tools/ui_snapshot.gd -- <folder>` plays a scripted day and saves a screenshot of every screen. It also sends real clicks and mouse moves (a Synth, a stove, a starred customer, then picking up, moving and dropping décor and pressing Done), and prints `CHECK` lines with the results. The game clock is paused in the tool, so only the script advances time; with the clock running, one of four early runs failed.

## Notes for the next branches

- Theme: `UiTheme.shared()` must be set on every top-level Control. A theme set on the Window doesn't reach Controls under a plain Node or a CanvasLayer.
- Tools run with `-s` compile before autoloads exist. Don't name UI classes that use `Session` in a tool script's types; keep those references untyped.
- Clicks use the event's own position, not the cursor's, so injected input works. Popups are embedded, so they're positioned in game-window coordinates.
- Not checked through the UI: loading a save from the main menu, and saving from the pause menu. `SaveSystem` itself is covered by the headless tests.
