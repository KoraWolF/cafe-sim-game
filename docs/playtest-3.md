# Playtest 3 feedback and plan (2026-10-27)

## Answer: what is Power on the top bar?

It is the café's electricity stock. At night it recharges Synths' batteries: 0.2 per battery point (times the species' recharge cost), bought for 2 coins each. It shared a name with a Synth's fight Power, so the top bar now calls it **Energy**. The code still names it `power`.

## Branches

| # | Branch | What's in it | Status |
| --- | --- | --- | --- |
| 1 | `playtest-3-quick` | Pencil icon to rename, battery as %, max battery 70–200 rolled per unit, new Synths walk to their Pod at 70% on Rest, Power→Energy, Bin and throw-away (the counter bug), Auto button | built |
| 2 | `live-build` | Shop, upgrades, décor and floor editing open at any time from the top bar (not only at night) | built |
| 3 | `tables` | Tables apart from seats, seats must face a table, dish shown and eaten on the table; starter café 8×8 with 3 tables, 3 chairs, 1 bin | |
| 4 | `cashier` | Cashier role and cashier counter, everyone pays on the way out, star wait spot removed, start with 2 staff | |
| 5 | `unit-cards` | New worker and customer cards, a draggable Details window (Work, Fight, Trait, Gear tabs), an Info button | |
| 6 | `items` | Inventory: EXP bottles, equipment (5 tiers), fashion, selling, crafting from raid materials | |
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

**Tables (branch 3)**
- A table is 1×1. A seat works only when it's beside a table (not diagonally) and rotated to face it.
- One seat per table, and one dish per table. A seated customer locks that table.
- Seats without a valid table give no customer slot (like décor) and show an outline warning in edit mode.
- Vibe still comes from the seat.
- Starter café: 8×8 floor with 2 stoves, 2 counters, 3 tables, 3 chairs and 1 bin.

**Cashier (branch 4)**
- Everyone pays at a cashier counter (1×1, one Cashier each) before leaving.
  - 1 s each, or 2 s for star customers
  - faster with the Cashier's speed
  - **no Cashier means nobody can pay**
- So a new game starts with 2 staff.
- Coins arrive when the customer pays. A customer who gets angry in the pay queue still pays, but without a tip.
- The star wait spot goes away. Click a star customer anywhere to convert them.

**Items (branch 6)**
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

**Cards (branch 5)**
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
