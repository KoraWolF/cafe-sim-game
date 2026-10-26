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
3. **`ui-battle-playback` (built 2026-10-27):** the animated battle scene, played from `Battle.Report.hits`.
4. **`ui-polish`:** feedback effects (tip pop-ups, conversion burst, level-up), tooltips, settings menu (resolution, volume, language) and audio buses.

Branch 4 decisions (2026-10-27):
- **Audio style:** lo-fi synthwave.
  - Music: chill lo-fi beats with soft synth pads during shifts, a moodier neon synthwave track at night, and punchy, slightly chiptune stings in battles.
  - Sound effects: soft UI blips, coffee pours, a cash "ka-ching" and a glitchy power-up for conversions.
- **Audio source for now:** audio buses (Master, Music, SFX, UI) and an event hook for every moment (tip, conversion, hit, level-up, …), with simple placeholder tones generated in code. Real files are swapped in later by name, with no code changes.
- **Settings menu:** volume sliders for Master, Music, SFX and UI, saved between sessions.
- **Tutorial:** a guided first day.
  - Short step-by-step tips that wait for the player to do each thing: cook a dish, watch a delivery, convert a starred customer, set the menu, plan a raid, end the night.
  - It can be skipped, and replayed from the settings menu.
- **Feedback effects (from the plan):** tip pop-ups, a conversion burst, level-up flashes and tooltips.

## Running it

- Play: open the project in Godot 4.7 and press Play, or run `godot --path .`. Shortcuts: Space pauses or resumes, 1/2/3 set the speed, Esc opens the pause menu (save to a slot, main menu).
- Floor editing (night): press Arrange Floor in the night hub. Click a piece to pick it up and click again to drop it, or take one from Storage in the side panel. The ghost turns green or red, shows the Vibe change, and outlines the pieces it would combine with. R rotates, right-click puts the piece back, Esc leaves. The panel has Rotate, Put back, Store and Sell (décor only, 50% back). The rules are the game's own (`FloorEditor` goes through `GameLoop`), so a busy stove or a Pod a Synth needs stays put.
- Battles (after End Night): your raid, then any MegaBean raid or Corporate Audit, play as short scenes before the night report. Your side is on the left. Each recorded hit is a lunge with a damage number, health bars drain, and knocked-out fighters fall. The scene ends with a Victory or Defeat banner. Skip jumps to the end, 2× doubles the speed, and Continue moves on. `BattlePlayback` replays from full HP and is tested to end exactly at the recorded result.
- Shift: click a stove to cook, click a starred customer to convert them (needs a NanoBrew and a free Pod), click a Synth for its card and role. Wheel zooms; right-drag or middle-drag pans (a left drag on empty floor pans too).
- Screenshot check: `godot --path . --resolution 1920x1080 -s res://tools/ui_snapshot.gd -- <folder>` plays a scripted day and saves a screenshot of every screen. It also sends real clicks and mouse moves (a Synth, a stove, a starred customer, then picking up, moving and dropping décor, pressing Done, and clicking Skip and Continue through a raid and an Audit), and prints `CHECK` lines with the results. The game clock is paused in the tool, so only the script advances time; with the clock running, one of four early runs failed.

## Notes for the next branches

- Theme: `UiTheme.shared()` must be set on every top-level Control. A theme set on the Window doesn't reach Controls under a plain Node or a CanvasLayer.
- Tools run with `-s` compile before autoloads exist. Don't name UI classes that use `Session` in a tool script's types; keep those references untyped.
- Clicks use the event's own position, not the cursor's, so injected input works. The tool sends each click's press and release in the same frame: real mouse moves from the OS cursor landing between them turned some clicks into drags and failed about 1 run in 4. Moving the real cursor to the target first made it worse. Popups are embedded, so they're positioned in game-window coordinates.
- Not checked through the UI: loading a save from the main menu, and saving from the pause menu. `SaveSystem` itself is covered by the headless tests.
