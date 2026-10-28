# Playtest 5 feedback (2026-10-28)

All save slots were deleted before this round, as asked.

## Fixes (branch `playtest5-fixes`)
- **HP shown above max (Tally 33/32):** in a fight, HP was rounded up while max HP was rounded to the nearest number. HP now never shows above max.
- **Servers jumping to the stove:** a Server picking up a batch or a dish now walks from where they stand to the stove or counter, then on to where it goes.
- **Pod bay over the back seats:** the Pod bay sits one tile away from the café wall, with a walkway between. Pods are drawn in depth order with everything else.

## No daily menu (branch `free-menu`)
- Customers don't order. A Server brings each seated customer the dish on the counter nearest their seat, and the customer pays that dish's price.
- Any unlocked dish can be cooked on any stove. The night Menu tab, menu slots, the menu-slot upgrade and favourite dishes are gone.
- Clicking a cooking stove lists **Cancel (full refund)** and the other dishes. Picking another dish swaps the batch.
- Mood still drops while customers wait, so fast service still earns the "loved it" mark needed to convert. The mood bars and order bubbles above heads are gone.
- The star icon is now a pulsing cyan ring at the customer's feet. The list at the top left is called **Ready to convert**.
- Save format v16 drops the menu. Seated customers in old saves forget their order.

## Café size (branch `cafe-size`)
- A new café is **6×6**. The Floor upgrade makes it square: 8, 9, 10, 12, 14, 15, 16, 18, then 20 tiles. Costs start at 500 and grow ×1.5 per level.
- Starter kit: 1 stove, 3 counters, 1 bin, 1 register, and 3 tables with seats.
- Customer arrivals follow the café's size. A 6×6 café gets 0.75× the old base rate, 8×8 gets 1×, and 20×20 gets 2.5×, all times the Cashiers' appeal. More seats no longer bring customers in faster.
- Speed, cooking, appeal, power and HP grow 15% per level instead of 8%.
- The story step "Get a third stove" became "Get a second stove on the floor".
- Save format v17 saves the floor's width. Older cafés were 8 across.

## Save slots (branch `save-slots`)
- The main menu shows each save's day, district, coins, staff and when it was saved. Each save has a **Delete** button, with a confirmation.
- The pause menu's save buttons say what they would overwrite.

## UI (branch `ui-cleanup`)
- Daily quests can be claimed from the list at the top left. It is shown by day and by night.
- The Workshop moved from the Bag to the Shop, as a fifth tab.
- No hover text anywhere. Info has a new **Help** tab, first in the row, covering cooking, jobs, converting, quests, the Shop, Arrange, the Bag, resources, Auto and windows.

## Balance (40 days × 5 seeds)
The sim bot cooks the most profitable dish whenever there isn't enough food on the way for everyone waiting.
- About 1,800 customers seated, down from about 2,040, because the small café gets fewer customers early. 84% loved it.
- About 12.6 conversions per run.
- The Alley taken around day 12 and Neon Market around day 20, in all 5 runs.
- About 5,320 coins at day 40, up from about 3,940. The floor reaches about 17×17.
