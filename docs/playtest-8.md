# Playtest 8 feedback (2026-11-02)

## Café (branch `playtest8-cafe`)
- **A stove stacks dishes:** one cooking and one waiting (`stack` in `pieces.json`; a normal stove holds 2, later stoves can hold more). A waiting dish is paid when it's queued and starts by itself. Its menu can take it off the queue, with a refund.
- **Staff work only once they're there:** a Cashier takes payments, and a Chef cooks, only after walking to the register or stove. Being assigned isn't enough any more.
- **Clicking a stove that already has a Chef** opens its dish menu and says it has a Chef. The worker you picked stays picked, and nobody moves.
- **Raid planner drag and drop:** drag a worker from the list onto a tile, from one tile to another (swapping), or back onto the list to take it out.

## Night (branch `playtest8-night`)
- **Night window:** a centred window, opened and closed at any time with the round **Night** button at the top right.
- **No Start Day dialog:** the night results appear as notes at the top right, and the day starts at once.
- **A raid ends the night:** after the raid, a MegaBean raid on the café (if one comes) is fought, then the day starts.
- **Defenders tonight:** tick who defends in Night Ops. At closing, the 4 with the most battery are ticked (`defender_count`). Defenders who fight don't recharge that night.
- **The defence grid is gone.**

## Fights inside cafés with one door
- **Both kinds of fight:** a raid is fought in the rival café, and a MegaBean raid in your own café, as you've laid it out.
- **Layout:** each café has a front wall with one door. The attackers start on the street and walk in through the door. The fight (and its 45-second limit) starts when the first one reaches the doorway.
- **Defenders:** they wait inside, nearest the door first: tanks, then fighters, fragile, ranged.
- More in `docs/raids.md`.

## Balance (40 days × 5 seeds)
| | Playtest 7 | Raid map | Playtest 8 |
|---|---|---|---|
| Customers seated | ~2,240 | ~1,780 | ~1,660 |
| Left angry | 10 | 123 | 0 |
| Raids won | 39 / 39.2 | 36.6 / 38.6 | 32.2 / 39.6 |
| MegaBean raids lost | 3 / 16.6 | | 11.4 / 15.2 |
| Audits lost | 1.2 / 5 | | 3.4 / 3.4 |
| Alley taken | day 8 | day 8 | day 16.8 |
| Neon Market taken | day 18 | day 21 | day 25.2 |
| Coins at day 40 | ~4,840 | ~7,780 | ~3,400 |

**Home defence got much weaker.** The likely cause: the sim bot raids with everyone but one Synth. The 4 most-charged Synths ticked to defend at closing are mostly the same ones who went on the raid, so very few are left at home. The walk-in fight may also play a part.

Worth deciding:
- whether a Synth who goes on the raid should hand its defender tick to the next most-charged one;
- or whether the default should be more than 4.
