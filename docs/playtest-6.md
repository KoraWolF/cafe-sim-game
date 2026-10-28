# Playtest 6 feedback (2026-10-28)

## Answer: what is "Alley" on the top bar?
It is the district you are taking over. The city is split into districts, each run by MegaBean cafés. You start in the **Alley**:
- Win raids there to earn Influence (the "Influence 0 / 10" next to it).
- With enough Influence, beat the district's flagship café to take the Alley over.
- Then the next district, **Neon Market**, opens.

The Help tab now says this too.

## Fixes
- **Daily quest Claim at the top left did nothing** (seen with the raid daily). The button sent the quest's name, but claims go by the quest's place in the list, so it always tried the first daily. It now claims the right one. (branch `fix-tracker-claim`)
- **Workers still jumped, e.g. counter to bin.** A carry always took 2 seconds, whatever the distance, so long trips looked like jumps. (branch `walk-timing`)
  - Every trip now takes as long as the walk: from where the worker stands, to the pick-up, then to the drop-off.
  - Afterwards the worker stays where the trip ended, and the next trip starts there.
  - Customers walk to the register before paying.
  - Everyone walks a bit slower: 1.8 tiles a second, the same speed for timed trips and free walking.
- **Shop off the right edge of the screen:** the shop is now a strip along the bottom (see UI).

## Customers (branch `convert-anyone`)
- **Click any customer, any time, to convert them:**
  - in line, seated, eating, paying, or walking out until they're out of sight;
  - no star is needed;
  - a dish already on its way to them goes back to the counter.
- The Ready to convert list is gone.
- **Patience:** customers in a 6×6 café wait 3× as long. This drops evenly to normal at the top café level. Customers waiting in line outside give up sooner than seated ones (line patience 30 s, was 40 s).
- "Loved it" (high mood) still gives a tip and counts for quests.
- Save format v18: the old starred list becomes the customers walking out.

## Café level, Pods, stoves, batteries (branch `cafe-level`)
- The Floor upgrade is now called **Café level**.
- **Sync Pods are bought in the Shop's Furniture tab** for 250 each. You can own as many as there are tiles along the café's side: 6 at 6×6, up to 20 at 20×20. The Pod upgrade is gone.
- **A stove only cooks while its Chef works there.** Pieces can be flagged `auto_cook` for a future stove that cooks by itself.
- **A new game starts with three workers:**
  - Byte, a Glitchling Chef at the stove;
  - a Server;
  - a Cashier (one of the first two, picked at random);
  - 4 Pods, so one is free for your first NanoBrew.
- **Batteries:**
  - Only workers resting in their Pod when the café closes recharge at night. The night report lists the ones that weren't.
  - An empty battery no longer stops a worker. They work at 50% speed.
  - Low battery (under 20%) means 75% speed.
- A counter holds at most **999** servings.
- Save format v19: the old Pod upgrade level is dropped, and your Pods stay.

## Dishes (branch `dish-unlocks`)
A new game has **Coffee** only. More dishes come from:

| Dish | How to get it |
|---|---|
| Toast | Story: first conversion |
| Ramen | Story: second stove |
| Quantum Croissant | Achievement: 100 served |
| Plasma Pho | Achievement: 10,000 coins earned |
| Neon Noodles, Byte Burger | 40% chance after a won raid |
| Glitch Gelato, Circuit Cake | 40% chance after holding off a MegaBean raid on your café |
| Star Jelly | Having a Xeno (unchanged) |

Save format v20: older games keep every dish they could already cook.

## UI (branch `shop-carousel`)
- **Shop:**
  - a round button in the bottom-right corner;
  - opens a strip along the bottom: category tabs (Furniture, Décor, Upgrades, Energy, Workshop) over a sideways-scrolling row of cards with ◀ ▶ arrows;
  - Arrange Floor and Close in the header;
  - the café view moves up to stay above the strip.
- **Arrange:**
  - Put back is now **Cancel**;
  - **Select several**: click pieces to add or remove them, then Store selected or Sell selected;
  - every Store and Sell asks for confirmation, saying what goes and how many coins you get back.

## Balance (40 days × 5 seeds)
The sim bot now does what a player has to:
- keeps a Chef on every stove (while a Server is left);
- sends everyone to their Pod for the last 20 seconds of the shift;
- puts them back to work in the morning;
- buys Pods up to the cap.

| | Playtest 5 | Now |
|---|---|---|
| Customers seated | ~1,800 | ~2,110 |
| Loved it | 84% | 97.5% |
| Left angry | — | ~13 |
| Conversions | 12.6 | 17.4 |
| Alley taken | day 12 | day 9 |
| Neon Market taken | day 20 | day 17 |
| Coins at day 40 | ~5,320 | ~21,800 |
| Corporate Audits | — | about 1 per run (5 across 5 runs, 2 lost) |

Both districts are still taken in all 5 runs.

**The game is now clearly easier and coins pile up.** The main cause is the extra patience: almost every customer loves their meal and tips. Worth tuning next, e.g. a smaller `patience_bonus` (2.0 → 1.0) or lower tips.

### Tuning (branch `tune-patience`)
Testing one change at a time (40 days × 2 runs each) showed patience was **not** the cause. Halving the bonus barely moved coins (21,100 against 21,800 over 5 runs).

| Variant | Coins at day 40 |
|---|---|
| As built | 9,480 |
| Empty battery stops work again | 3,586 |
| No dish drops | 1,523 |

The real drivers are workers still working on an empty battery (kept: it was asked for) and the new dishes earning far more per second than Ramen.

**Changes**
- New dish prices lowered so they sit just above Ramen (2.0 coins per cooking second): Neon Noodles 15, Byte Burger 18, Glitch Gelato 14, Circuit Cake 21, Quantum Croissant 16, Plasma Pho 24.
- Raid and defense dish drops: 25% chance (was 40%).
- Patience stays at 3× in a new café.

**Result (40 days × 5 seeds)**
- About 1,840 seated, 89% loved it, about 130 left angry.
- 14.4 conversions per run.
- Alley taken around day 9, Neon Market around day 21, in all 5 runs.
- About 4,030 coins at day 40.
- About 4 Corporate Audits per run, 2.4 of them lost.


## Round 2 (branch `ui-strips`)
- The window is maximized when it would be bigger than the screen, so it stays above the Windows taskbar.
- **Menu (was Shop):**
  - The round button at the bottom right is now called Menu.
  - Its card row scrolls with the mouse wheel.
  - NanoBrew is brewed in its Workshop tab. The night hub only shows the count.
- **Bag and Arrange** open as strips along the bottom, like the Menu.
  - Bag: a row of cards, with the detail box at the right.
  - Arrange: what you hold, Select several, and storage as a sideways row.
- **Top bar:** the pause menu button is a cog icon.
- **Night hub:** narrower (640 px, was 780) with smaller text.
- **Top-left tracker:** the story step comes first, under "Story", then the dailies under "Daily". Both can be claimed there.
- The round Menu button stays left of the night hub. The tutorial box stays above an open strip.

## Round 3 (branch `pod-charging`)
- **Workers resting in their Pod now charge during the shift:** 0.4 battery points a second, free (no Energy). That's about 3× the usual drain, so a 125-point battery fills from empty in about 5 minutes.
- Night recharge is unchanged: those in their Pod at closing refill fully, using Energy.
- Sim (40 days × 5 seeds): about 7,300 coins at day 40 (was about 4,000), since less Energy is bought. Alley taken around day 9, Neon Market around day 19, in all 5 runs.

## Round 4: auto-chess combat (branch `grid-battles`)
Raids, MegaBean raids on the café and Corporate Audits are now fought on a grid, auto-chess style, instead of in turns. References: the genre basics (placement before the fight, nearest-target AI, attack speed, range in tiles, mana from attacking and being hit, a skill on full mana) as described for [TFT](https://metabot.gg/en/TFT/guides/tft-combat-mechanics-mana-damage-armor-explained), [Dota Underlords](https://dotaunderlords.fandom.com/wiki/Attacks) and a [game-design module on auto battlers](https://seanking11.github.io/gamebootcamp/modules/24-auto-battler).

- **Board:** 8 × 6 isometric squares. Each side owns 3 rows; the player's half is always nearest the camera.
- **Formation:** set in Night Ops → Battle formation. Click a Synth, then a tile (front row faces the enemy); someone already there swaps. Synths without a spot are placed by class: tanks and fighters in front, fragile behind them, ranged at the back. Saved with the game.
- **Classes** (`data/combat.json`):

| Class | Species | Range | Attacks every | Moves (tiles/s) | Armor |
|---|---|---|---|---|---|
| Tank | Bulkform | 1 | 1.3 s | 1.6 | 30% |
| Fighter | Steady-unit | 1 | 1.0 s | 2.0 | 15% |
| Ranged | Clerkbot, Hypeform, Xeno | 3 | 1.1 s | 1.8 | 0% |
| Fragile | Glitchling | 1 | 0.7 s | 2.8 | 0%, goes for the weakest enemy |

  MegaBean guards have classes too, set per café in `data/districts.json`.
- **Fighting:** each unit keeps its target until it falls, walks round others toward it, and attacks when in range. Damage is power × 0.8–1.2, less armor; a shield takes damage first.
- **Mana:** +10 per attack, +5 per hit taken. Full mana casts the species skill:

| Skill | Species | Mana | Effect |
|---|---|---|---|
| Slam | Bulkform | 80 | 1.2× damage to all enemies next to it, stun 1 s |
| Fortify | Steady-unit | 70 | Shield of 30% max HP |
| Overtime | Clerkbot | 60 | Attacks 1.6× faster for 4 s |
| Chain spark | Glitchling | 50 | Hits the target and the 2 enemies nearest it |
| Cheer | Hypeform | 60 | Heals the most-hurt ally for 30% of their max HP |
| Beam | Xeno | 70 | 2.5× damage to the target |

- **Time limit:** a fight still going after 45 s is won by the defenders.
- **Ready for models and animations:** a battle is recorded as a timeline of events (move, attack, hit, cast, heal, shield, stun, down). `BattlePlayback.unit_state()` gives any unit at any moment: position, HP, shield, mana, animation (`idle`, `move`, `attack`, `cast`, `hurt`, `down`) with the time into it, and facing. `BattleView._draw_unit` is the one place to swap the placeholder shapes for sprites or models.
- **Sim (40 days × 5 seeds):** raids won 37.4 of 38.2, MegaBean raids on the café lost 2.4 of 15.2, Audits lost 1.0 of 4.8. Both districts taken (day 9 and 19). About 6,000 coins at day 40.
