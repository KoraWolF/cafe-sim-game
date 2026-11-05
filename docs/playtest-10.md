# Playtest 10 feedback (2026-11-05)

## Fixes
- **Night menu over a bottom menu:** the Night button now shows while the Shop, Bag, Quests or Arrange is open. It closes that menu and opens the night window.
- **Raid plan drag:** you can grab a worker by its whole body on the board, not only by the tile under its feet. The worker nearest the camera wins when they overlap.
- **Bartenders stand in front of the mixer:** they stand at its front corner on screen, or in front of it when that tile is taken.

## Bottom menus
- **Resize:** drag the top edge of the Shop, Bag or Arrange menu. Each menu keeps its own height, from 20% to 75% of the screen. A small menu scrolls.
- **Drag to store:** in Arrange, drag a piece onto the menu and let go to store it. Clicking the menu while holding a piece does the same. Neither asks first.

## Walls
- **The grid:** each wall has one column per floor tile, and each column is 3 cells high (`Walls.ROWS`).
- **The starter bar** has bare cracked concrete and no wall décor.
- **The Walls tab** in the shop sells panels and décor. Place them from Arrange by clicking a wall.
- **Panels** paint one whole column (1 x 3). A new panel sends the old one back to storage. A panel can be replaced but not taken down to bare concrete.
- **Wall décor** hangs on cells. The Rainy Window is 2 cells tall and the rest are 1. Click a piece on the wall to take it down.
- **Vibe:** panels and décor add Vibe to seats within `decor_range` of their wall tile, like floor décor.
- Saves are now version 22 and keep the walls in `state.walls`.

## Defenders
- **Default ticks:** at closing, every worker above 70% battery is ticked (`defender_battery_share`).
- **A ticked defender can't raid:** it's greyed out in the raid plan. Untick it in Night Ops first. Raiders no longer hand their tick on.

## Worker HP
- **Current and max:** HP no longer refills at the end of the night. Damage from raids, defences and audits stays. Security's bonus HP takes the damage first.
- **Rest is free:** a worker resting in its Pod recovers 0.2% of max HP each shift second (`pod_heal_share`). Each night recovers 30% (`night_heal_share`), or half that for workers who fought.
- **At 0 HP** a worker is knocked out. Its battery drains to 0 and it's forced into its Pod for 2 minutes of shift time at level 1, plus 30 seconds per level above that (`knockout_seconds`, `knockout_seconds_per_level`).
- **When the timer ends** it has half its HP and battery (`knockout_return_share`) and goes back to the job it had.
- **While knocked out** it can't work, raid or defend, and recovers nothing.

## Cooking
Every dish takes 1.5x as long to cook and gives 2x the servings for 2x the cost, so a stove makes about a third more per minute.

## Balance (30 days x 10 seeds, the sim bot raids every night it can)
The first numbers for this playtest were wrong. After knockouts the sim bot could end up with no Server and never fix it, so whole runs served nobody. That made the game look harder than it is and made cooking ahead look bad. The bot now keeps a Server, and these numbers replace the earlier ones.

| | Normal early raids | Fewer early raids (now in the game) | Fewer early raids, bot cooks ahead |
| --- | --- | --- | --- |
| Star rate | 92% | 95% | 99% |
| Left angry per run | 12.4 | 10.5 | 8.2 |
| Raids won | 84% | 87% | 82% |
| MegaBean raids, days 1-10 | 29 (6 held) | 9 (3 held) | 18 (6 held) |
| MegaBean raids held, all days | 76% | 82% | 74% |
| Alley taken | 10 of 10, day 8.3 | 10 of 10, day 8.6 | 10 of 10, day 8.8 |
| Neon Market taken | 9 of 10 | 9 of 10 | 8 of 10 |
| Workers at the end | 16.1 | 15.9 | 15.8 |

- **Fewer early raids:** MegaBean's chance is a quarter of normal on day 1 and all of it by day 11.
- **Cooking ahead helps:** keeping 8 servings ready gave the best service. The bot still doesn't do it by default, so the table's middle column stays comparable with earlier runs.
- **Chrome Heights** wasn't taken in any run within 30 days.
