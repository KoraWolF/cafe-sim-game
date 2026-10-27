# Playtest 1 feedback and plan (2026-10-27)

Feedback from @Boss's first playtest, with the agreed answers.

## Answers to the "what does it do" questions

- **Security** (upgrade): every Synth that stays home and fights off a night raid gets +15 HP per level. It matters only when MegaBean raids the café or an Audit comes.
- **Chef** (role): makes every stove cook faster. A chef adds its cooking stat to the kitchen's speed. A Glitchling chef adds +60%, so a 20 s coffee takes about 12.5 s; it sometimes glitches and skips a second.
- **Greeter** (role): brings customers in more often. The time between arrivals is divided by 1 + the greeters' appeal; a Hypeform adds +50%.
- These are tooltips today, which is too hidden. Branch 1 puts them on the Synth card.

## Agreed changes, in four branches

1. **`playtest-fixes`** (UI and UX):
   - Dim the background behind Settings and other pop-ups.
   - Confirm before spending NanoBrew on a customer.
   - The Synth card explains the current role, the trait and what each stat does.
   - The security upgrade and the night-ops screen explain what security does.
   - **Customer hover card:** type, order, mood, patience, and "Converts to: <species>" with their trait. The trait is rolled when the customer arrives, so you can choose who to convert. This is a small logic change.
   - Sync Pods start on the left side of the café.
   - Starred customers queue at a **call board** beside the café, away from the tables.
   - **A door:** customers walk in through it and walk out again. Movement is visual only; the rules don't change.
2. **`counter-piece`:** a real counter (2×1 furniture). Ready dishes are stacked on it, and servers walk to it to pick up. Save format v6 places a counter in older saves.
3. **`decor-aura`:** décor works in a range. Each piece boosts only the seats within N tiles, shown as a glowing range while placing. A customer's mood uses the Vibe around their own seat. This moves seat assignment into the game logic and needs a balance re-check.
4. **`synth-outfits`:** fashion progression. Cosmetic outfits and accessories for Synths, unlocked by progress, with no stat effect. **Questions to ask first:** how outfits are unlocked, which slots there are, and where they're equipped.

Art: see `docs/art-guide.md` for how to make customer and Synth models.
