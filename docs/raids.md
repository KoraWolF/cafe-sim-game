# Raids from the map

## How it plays
1. At night, go to **Night Ops → Open map**.
2. The **district map** shows your café and the district's MegaBean cafés as pins. Each pin shows:
   - how many guards and their **average level**;
   - the loot, plus Influence for rivals;
   - why it can't be raided, if so: already raided tonight, cooling down for *n* nights, or the flagship locked until you have enough Influence.
3. Click a café to open the **raid screen**. The enemy café is drawn as it is: its counters, stove, tables, seats and décor, and its guards where they'll stand. In front of it are your **3 rows** on the street.
   - Pick a worker from the list on the left, then click a tile in your rows. One already there swaps places.
   - With nobody picked, click a squad member's tile to take them out.
   - Up to 4 in the squad (`raid_squad_max`).
4. **Start raid** fights at once. Then a results screen (loot, XP), and you're back at the night hub.
5. **One raid a night.** End Night then handles the rest: MegaBean raids on your café, Audits, recharge, income.

Your squad's spots are kept as their formation spots, so they also count when defending your café. The **Home defence formation** board in Night Ops sets those spots directly.

## The fight inside the café
The board is the café floor (8 wide; 4 rows deep, 5 for a flagship) plus your 3 rows outside.
- **Obstacles:** furniture blocks walking, so units path round it.
- **Cover:** a unit standing next to furniture takes 25% less from attacks made from more than one tile away (`cover` in `data/combat.json`).
- **Guards:** placed inside by class. Tanks and fighters stand near the door, ranged at the back.

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

- `rows`: how deep the café is. Row 0 is the back wall; the last row is the door side.
- `pieces`: any piece id from `data/pieces.json` (`cell` is column, row; `rotated` turns 2×1 pieces).
- The café is 8 columns wide (0–7).
- Keep the door row clear and leave a path to every free tile, so the guards and your squad can reach each other.
- Remove the `layout` to go back to the generated one.

The code is in `src/systems/raid_field.gd`.

## Balance check (40 days × 5 seeds, the sim bot raiding inside the cafés)
- Raids won 36.6 of 38.6. Both districts taken in every run (Alley around day 8, Neon Market around day 21).
- About 7,780 coins at day 40.
- The café side moved: about 1,780 customers seated and 123 leaving angry, against about 2,240 and 10 the round before. Nothing in the café changed, so it is most likely the knock-on of raids going differently (cores, conversions, staff). Worth watching in play.

