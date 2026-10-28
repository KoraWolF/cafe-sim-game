# Playtest 4 feedback (2026-10-28)

Built on branch `free-furniture`.

## Furniture by the piece
- Stove, counter, seat, table, bin and register are no longer upgrades. Each has a flat price and you can buy as many as you like: the floor space is the only limit.
  - Prices: seat 30, table 30, bin 40, counter 120, stove 150, register 150.
  - Better-looking variants may come later; they will change looks only, never stats.
- Upgrades are now only the things that aren't on the floor: Pods, floor rows, menu slots and Security.
- **Buy** closes the Shop and opens Arrange with the piece in your hand. **Store** sends it to storage, which is listed in the Arrange panel.
- Furniture sells for half, like décor. These can't be sold:
  - the last counter and the last register
  - a busy stove, a counter with food on it, a seat or table in use
- Save format v14 drops the old furniture upgrade levels; the pieces themselves stay.
- The story step "Buy a second stove" became "Get a third stove on the floor".

## Shop and Bag
- **Shop** is for buying only, with four tabs: Furniture, Décor, Upgrades, Energy. Each piece shows how many you have placed and stored.
- **Bag** (top bar) holds everything you own. Tabs: Equipment, Fashion, Bottles, Workshop.
  - Each piece is a card. The border colour shows its tier: Common grey, Magic blue, Rare gold, Epic purple, Legendary orange. Fashion cards use the piece's colour.
  - A card says who wears it.
  - Clicking a card opens a detail box with every action: Wear on (pick a worker), Take off, Sell. A worn piece must be taken off before selling.
  - Bottles have Use on (pick a worker).
  - The Workshop has Scrap and Chips plus the two crafts. A new piece is shown, already selected, in the Equipment tab.
- **Worker Details:** the Fashion and Equipment tabs show one box per slot. Click a box for a short list of spare pieces that fit, or Take off.

## Balance (40 days × 5 seeds)
The sim bot now buys furniture by the piece, capped at what the old upgrades allowed (4 stoves, 4 counters, 8 seat-and-table pairs).
- About 2,090 customers seated, 93.7% stars.
- The Alley taken around day 11 and Neon Market around day 23, in all 5 runs.
- About 5,230 coins at day 40.

## Second round (branch `click-roles`)
- **Jobs by place:** click a worker, which shows a ring under it and opens its card. Then click a place:
  - a stove: **Chef** at that stove
  - a counter or a table: **Server**
  - a register: **Cashier** at that register
  - the Pod bay: **Rest**

  While a worker is picked, the place you click wins over another worker's head in front of it. The role buttons are gone.
- **One Chef per stove:** a Chef speeds up only its own stove. A stove with no Chef cooks at the base speed. Putting a new Chef at a stove sends the old one to Rest.
- **One Cashier per register:** a new Cashier at a register sends the old one to Rest. A Chef or Cashier whose stove or register is gone takes a free one, or waits.
- **Greeter removed. Appeal now belongs to the Cashier:** working Cashiers' Appeal brings customers in faster (what Greeters used to do), and Cashiers get the XP for each arrival. Hypeform's best role is now Cashier.
- **Starred customers:** everyone leaves right after paying. Starred customers go to a **★ Starred** dropdown under the daily quest tracker, where you can pick one to convert. The list lasts until the café closes. A starred customer still in the pay line can also be clicked.
- **A worker on a trip** (carrying a dish or a batch) finishes it before changing jobs, as before.
- **Save format v15:** Greeters become Servers, stations are bound on load, and starred customers from older saves go to the list.
- **Balance (40 days × 5 seeds):** about 2,100 customers seated, 91.6% stars. The Alley is taken around day 13 and Neon Market around day 25, in all 5 runs, with about 4,070 coins at day 40.
