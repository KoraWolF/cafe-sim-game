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

District takeover: winning a raid on a rival earns that district Influence (kiosk-sized rivals 1, bigger ones 2). Once Influence reaches the district's target, its MegaBean flagship can be raided. Flagships keep a fixed strength, while ordinary rivals grow 3% stronger for each day their district has been open. Beating the flagship takes the district: it pays income every night (the Alley pays 80, Neon Market 200), and the next district opens the following day with Suspicion at 0. When the last district is taken, the city is yours and the game carries on.

Corporate Audit: if Suspicion is at 90 or more at night, an Audit replaces the random MegaBean raid. It always comes: 4 raiders, each 1.5 times as strong as a normal raider. Losing it costs 30% of your coins and one random Synth (never the last), and the café stays shut for the next shift. Win or lose, Suspicion then drops to 40.

Synth levels: Synths earn XP from their work. A server earns 2 per dish delivered. Chefs share 6 per batch cooked, and greeters share 1 per customer who arrives. Each raider earns 30 for a won raid and 15 for a lost one, and each Synth defending the café earns 20. Going from level n to n + 1 costs 100 × n XP, up to level 10. Each level adds 8% of the species' base speed, cooking, appeal, power and HP. Battery, drain and weaknesses don't change, and trait bonuses stay flat. Saves are now format v3, which adds level and XP.

Daily menu: each night the player picks up to `menu_slots` unlocked dishes for the next shift. You start with 2 slots, and the menu-slot upgrade adds up to 2 more (250, then 500 coins). Customers order only from the menu. Each customer type has favourites (`favorites` in `customer_types.json`): a favourite on the menu is ordered 3 times as often as other dishes and adds +10 satisfaction when it's served. A new game starts with the first unlocked dishes on the menu. If nothing on the menu can be ordered (for example, an Audit took the Xeno that unlocks star jelly), customers order any unlocked dish. Saves are now format v4.

Café floor and décor: the café is a grid 8 tiles across, starting 6 rows deep. Each floor expansion adds 2 rows, up to 4 times; it costs 500 coins and doubles each time. Seats (1×1), stoves (2×1) and Sync Pods (1×2) stand on it like décor and count only once placed. Their upgrades put the piece in storage and need a free spot for it. A new game lays out the starting furniture automatically. Décor (`data/pieces.json`, 10 pieces costing 100 to 5,000) adds Vibe, plus Vibe from adjacency rules (`data/adjacency.json`) for each pair of touching pieces with matching tags. Vibe divides how fast waiting customers lose satisfaction by (1 + 0.003 × Vibe), and every served dish adds 0.03 × Vibe satisfaction, up to +5. Buying, placing, moving (free), picking up and selling (50% back) happen only at night. A cooking stove, or a Pod a Synth needs, can't be picked up. Saves are now format v5, which saves the floor instead of seat and Pod counts. Older saves get their furniture laid out on load.

Not built yet: UI.

## Balance pass (30 days × 5 seeds, `tools/balance_sim.gd`)

Run it with `godot --headless --path . -s res://tools/balance_sim.gd -- 30 5` (add `--daily` for a table of each day). The bot cooks what customers ask for, converts every star, keeps Power topped up, buys the cheapest upgrade (keeping 150 coins in reserve), and raids only rivals it expects to beat.

Changes made: each seat beyond the starting 4 brings customers 10% faster (`arrival_per_extra_seat`), rival guards grow 6% stronger per day (`rival_growth_per_day`), and upgrade prices climb faster. Results after: about 1,960 customers seated in 30 days, 90.7% stars, about 8 conversions, 18 raids (almost all won, because the bot skips raids it can't win), MegaBean attacks on 15 nights (9 lost), and about 3,600 coins at day 30.

Still open, waiting on design (district takeover, décor):
- Upgrades are maxed by about day 17–20, and after that coins pile up with nothing to spend them on.
- Suspicion reaches its cap (95+) by about day 14 if the player raids every other night, and then it stops creating any choices.
- The Alley has only two rivals. After about day 10 the express café is too strong to raid, so all raids go to the kiosk.

## Decisions for the next features (2026-10-26)

- **District takeover (built):** each district has a MegaBean flagship (the boss). Raiding its smaller rivals earns Influence. Enough Influence unlocks the boss raid, and winning it takes over the district: it then gives income each day, and the next district opens with stronger rivals.
- **Losing (built as the Corporate Audit):** setbacks only, never game over. When Suspicion is at max, a "Corporate Audit" night comes: a big raid you have to survive. Losing it closes the café for a day and costs coins or a Synth, and then the game carries on.
- **Menu (built):** each night the player picks up to N dishes for the next day (more slots come from an upgrade). Customers only order from the menu, and some customer types prefer certain dishes.
- **Synth growth (built):** Synths earn XP from shifts and raids, and each level raises their stats a little.

## Balance check after district takeover (40 days × 5 seeds)

Every seed takes the Alley on day 11 or 12. 2 of 5 take Neon Market on day 19–20; the rest are still building a strong enough squad at day 40. Expect that to come sooner once Synths can level up. About 30 raids (29.8 won, since the bot only picks raids it expects to win), 2 Audits (1.8 lost: the bot leaves only one Synth home, even when an Audit is coming), 92% stars, about 4,100 coins of district income, and about 10,900 coins left at day 40. Coins still pile up late in the game; décor is the planned place to spend them.

## Balance check after Synth levels (40 days × 5 seeds)

The Alley still falls on day 11–13. Neon Market is now taken in 4 of 5 runs (days 19, 19, 25 and 35), up from 2 of 5 before levels. Synths end at about level 5 on average, and the best one reaches about level 9 (usually the starter, which serves every shift). MegaBean raids lost fell from 7.8 to 5.0 per run. The bot still loses every Audit because it keeps only one Synth home. Coins at day 40 are about 13,400, so a late-game coin sink (décor) is still needed.

## Balance check after the daily menu (40 days × 5 seeds)

The bot fills the menu with the dishes the customer mix likes most. Compared with before the menu: more customers seated (2,857 vs 2,650 over 40 days), far fewer leaving angry (6.8 vs 21), 92% stars, and Neon Market taken in all 5 runs (days 17–32). The Alley falls on day 9–12. A focused menu makes the kitchen easier to keep stocked, so good menu planning pays off. Coins at day 40 are about 15,300, which makes décor as a coin sink the most needed next feature.

## Décor design (agreed 2026-10-26, built)

Your answers:
- **Effect: Vibe.** Décor adds Vibe, which slows how fast waiting customers lose satisfaction and adds a little satisfaction to every meal.
- **Placement: tile grid with adjacency.** The café is an isometric tile grid. Each piece has a footprint (1x1, 2x1, 2x2, and can be rotated), and pieces may not overlap.
- **Adjacency by tags.** Each piece has tags (plant, light, tech, cozy, …). Data rules such as "light next to plant: +2 Vibe" apply to any pair of touching pieces with matching tags.
- **Furniture is placed like décor.** Seats, stoves and Sync Pods take tiles too. Buying one of those upgrades gives you a piece to place, and it only counts once it's placed. The starting furniture comes pre-placed. A full floor means you have to expand before buying more.
- **Prices: one-time coins.** Better pieces cost much more (about 100 up to 5,000+). Selling a piece gives back 50%.
- **Floor grows with an upgrade.** Start with a small grid; a floor-expansion upgrade adds rows.
- **Editing: night only.** Buy, place, move, rotate and sell only at night, while the café is closed. Moving is free.

Proposed numbers (my defaults, to be tuned with the sim):
- **Floor:** 8×6 tiles at the start. Each floor expansion adds 2 rows, up to 4 times (8×14 at most), at 500 coins growing ×2 each time.
- **Furniture footprints:** seat 1×1, stove 2×1, Sync Pod 1×2.
- **Vibe effect:** proposed as 1 + Vibe / 100 and Vibe × 0.1 per meal (up to +10). The sim showed that was too strong (98% stars), so it shipped as 1 + 0.003 × Vibe and 0.03 × Vibe per meal, up to +5.
- **Save format:** v5. Older saves get their furniture laid out automatically.

## Balance check after décor (40 days × 5 seeds)

The bot buys the décor piece that adds the most Vibe per coin at its best spot, keeping 150 coins in reserve and leaving room for future furniture. It also expands the floor when furniture no longer fits. Upgrades plus décor now take about 33,900 coins over 40 days (21,300 before décor), and coins at day 40 fell from about 15,300 to about 5,100. A fully decorated floor reaches about 520 Vibe, and stars rise from 92% to 96.6%. The Alley falls on day 11–14 (a little later, since money goes into décor) and Neon Market in 4 of 5 runs (days 20–33). The proposed Vibe numbers gave 98% stars, so I weakened them:

| Loss divided by 1 + k × Vibe | Per-meal bonus | Stars | Coins at day 40 |
| --- | --- | --- | --- |
| k = 0.01 (proposed) | 0.1 × Vibe, max 10 | 98.0% | 4,100 |
| k = 0.004 | 0.04 × Vibe, max 6 | 97.1% | 5,200 |
| **k = 0.003 (chosen)** | **0.03 × Vibe, max 5** | **96.6%** | **5,100** |
| k = 0.002 | 0.02 × Vibe, max 4 | 96.4% | 5,300 |
