# Raids from the map

## How it plays
1. At night, go to **Night Ops → Open map**.
2. The **district map** shows your café and the district's MegaBean cafés as pins. Each pin shows:
   - how many guards and their **average level**;
   - the loot, plus Influence for rivals;
   - why it can't be raided, if so: already raided tonight, cooling down for *n* nights, or the flagship locked until you have enough Influence.
3. Click a café to open the **raid screen**. The enemy café is drawn as it is: its counters, stove, tables, seats and décor, its front wall with one **door** (the green tile), and its guards waiting inside. In front of it are your **3 rows** on the street.
   - Drag a worker from the list on the left onto a tile in your rows (or pick it, then click the tile). One already there swaps places.
   - Drag a squad member to another tile, or back onto the list to take it out.
   - Up to 4 in the squad (`raid_squad_max`).
4. **Start raid:** your squad walks in through the door. The fight starts when the first of them is in the doorway. Then a results screen (loot, XP).
5. **One raid a night, and it ends the night:** a MegaBean raid on your café (if one comes) is fought next, then the day starts.

## The fight inside the café
The board is the café floor (8 wide; 4 rows deep, 5 for a flagship), its front wall (one row, the door in the middle) and your 3 rows outside.
- **The door:** the attackers start on the street and walk in through it. Nobody fights until the first attacker reaches the doorway; the 45-second limit counts from then. An attacker still outside keeps walking in, and only fights a defender who has come out to the door or beyond.
- **Obstacles:** furniture and the wall block walking, so units path round them.
- **Cover:** a unit standing next to furniture takes 25% less from attacks made from more than one tile away (`cover` in `data/combat.json`). The wall gives no cover.
- **Guards:** placed inside by class, each on the free tile nearest the door: tanks first, then fighters, fragile, ranged.

## MegaBean raids on your café
Fought the same way, inside **your own café** as you've laid it out, with its door (the front-right corner). MegaBean comes from the street.
- **Who defends:** tick them under **Night Ops → Defenders tonight**. At closing the 6 with the most battery are ticked (`defender_count`).
- They wait inside, tanks nearest the door.
- Defenders who fought don't recharge that night.

## Guard levels
Each guard has a `level` in `data/districts.json`. It counts as one level higher for every 15% the café has grown since the district opened (`rival_growth_per_day`). Flagships don't grow. The map shows the average.

## Hand-making a café's layout
By default each café's layout is **generated** from its id, so it's the same on every visit:
- a stove and counters along the back;
- tables with their seats;
- a little décor;
- the front row clear, and every free tile reachable from the door.

To design one yourself, add a `layout` to that café in `data/districts.json`:

```json
{"id": "megabean_kiosk", "defenders": [...], "loot_coins": 60, "loot_cores": 1, "influence": 1,
	"layout": {"rows": 4, "pieces": [
		{"piece": "stove", "cell": [1, 0]},
		{"piece": "counter", "cell": [2, 0]},
		{"piece": "table", "cell": [3, 2]},
		{"piece": "seat", "cell": [4, 2]},
		{"piece": "potted_fern", "cell": [7, 1]},
		{"piece": "led_sign", "cell": [5, 0], "rotated": false}
	]}}
```

- `rows`: how deep the café is. Row 0 is the back wall; the last row is just inside the front wall.
- `door`: the door's column (optional; the middle by default).
- `pieces`: any piece id from `data/pieces.json` (`cell` is column, row; `rotated` turns 2×1 pieces).
- The café is 8 columns wide (0–7).
- Keep the tile inside the door clear and leave a path to every free tile, so the guards and your squad can reach each other.
- Remove the `layout` to go back to the generated one.

The code is in `src/systems/raid_field.gd`.

## Balance check (40 days × 5 seeds, the sim bot raiding inside the cafés)
- Raids won 36.6 of 38.6. Both districts taken in every run (Alley around day 8, Neon Market around day 21).
- About 7,780 coins at day 40.
- The café side moved: about 1,780 customers seated and 123 leaving angry, against about 2,240 and 10 the round before. Nothing in the café changed, so it is most likely the knock-on of raids going differently (cores, conversions, staff). Worth watching in play.

