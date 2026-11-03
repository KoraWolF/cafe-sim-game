# Raids from the town map

## Towns
The city is split into towns, taken one after another (`data/districts.json`, in order):

| Town | Bars | Boss | Guard levels |
| --- | --- | --- | --- |
| Alley (start) | Kiosk, Cart, Stand, Express, Corner | Alley Flagship | 1–4 |
| Neon Market | Drive, Arcade, Lounge, Club, Rooftop | Tower | 3–7 |
| Chrome Heights | Lab, Plaza, Casino, Spire, Vault | HQ | 6–10 |

- **Opening the boss:** beat every bar in town once (each first win marks the bar **beaten**), and the boss bar opens.
- **Taking the town:** beat the boss and the town is yours. It pays its income every night, and the next town opens with fresh Suspicion.
- **Beaten bars:** they stay on the map and can be raided again for loot after their cooldown. They don't count again.
- **Influence:** it's still earned, but no longer opens anything.

## How it plays
1. At night, go to **Night Ops → Open map**.
2. The **town map** is a neon town about two screens wide.
   - **Moving around:** drag it with the mouse, or scroll (Shift + scroll moves sideways).
   - **The bars:** each MegaBean bar is a red-signed building, and the boss a taller tower with a crown. Beaten bars carry a green check, and your own bar has a cyan sign.
   - **Minimap:** the corner minimap shows every bar and what's on screen; click it to jump there.
   - **Town tabs:** the tabs at the top show the towns. Ones you've taken can be looked at, and the next ones are locked.
   - **A bar's card:** click a bar to see its guards and their **average level**, its loot, whether it's beaten, and why it can't be raided, if so: already raided tonight, cooling down, or the boss locked until every bar is beaten.
3. Press **Raid this bar** on the card to open the **raid screen**. The enemy café is drawn as it is: its counters, stove, tables, seats and décor, its front wall with one **door** (the green tile), and its guards waiting inside. In front of it is the street: 2 open rows, then your **3 rows**.
   - Drag a worker from the list on the left onto a tile in your rows (or pick it, then click the tile). One already there swaps places.
   - Drag a squad member to another tile, or back onto the list to take it out.
   - Up to 4 in the squad (`raid_squad_max`).
4. **Start raid:** the guards come out of the door to meet your squad. The fight starts when the first guard steps outside, and it's fought on the street. Then a results screen (loot, XP).
5. **One raid a night, and it ends the night:** a MegaBean raid on your café (if one comes) is fought next, then the day starts.

## The fight on the street
The board is the café floor (8 wide; 4 rows deep, 5 for a flagship), its front wall (one row, the door in the middle), 2 rows of open street (`STREET_ROWS` in `raid_field.gd`) and the attackers' 3 rows.
- **The door:** the defenders wait inside and the attackers wait in formation. The attackers stay put until every defender is out; the 45-second limit counts from then.
- **Coming out:** the defenders all walk out first (ranged too), each as far toward the attackers as the street goes; the fight starts once they are all out and in place (after 20 seconds at most).
- **On the street:** attackers never go into the café, so the fight happens outside.
- **Obstacles:** furniture and the wall block walking, so units path round them.
- **Cover:** a unit standing next to furniture takes 25% less from attacks made from more than one tile away (`cover` in `data/combat.json`). The wall gives no cover.
- **Guards:** placed inside by class, each on the free tile nearest the door: tanks first, then fighters, fragile, ranged.

## MegaBean raids on your café
Fought the same way, in front of **your own café** as you've laid it out, with its door (the front-right corner). MegaBean waits on the street and your defenders walk out to meet it.
- **Who defends:** tick them under **Night Ops → Defenders tonight**. At closing the 6 with the most battery are ticked (`defender_count`). A worker who goes on a raid hands its tick to the most-charged one staying home.
- They wait inside, tanks nearest the door.
- Defenders who fought get back only half their missing battery that night (`defender_recharge`).

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

