# Playtest 9 feedback (2026-11-02)

## Fixes (branch `playtest9-bugs`)
- **Pause stops everyone:** the Pause button (speed 0) used to let walkers keep going at 1×. Now nobody walks while it's paused.
- **The door can't be blocked:** a piece can't be placed or moved where it would cut off anything people walk up to (seats, stoves, counters, bins, registers) that could be reached from the door before. A seat counts as reached across its own table. The game says *That would block the way*.
- **Resting workers vs workers after the night:** recharging works the same for everyone. Two things caused the difference:
  - A resting worker has the most battery at closing, so it's usually ticked to defend, and defenders who fought didn't recharge at all.
  - In the save checked, Energy was 0, so nobody recharged that night (the results say so).
  - **Change:** defenders who fought now get back half their missing battery (`defender_recharge`).
- **Customers leave by the shortest way:** the pay line used to run straight down from the register, through the front wall. Anyone in the line outside the floor walked round the café corner instead of through the door. The line is now on the floor (see below).
- **Night results can be closed** with the × at their top right.

## Customers and the pay line
- **No crowded-arrival slowdown:** customers arrive at their normal speed again.
- **The pay line** holds 4 per register (`pay_line_max`). It stands along the walk from the register back to the door, so it never goes through a wall.
- **When the line is full** (for example, no Cashier working), customers who finished eating wait at their table. Their seat stays taken, so fewer new customers can sit.
- **After waiting too long** (`pay_wait_seconds` = 30, times their patience), they leave angry without paying.

## Street fights (branch `playtest9-street`)
- **Raids and MegaBean raids** are both fought on the street in front of the café. The café stays on screen.
- **The street:** in front of the wall are 2 rows of open street, then the attackers' 3 rows.
- **How it starts:** the attackers wait in formation and the defenders walk out of the door. The fight (and its 45-second clock) starts when the first defender steps outside.
- **Attackers never go in.** A defender still inside keeps walking out, fighting only an attacker already in reach.

## Balance (40 days × 5 seeds)
| | Playtest 8 (v1.5.2) | Playtest 9 |
|---|---|---|
| Customers seated | ~1,730 | ~1,930 |
| Left angry | 0.6 | 1.8 |
| Raids won | 34 / 39.6 | 32.2 / 40 |
| MegaBean raids lost | 3 / 15.2 | 0.8 / 15.6 |
| Audits lost | 0 / 3.6 | 0 / 3.6 |
| Alley / Neon Market taken | day 14 / 24 | day 6.4 / 14.4 |
| Coins at day 40 | ~6,570 | ~6,490 |

**Defending is now very easy.** MegaBean raids are almost never lost, and both districts fall much sooner. Defenders get the security HP bonus and half recharge, and the attackers no longer have the door to fight through.

Worth tuning if it feels the same in play:
- stronger MegaBean raids (`defense_power_per_day`, `defense_hp_per_day`);
- or a stronger Audit (`audit_strength` 1.2 → 1.5).

## After playtest 9 (branch `tune-street`)
- **Ranged defenders walk out first:** nobody fights from inside the café any more. Ranged defenders used to stop at the door and shoot once attackers came within 3 tiles.
- **Resting by Pod:** each Pod has its own hitbox. Click a free Pod to rest the picked worker in exactly that Pod; a resting worker clicked onto another free Pod moves there. Clicking a Pod in use is like clicking its worker (a café worker picked swaps with it). Blank space in the bay does nothing.
- **Tuning:** MegaBean raiders grow faster (`defense_power_per_day` 0.5 → 0.8, `defense_hp_per_day` 2 → 3), and Audits are stronger (`audit_strength` 1.2 → 1.3; 1.5 lost 81% of Audits).

| | Playtest 9 | Tuned + walk-out rule |
|---|---|---|
| Customers seated | ~1,930 | ~2,200 |
| Left angry | 1.8 | 16.4 |
| Raids won | 32.2 / 40 | 40 / 40 |
| MegaBean raids lost | 0.8 / 15.6 | 3.4 / 14.8 |
| Audits lost | 0 / 3.6 | 1.6 / 5.4 |
| Alley / Neon Market taken | day 6.4 / 14.4 | day 8 / 16 |
| Coins at day 40 | ~6,490 | ~25,900 |

**Raids are now always won,** and coins pile up from the loot. Rival guards come out of their door one at a time into a squad that is already waiting, and their ranged guards can no longer shoot from inside. Worth tuning next: stronger guards (`rival_growth_per_day`, or guard power and HP in `districts.json`), or the guards could all come out before the fight starts.
