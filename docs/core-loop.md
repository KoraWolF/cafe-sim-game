# Core loop (decisions, 2026-10-26)

Decisions the GDD left open, as agreed with @Boss. Every number is a starting guess and lives in `data/balance.json`.

- **Engine:** Godot 4.7, GDScript. The game logic has no UI and is tested headless (`tests/run_tests.gd`). The UI will be added later and will only call `GameLoop`.
- **Time:** whole seconds. The game advances only while a shift is playing: 1 game second is 1 real second at 1x speed. A day is one **café shift** (default 480 s = 8 min, tunable within 5–10 min) followed by a **night**. The night doesn't pass on its own: the player plans and then ends it.
- **Service (Zombie Cafe style):** the player starts dishes on stoves. Each dish costs coins and makes a batch of servings that go to the counter. Customers queue, take a free seat and order one unlocked recipe. A free **server** Synth carries a serving to them. They eat, pay, and leave. While they wait, satisfaction drops.
- **Roles during a shift:** server (delivers, based on speed), chef (adds to cooking speed for all stoves), greeter (customers arrive more often), rest (doesn't work and doesn't drain). With no chef the stoves still cook at base speed, because the player is the cook.
- **Star and conversion:** a customer who finishes with satisfaction ≥ the star threshold pays a tip and keeps a star for a short window. During that window the player can spend 1 NanoBrew on them, if a Sync Pod is free. They become a Synth of their type's species, with a random trait from that type's pool. Each conversion adds Suspicion in the current district. Target star rate: about 90% of seated customers (10 s of free waiting, then -1.2 satisfaction per second, star at 80). That measured 84% in days 1–3 and 90% over 10 days with a player who cooks to demand.
- **NanoBrew:** brewed from 1 Nano Core plus some coins. Nano Cores come from raids. A new game starts with 1 NanoBrew, so the first conversion can happen in the first shift.
- **Start:** 1 starter Synth (Steady-unit, server), 2 stoves, 4 seats, 2 Sync Pods.
- **Upkeep:** a Synth on duty drains battery every second. Low battery makes it slower, and at 0 it stops. At night every Synth recharges in its Pod, which costs Power (bought with coins). If Power runs out, Synths recharge only partly. Xenos cost more to recharge (special fuel).
- **Night Ops, attack:** the player may pick one rival café in the district and a squad (up to 4 Synths with battery). An auto-battle runs and returns a round-by-round report for the UI to play back. Winning gives coins and Nano Cores and adds Suspicion. Either way, raiders spend battery. A raided café is closed to raids for a few days.
- **Night Ops, defense:** each night MegaBean may raid you. The chance and the squad's strength grow with Suspicion, and the squad grows stronger with days. Synths that stayed home fight, with security décor adding HP. Losing costs coins and a Nano Core.
- **Suspicion:** a number from 0 to 100 per district. It goes up with conversions and raids and falls a little every night.
- **Species weaknesses:** Clerkbot slows late in the shift; Bulkform can break dishes on delivery; Glitchling can glitch (skips a second of cooking); Hypeform is slow; Steady-unit barely drains; Xeno costs more to recharge and unlocks an exotic recipe.
- **Traits** are stat modifiers on top of species. Night Owl works faster late in the shift and fights better. Perfectionist makes customers happier but works slower. Chatty earns more tips and works slower. Kleptomaniac brings more raid loot but may pocket coins at night.

Saving: `SaveSystem` writes plain JSON with a version number, crash-safe, with a `.bak` fallback; 3 manual slots plus an autosave when a shift closes and after each night.

Upgrades: at night the player buys stoves, seats, Sync Pods and security. Each level costs more and has a cap (`data/upgrades.json`).

Not built yet: UI, decorating, district takeover, menus.

## Balance pass (30 days × 5 seeds, `tools/balance_sim.gd`)

Run it with `godot --headless --path . -s res://tools/balance_sim.gd -- 30 5` (add `--daily` for a table of each day). The bot cooks what customers ask for, converts every star, keeps Power topped up, buys the cheapest upgrade (keeping 150 coins in reserve), and raids only rivals it expects to beat.

Changes made: each seat beyond the starting 4 brings customers 10% faster (`arrival_per_extra_seat`), rival guards grow 6% stronger per day (`rival_growth_per_day`), and upgrade prices climb faster. Results after: about 1,960 customers seated in 30 days, 90.7% stars, about 8 conversions, 18 raids (almost all won, because the bot skips raids it can't win), MegaBean attacks on 15 nights (9 lost), and about 3,600 coins at day 30.

Still open, waiting on design (district takeover, décor):
- Upgrades are maxed by about day 17–20, and after that coins pile up with nothing to spend them on.
- Suspicion reaches its cap (95+) by about day 14 if the player raids every other night, and then it stops creating any choices.
- The Alley has only two rivals. After about day 10 the express café is too strong to raid, so all raids go to the kiosk.

## Decisions for the next features (2026-10-26)

- **District takeover:** each district has a MegaBean flagship (the boss). Raiding its smaller rivals earns Influence. Enough Influence unlocks the boss raid, and winning it takes over the district: it then gives income each day, and the next district opens with stronger rivals.
- **Losing:** setbacks only, never game over. When Suspicion is at max, a "Corporate Audit" night comes: a big raid you have to survive. Losing it closes the café for a day and costs coins or a Synth, and then the game carries on.
- **Menu:** each night the player picks up to N dishes for the next day (more slots come from an upgrade). Customers only order from the menu, and some customer types prefer certain dishes.
- **Synth growth:** Synths earn XP from shifts and raids, and each level raises their stats a little.
