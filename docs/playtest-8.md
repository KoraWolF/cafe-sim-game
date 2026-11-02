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
- **Defenders tonight:** tick who defends in Night Ops. At closing, the 6 with the most battery are ticked (`defender_count`). Defenders who fight don't recharge that night.
- **The defence grid is gone.**

## Fights inside cafés with one door
- **Both kinds of fight:** a raid is fought in the rival café, and a MegaBean raid in your own café, as you've laid it out.
- **Layout:** each café has a front wall with one door. The attackers start on the street and walk in through the door. The fight (and its 45-second limit) starts when the first one reaches the doorway.
- **Defenders:** they wait inside, nearest the door first: tanks, then fighters, fragile, ranged.
- More in `docs/raids.md`.

## Balance (40 days × 5 seeds)
| | Playtest 7 | Raid map | Playtest 8, 4 defenders | Playtest 8, 6 defenders |
|---|---|---|---|---|
| Customers seated | ~2,240 | ~1,780 | ~1,660 | ~1,580 |
| Left angry | 10 | 123 | 0 | 0.2 |
| Raids won | 39 / 39.2 | 36.6 / 38.6 | 32.2 / 39.6 | 29.8 / 39.6 |
| MegaBean raids lost | 3 / 16.6 | | 11.4 / 15.2 | 3.2 / 13 |
| Audits lost | 1.2 / 5 | | 3.4 / 3.4 | 3.2 / 3.2 |
| Alley taken | day 8 | day 8 | day 16.8 | day 17 |
| Neon Market taken | day 18 | day 21 | day 25.2 | day 20 |
| Coins at day 40 | ~4,840 | ~7,780 | ~3,400 | ~7,360 |

**Home defence with 4 defenders was much weaker.** The sim bot raids with everyone but one Synth, and the 4 most-charged Synths ticked at closing were mostly the ones who went on the raid, so few stayed home.

**The default is now 6** (`defender_count`). MegaBean raids lost fell back to about the old level (3.2 of 13).

## Tuning after the door fights (branch `tune-doors`)
Three tries, each 40 days × 5 seeds:

| | 6 defenders | A | B | C (kept) |
|---|---|---|---|---|
| Change | | Audit strength 1.5 → 1.2, guard growth 3% → 2% a day | + Audit strength 1.0 | Audit squad 4 → 3 at strength 1.2, guard growth 2% |
| Raids won | 29.8 / 39.6 | 31.6 / 39.6 | 32.4 / 39.6 | 32.0 / 39.6 |
| MegaBean raids lost | 3.2 / 13 | 3.8 / 13.2 | 4.2 / 14 | 4.6 / 13 |
| Audits lost | 3.2 / 3.2 | 2.8 / 3.2 | 2.0 / 3.4 | 1.8 / 3.2 |
| Alley / Neon Market taken | day 17 / 20 | day 14 / 20 | day 14 / 27 | day 14 / 20 |
| Coins at day 40 | ~7,360 | ~3,990 | ~3,240 | ~4,940 |

Kept C: `audit_size` 3, `audit_strength` 1.2, `rival_growth_per_day` 0.02.

- **Raids:** won about 80% (the sim bot picks targets with a rough power/HP guess, so it takes fights the door makes harder). The Alley falls 3 days sooner.
- **Audits:** still lost a bit over half the time, and weaker Audits barely change that. They come at high Suspicion, on nights the bot raids with its 4 strongest, so only the weaker Synths are home to defend. Only about 16 Audits happen across all runs, so this number is noisy.
- If that feels wrong in play, the fix is in who defends, not the numbers: a Synth who goes on the raid could hand its defender tick to the next most-charged one.
