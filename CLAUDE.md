# NanoBrew Bar — Game Design Document

Oct 26, 2026 · @Boss · retheme to a cyberpunk bar on Nov 3, 2026

## Concept

NanoBrew Bar (working title; first called NanoBrew Café) is a 2D single-player bar management game where your signature drink turns customers into quirky cyborg staff. It keeps what made Zombie Cafe fun — converting customers into workers, staff upkeep, decorating — and swaps the horror theme for a neon cyberpunk city.

- **Setting:** a neon megacity in the 2040s. You are a rogue bio-engineer running a tiny dive bar in a forgotten alley.
- **The hook:** your NanoBrew drink carries nanobots. A happy customer who drinks it becomes a “Synth” — a cute half-human, half-machine worker whose look and skills come from who they were.
- **The conflict:** MegaBean Corp, a giant drinks chain, owns the city. You grow from one alley to taking over its districts.
- **Platform and model:** premium on Steam first (one-time price), cosmetic-only purchases, no energy, no real-time waiting. Mobile later is possible.
- **Tone:** funny and gritty-cute, light satire of startup and corporate culture, no gore.

## Art direction

A cyberpunk dive bar with chibi cyborgs: Zombie Cafe's readable cartoon look, in a dark neon world. The detailed rules are in `docs/art-guide.md`.

- **Camera:** 2D isometric (3/4 view) on a tile grid, so furniture snaps neatly and the whole bar fits on screen.
- **Characters:** chibi cyborgs — big heads, small bodies, outlines in a darker shade of each colour. Customers wear street style with small implants (LED tattoos, cheek plates, ear jacks) and are readable at a glance by silhouette.
- **Synths:** each keeps its human silhouette plus heavy chrome — a visor, a mechanical arm, glowing seams. Each species has one signature glow colour.
- **World:** a dark dive bar against rainy neon streets: chrome bar stools, a neon-edged bar counter, drink mixers with glowing tanks, back-bar shelves of glowing bottles, graffiti, vending machines, a DJ booth. Grime and neon (magenta, cyan, acid green, amber) over near-black and steel.
- **MegaBean:** black-and-red corporate enforcers with red visor strips and the bean logo.
- **Feedback:** big readable icons above heads (order, mood, battery), juicy pop-ups for tips and conversions.
- **Production:** vector parts animated on one shared cut-out rig (in Godot), so one rig serves every character and skin — important for cosmetic sales.

## Converting customers into staff

Any customer who leaves fully satisfied can be offered a NanoBrew; that customer becomes a Synth whose species and traits come from the customer type.

1. A customer finishes a drink with high satisfaction and a star appears over their head.
2. You tap them and spend one NanoBrew (brewed from a rare ingredient earned in Night Ops).
3. They walk into a Sync Pod and come out as a Synth, with a random trait from their type's pool.
4. Each Synth needs a free Pod slot. Pods are the staff cap and a main upgrade.
5. Every conversion raises the district's Suspicion (see Night Ops and Suspicion).

| Customer type | Synth species | Best role | Strength | Weakness |
| --- | --- | --- | --- | --- |
| Office worker | Clerkbot | Server | Fast, steady | Gets bored, slows late in shift |
| Gym fan | Bulkform | Raider / carrier | Strong, high battery | Clumsy, drops drinks |
| Gamer | Glitchling | Bartender | Very fast mixing | Random glitches |
| Influencer | Hypeform | Greeter | Attracts more customers | Low work speed |
| Grandparent | Steady-unit | Any | Barely decays | Slow |
| Alien tourist (rare) | Xeno | Bartender | Unlocks exotic drinks | Needs special fuel |

Traits add variety on top (examples: Night Owl, Perfectionist, Chatty, Kleptomaniac), so two Clerkbots are never identical.
