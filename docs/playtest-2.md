# Playtest 2 feedback and fixes (2026-10-27)

| Note | What changed |
| --- | --- |
| Bug: customers got stuck at the door | The door is now a short lane: walkers go to its near end, through it, then on (`src/ui/walk.gd`). Before, a customer just past the door point was sent back to it every frame. A test reproduces the old jiggle and checks every seat is reached. |
| What is worker power? | Power is how hard a Synth hits in raids and defence: species base × (1 + 8% per level above 1) + trait bonus (Night Owl +3). Each hit deals power × battery (×0.5 below 20%, nothing when empty) × a random 0.8–1.2. Bases: Clerkbot 6, Bulkform 14, Glitchling 8, Hypeform 5, Steady-unit 7, Xeno 10. The Synth card shows it, with this formula as a tooltip. |
| Pods outside, on the left | Sync Pods left the floor for a **Pod bay** outside the front-left wall. The Pod upgrade adds one to the bay, and resting Synths stand in their Pods. Save format v7 turns placed and stored Pods into bay Pods. |
| Rename workers | Click the name on the Synth card, type and press Enter (up to 20 letters). |
| Counter: 1x1, one dish each; the server carries the batch to the closest free counter | A finished batch now **waits on its stove** ("Ready ×N"). An idle server carries it (2 s at speed 1) to the nearest counter that's empty or already holds that dish. If none is free, the batch stays and the stove can't cook again. Serving waiting customers comes before carrying. A new game has two 1×1 counters; the **Counter** upgrade buys more. A counter holding dishes, or the last counter, can't be picked up. Save format v8 spreads an older save's ready dishes over the counters. |

Balance (40 days × 5 seeds, carry 2 s): about 2,720 customers seated, 97.4% stars, the Alley taken on day 12–17, Neon Market in 4 of 5 runs (day 20–27), about 6,900 coins at day 40. With 3 s carries: 2,240 seated, the Alley on day 13–17, Neon Market in only 3 of 5 runs. The extra trips made servers the bottleneck.
