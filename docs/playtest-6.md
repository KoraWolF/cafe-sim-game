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
