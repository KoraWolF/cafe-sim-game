# Version control

## Branches

- `main` always opens in Godot and passes the tests. Nothing is committed straight to it except small fixes and doc edits.
- Everything else gets its own branch off `main`: a new feature, a new system, or any change that touches many files. Name the branch after the work: `core-loop`, `night-ops`, `decorating`, `ui-shift-hud`.
- When a branch is done and its tests pass, merge it into `main` with `git merge --no-ff <branch>`. That keeps one merge commit per feature, so the history reads like a feature list and one feature can be reverted whole.
- Delete a branch after merging, or keep it if it's useful as a record.

## Commits

- One commit for each step that works, with a message that says what changed in the game, for example "Add stoves and timed cooking". Not "update files".
- Run the tests before every commit:

```bash
"/d/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s res://tests/run_tests.gd
```

## Milestones

Tag each playable milestone so you can always go back to it:

```bash
git tag -a v0.1-core-loop -m "Core loop playable headless"
```

## Back-up

1. **GitHub (main backup):** `origin` is `https://github.com/KoraWolF/cafe-sim-game.git` over HTTPS with the Windows credential manager, like monster-brothel (keep it private). Push `main` and every work branch at the end of each session: `git push -u origin <branch>`, and push tags with `git push --tags`.
2. **Second copy (optional):** a few times a month, write a single-file bundle to another drive or cloud folder: `git bundle create D:/Backups/nanobrew-YYYY-MM-DD.bundle --all`. It restores with `git clone <bundle>`.

## Large files

Art, audio and fonts go through Git LFS (see `.gitattributes`). Run `git lfs install` once on each machine. Keep source art (`.psd`, `.kra`, Spine projects) in `art/source/` and exported sprites in `art/`.
