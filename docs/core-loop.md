# Core loop (decisions, 2026-10-26)

Decisions the GDD left open, as agreed with @Boss. Every number is a starting guess and lives in `data/balance.json`.

- **Engine:** Godot 4.7, GDScript. The game logic has no UI and is tested headless (`tests/run_tests.gd`). The UI will be added later and will only call `GameLoop`.
- **Time:** whole seconds. The game advances only while a shift is playing: 1 game second is 1 real second at 1x speed. A day is one **café shift** (default 480 s = 8 min, tunable within 5–10 min) followed by a **night**. The night doesn't pass on its own: the player plans and then ends it.
- **Service (Zombie Cafe style):** the player starts dishes on stoves. Each dish costs coins and makes a batch of servings that go to the counter. Customers queue, take a free seat and order one unlocked recipe. A free **server** Synth carries a serving to them. They eat, pay, and leave. While they wait, satisfaction drops.
- **Roles during a shift:** server (delivers, based on speed), chef (adds to cooking speed for all stoves), greeter (customers arrive more often), rest (doesn't work and doesn't drain). With no chef the stoves still cook at base speed, because the player is the cook.
- **Star and conversion:** a customer who finishes with satisfaction ≥ the star threshold pays a tip and keeps a star for a short window. During that window the player can spend 1 NanoBrew on them, if a Sync Pod is free. They become a Synth of their type's species, with a random trait from that type's pool. Each conversion adds Suspicion in the current district.
- **NanoBrew:** brewed from 1 Nano Core plus some coins. Nano Cores come from raids. A new game starts with 1 NanoBrew, so the first conversion can happen in the first shift.
- **Start:** 1 starter Synth (Steady-unit, server), 2 stoves, 4 seats, 2 Sync Pods.
- **Upkeep:** a Synth on duty drains battery every second. Low battery makes it slower, and at 0 it stops. At night every Synth recharges in its Pod, which costs Power (bought with coins). If Power runs out, Synths recharge only partly. Xenos cost more to recharge (special fuel).
- **Night Ops, attack:** the player may pick one rival café in the district and a squad (up to 4 Synths with battery). An auto-battle runs and returns a round-by-round report for the UI to play back. Winning gives coins and Nano Cores and adds Suspicion. Either way, raiders spend battery. A raided café is closed to raids for a few days.
- **Night Ops, defense:** each night MegaBean may raid you. The chance and the squad's strength grow with Suspicion, and the squad grows stronger with days. Synths that stayed home fight, with security décor adding HP. Losing costs coins and a Nano Core.
- **Suspicion:** a number from 0 to 100 per district. It goes up with conversions and raids and falls a little every night.
- **Species weaknesses:** Clerkbot slows late in the shift; Bulkform can break dishes on delivery; Glitchling can glitch (skips a second of cooking); Hypeform is slow; Steady-unit barely drains; Xeno costs more to recharge and unlocks an exotic recipe.
- **Traits** are stat modifiers on top of species. Night Owl works faster late in the shift and fights better. Perfectionist makes customers happier but works slower. Chatty earns more tips and works slower. Kleptomaniac brings more raid loot but may pocket coins at night.

Not built yet: UI, saving, decorating, furniture upgrades, buying pods, stoves and seats, district takeover, menus.
