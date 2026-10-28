# Exporting a standalone build (Windows)

A standalone build is one `NanoBrewCafe.exe` that runs without Godot. Send it to a friend to playtest.

## One-time setup: export templates
Godot builds games from "export templates". They must match the editor version (4.7.2).

1. Open the project in Godot (`D:\Godot_v4.7.2-stable_win64.exe`, then open `D:\Game_Project\Nano-cafe`).
2. **Editor → Manage Export Templates… → Download and Install.** It's about 1 GB, from Godot's official servers.
3. When it says *Installed*, close the window.

The templates end up in `%APPDATA%\Godot\export_templates\4.7.2.stable`.

## Export from the editor
1. **Project → Export…**
2. Pick the **Windows Desktop** preset. It is already set up in `export_presets.cfg`:
   - The game is packed inside the `.exe` (`embed_pck`), so it is a single file.
   - `data/*.json` is included. The game reads these files directly, and without them it won't start.
   - `tests/`, `tools/`, `docs/` and `graphify-out/` are left out.
3. **Export Project…** Keep the path `build/windows/NanoBrewCafe.exe` and untick **Export With Debug**.

## Export from the command line
```bash
"/d/Godot_v4.7.2-stable_win64.exe" --headless --path "D:/Game_Project/Nano-cafe" --export-release "Windows Desktop" "D:/Game_Project/Nano-cafe/build/windows/NanoBrewCafe.exe"
```

## Sending it to a friend
- Zip `build/windows/NanoBrewCafe.exe` and send the zip, for example through Google Drive or Discord.
- `build/` is in `.gitignore`, so builds never go into git.
- The build isn't code-signed, so Windows SmartScreen may say *Windows protected your PC*. Your friend clicks **More info → Run anyway**.
- Saves and settings go to the friend's own `%APPDATA%\Godot\app_userdata\NanoBrew Café\` folder.
- To get their notes, ask for:
  - a screenshot;
  - their game log: `%APPDATA%\Godot\app_userdata\NanoBrew Café\logs\godot.log`.
