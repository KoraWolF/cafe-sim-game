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

## Balance (40 days x 5 seeds, the sim bot raids every night it can)
| | Before | Now |
| --- | --- | --- |
| Star rate | 98% | 83% |
| Left angry | 2 | 91 |
| Income | 8,120 | 6,040 |
| Raids won | 37.6 of 39.2 | 33.8 of 40 |
| Defences lost | 2.4 of 14.8 | 3.4 of 13.6 |
| Alley taken | day 6 | day 10 |
| Workers at the end | 18.8 | 18 |

The game is harder, and both changes add to it. With the new HP rules and the old cooking, the sim gave 50 angry customers and a 92% star rate. The longer cooks took that to 91 and 83%. Income fell with the HP rules (5,944) and barely changed with the cooking.

A bot that cooks 8 servings ahead did much worse (356 angry, 59% stars, 11 workers), so it was dropped. The cause isn't known yet. One idea to test: each counter holds one dish, so extra dishes may fill the counters.

No values were changed after these runs. The Neon Market still falls within 40 days in all 5 seeds.
