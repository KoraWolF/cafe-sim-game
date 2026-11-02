# Playtest 7 feedback (2026-11-02, a real player)

## Controls and rules (branch `playtest7-quick`)
- **Space pauses and resumes** at the speed you had. It used to be swallowed by whichever button last had focus, so it seemed to do nothing. Space is now caught before the buttons, except while typing a name.
- **3× replaces 4×** as the top speed (keys 1, 2, 3). Old saves at 4× load at 3×.
- **The door stays clear:** nothing can be placed on the tile just inside the door (front-right corner); the game says why.
- **A crowded café slows arrivals:** with more customers inside (seated or paying) than tables, the gap between arrivals doubles (`crowded_arrival_slowdown` in `balance.json`).
- **A Chef stays with its cooking dish:** it can't be moved to another stove until the dish is done. Another job, or Rest, is fine.
- **Café ↔ Pod swap:** pick a worker in the café, then click one resting in the Pod bay (or the other way round). The resting one takes the job and station, and the other goes to rest. Two workers in the café still just switch which one is picked.

## Night (branches `night-rest`, `night-screens`)
- **At closing everyone walks to their Pod** and recharges fully at night (with Energy). In the morning each goes back to the job and station it had. A worker resting at closing stays resting. A job given at night replaces the one it would go back to.
- **The raid is confirmed at End Night.** The Plan raid button is gone: pick a target and a squad in Night Ops, then End Night asks *Raid … tonight?*, with **Raid and end night** or **End night without raid**.
- **Warning screen** before a MegaBean raid on the café or a Corporate Audit: how many are coming and who defends (or that nobody can).
- **Results screen** after every battle: Victory or Defeat, loot or losses (coins, cores, Influence, salvage, items, a new dish, a district taken), and the XP each fighter earned, with any level-ups. Then the night report as before.

## Workers list (branch `workers-list`)
A **Workers** panel on the left, under the quests. Its header folds it away. For each worker it shows:
- the name, in its species colour: click it to pick the worker, just like clicking it in the café;
- a job menu: a Chef or Cashier takes a free stove or register;
- the battery %.

## Balance (40 days × 5 seeds)
- About 2,240 customers seated. Only about 10 leave angry (was about 124), because a crowded café slows new arrivals.
- About 17 conversions per run.
- Raids won 39 of 39.2.
- MegaBean raids on the café: 3 of 16.6 lost. Audits: 1.2 of 5 lost.
- Alley taken around day 8, Neon Market around day 18, in all 5 runs.
- About 4,840 coins at day 40.
