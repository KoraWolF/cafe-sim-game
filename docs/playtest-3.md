# Playtest 3 feedback and plan (2026-10-27)

## Answer: what is Power on the top bar?

It is the café's electricity stock. At night it recharges Synths' batteries: 0.2 per battery point (times the species' recharge cost), bought for 2 coins each. It shared a name with a Synth's fight Power, so the top bar now calls it **Energy**. The code still names it `power`.

## Branches

| # | Branch | What's in it | Status |
| --- | --- | --- | --- |
| 1 | `playtest-3-quick` | Pencil icon to rename, battery as %, max battery 70–200 rolled per unit, new Synths walk to their Pod at 70% on Rest, Power→Energy, Bin and throw-away (the counter bug), Auto button | built |
| 2 | `live-build` | Shop, upgrades, décor and floor editing open at any time from the top bar (not only at night) | built |
| 3 | `tables` | Tables apart from seats, seats must face a table, dish shown and eaten on the table; starter café 8×8 with 3 tables, 3 chairs, 1 bin | built |
| 4 | `cashier` | Cashier role and cashier counter, everyone pays on the way out, star wait spot removed, start with 2 staff | built |
| 5 | `unit-cards` | New worker and customer cards, a draggable Details window (Work, Fight, Trait, Gear tabs), an Info button | built |
| 6 | `items` | Inventory: EXP bottles, equipment (5 tiers), fashion, selling, crafting from raid materials | built |
| 7 | `quests` | 3 daily quests (real-time reset), story quests, achievements | |

## Decisions (answers to the design questions)

**Bin and throw-away (bug: old menu food blocked counters)**
- Click a counter, or a stove with a waiting batch, and confirm. A server carries **all** of it to the nearest bin. No refund and no auto-bin.
- At night nothing moves: the servers do it first thing the next shift.
- A throw-away order comes **before** serving customers, so a busy café still does it at once.
- The bin is a 1×1 floor piece, moved like other furniture. More can be bought (Bin upgrade: 40 coins, ×1.5, up to 3). A new game has one. Older saves get one placed (or put in storage if the floor is full).

**New Synths and battery**
- Each unit rolls its max battery when it arrives as a customer (shown on the customer card) or at the start of the game.
  - Bulkform: 130–200
  - Hypeform: 70–140
  - every other species: 70–200
- On conversion the Synth walks round the front of the café into a free Pod. It starts on **Rest** at **70%** of its max.
- NanoBrew still needs a free Pod.
- Battery shows as a percentage everywhere, with the max beside it.
- Synths from older saves keep their species' old max (100, Bulkform 150, Xeno 120).

**Auto** (unlocks on day 3)
- When on, each night passes by itself:
  - same menu, no raid
  - batteries recharge with the Energy you have, with a warning when it's short
  - autosave, then the next shift starts
- It stops and leaves the night to you when a Corporate Audit is coming.
- A MegaBean raid on the café still plays out and shows the report.
- A quiet night shows only a toast.

**Live building (branch 2, built)**
- Buying, moving and selling furniture and décor (tables, seats, stoves, Pods and the rest) works at any time, not only at night. The café keeps running while you shop or arrange.
- The top bar has **Shop** (Energy, café upgrades, décor) and **Arrange**. The night hub keeps Summary, Menu, Staff and Night Ops, and Energy moved into the Shop.
- Pieces in use can always be **moved**, but can't be picked up or sold: a cooking stove or one with a waiting batch, a counter with food (or the last counter), a seat with a customer on it.
- Still night only: the daily menu and planning a raid.
- One panel on the right at a time (edit panel, shop, night hub). The Synth card opens beside it.

**Tables (branch 3, built)**
- Seats **turn to face** a table right beside them by themselves (chosen after branch 2). A seat with no table shows "No table" and a red outline while arranging.
- When a seat could use two tables (or two seats share one table), the seats with fewer choices pick first, so as many seats as possible work.
- New tables and seats go beside a free partner when you buy them. Older saves (v10) get a table beside each seat, or in storage if there's no room.
- A table whose seat has a customer on it can't be picked up (it can be moved).
- Seat and Table upgrades cost 30 each (×1.5 per level, 8 levels), so a working seat costs what a seat alone did before.
- Balance (40 days × 5 seeds): at 60 coins each, about 1,935 seated, 1,970 coins, and Neon Market taken in only 2 of 5 runs. At 30 each, about 2,544 seated, 95.6% stars, 5,130 coins, and the Alley taken on day 12–20 with Neon Market in 4 of 5 runs, close to branch 1.

Original decisions:
- A table is 1×1. A seat works only when it's beside a table (not diagonally) and rotated to face it.
- One seat per table, and one dish per table. A seated customer locks that table.
- Seats without a valid table give no customer slot (like décor) and show an outline warning in edit mode.
- Vibe still comes from the seat.
- Starter café: 8×8 floor with 2 stoves, 2 counters, 3 tables, 3 chairs and 1 bin.

**Cashier (branch 4, built)**
- New **Register** piece (1×1, Register upgrade 150 coins ×1.8, up to 3 more) and **Cashier** role. Working Cashiers pair with registers in floor order, one each; extra Cashiers wait. The last register can't be picked up.
- After eating, a customer gets their bill (plus a tip if starred) and joins the pay line. A Cashier takes them in 1 s (2 s if starred) at the Cashier's speed. Coins come in then.
- A customer who gets angry in the line still pays, but loses the tip. At closing, the line pays if a Cashier is working; otherwise they leave without paying.
- Starred customers show their star in the pay line and while they linger outside after paying (star_window_seconds). Click them anywhere to convert. One converted in the line pays first.
- New game: Proto (Server) plus **Tally**, a Clerkbot **Cashier**, with **3 Pods** so day 1's NanoBrew has room. Save format v11 gives older cafés a register and a Clerkbot Cashier with a Pod of its own.
- The "Starred? Wait here!" board is gone.
- Balance (40 days × 5 seeds): about 2,094 customers paid, 94.5% stars, the Alley taken on day ~11 and Neon Market on day ~26 in **all 5 runs**, about 2,650 coins at day 40. The extra Synth raises Suspicion (2.6 Audits), and early coins go to more upkeep.

Original decisions:
- Everyone pays at a cashier counter (1×1, one Cashier each) before leaving.
  - 1 s each, or 2 s for star customers
  - faster with the Cashier's speed
  - **no Cashier means nobody can pay**
- So a new game starts with 2 staff.
- Coins arrive when the customer pays. A customer who gets angry in the pay queue still pays, but without a tip.
- The star wait spot goes away. Click a star customer anywhere to convert them.

**Items (branch 6, built, agreed defaults)**
All numbers are in `data/items.json`.
- **Equipment:** one stat each.
  - Swift Boots: speed, +5/10/18/28/40%.
  - Charm Ring: appeal, +5/10/18/28/40%.
  - Spark Amulet: power, +2/4/7/11/16.
  - Plate Amulet: HP, +6/12/20/30/45.
  - Tiers are common, magic, rare, epic and legendary. Slots are ring, boots and amulet.
  - Sells for 20/50/120/300/750.
- **Fashion:** 3 hats and 3 outfits, looks only, drawn as colours on the chibi. Every game starts with a Neon Cap and a Teal Jacket (older saves get them too, format v12).
- **Raid wins:**
  - 1–3 Scrap; a flagship also gives 1 Chip.
  - 25% chance of equipment (a flagship gives one for sure, rare or better).
  - An EXP bottle: 50% at first, −2% per day and −2% per average staff level above 1, floor 5%. Large bottles only from day 10.
- **Crafting:**
  - Basic: 5 Scrap gives Common 70% or Magic 30%.
  - Advanced: 12 Scrap + 1 Chip gives Rare 60%, Epic 30% or Legendary 10%.
- **EXP bottles:** +20 / +100 / +350, drunk from the Equipment tab.
- **Where things are:**
  - The Shop's **Items** tab has materials, Craft, bottles and owned pieces, with Sell for equipment.
  - The Details window's **Fashion** and **Equipment** tabs wear and take off pieces.
- **Rules:** a piece is either in the inventory or worn by one Synth. A Synth taken by an Audit leaves its pieces behind.

Original decisions:
- Fashion (clothes, hat) is cosmetic only. Equipment (ring, boots, amulet) gives stats: work speed, appeal, power, HP.
- Each piece is unique and can be moved between workers at any time.
- Equipment can be sold in the shop at any time.
- Equipment comes from quests, raid loot and crafting with raid materials, never the shop.
- 5 tiers (common, magic, rare, epic, legendary), all in data so they're easy to change.
- EXP bottles give small +20, medium +100 and large +350 XP. They get harder to find as the days and levels go up. They're used from the Details window.

**Quests (branch 7)**
- 3 daily quests refresh each morning in real time.
- Rewards: EXP bottles, coins, NanoBrew, Nano Cores, fashion.
- They're found in a Quests tab in the night hub plus a small tracker on the shift HUD.

**Cards (branch 5, built)**
- **Worker card:**
  - name with pencil
  - species, best role and trait name
  - level and XP bar, with **HP under the level**
  - battery % with max battery
  - role buttons (5, including Cashier)
  - **Details** and Close. No long descriptions.
- **Details window**, which you can drag by its title:
  - **Work:** best role and current role with what they do, plus Speed, Cooking and Appeal, each with a line on what it does.
  - **Fight:** Power with its formula, HP, fight strength now from battery. There's no speed stat in battles (raiders strike first, then turns alternate), so instead of Speed the tab says so.
  - **Trait:** trait and species with their strengths and weaknesses.
  - **Fashion** and **Equipment:** placeholders until the items branch.
- **Customer card:** type, what they're doing, max battery as a Synth, order, mood, seat Vibe, and the species and trait name they'd become. No long descriptions.
- **Info** (top bar): Stats, Roles and Traits tabs explaining everything.

Original decisions:
- Equipment gets its own tab next to Fashion.
- "Core trait" on the worker card means species plus best role.
- A customer's max battery is the one they'd have as a Synth.
- The Info button explains stats, roles and traits.

## Balance after branch 1 (40 days × 5 seeds)

| | before (main) | after |
| --- | --- | --- |
| customers seated | 2,722 | 2,578 |
| star rate | 97.4% | 92.9% |
| Alley taken | 5 of 5, day 12–17 | 4 of 5, day 12–20 |
| Neon Market taken | 4 of 5 | 4 of 5, day 20–38 |
| coins at day 40 | 6,921 | 4,421 |

**Why it's lower:**
- Battery drain is a fixed amount per second, and a raid uses the battery left at the end of the shift.
- A unit that rolls a small battery (70) ends the shift under 20%, so it fights at half power. The sim bot won't send a unit with under 25 battery.
- In seed 1 the bot never raided at all.
- This is the trade-off of random batteries.

**If it feels too harsh, possible tweaks:**
- raise the low end of the range
- make drain a share of max battery
- recharge before the raid

**Sim changes:**
- The sim bot now puts each new Synth to work in its best role, as a player would.
- It no longer buys bins: they were its "cheapest upgrade" and wasted early coins.
