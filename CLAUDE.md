# NanoBrew Café — Game Design Document

Oct 26, 2026 · @Boss

## Concept

NanoBrew Café (working title) is a 2D single-player café management game where your signature drink turns customers into quirky synthetic staff. It keeps what made Zombie Cafe fun — converting customers into workers, staff upkeep, decorating — and swaps the horror theme for a bright, near-future tech city.

- **Setting:** a neon megacity in the 2040s. You are a rogue bio-engineer running a tiny café in a forgotten alley.
- **The hook:** your NanoBrew drink carries nanobots. A happy customer who drinks it becomes a “Synth” — a cute half-human, half-machine worker whose look and skills come from who they were.
- **The conflict:** MegaBean Corp, a giant coffee chain, owns the city. You grow from one alley to taking over its districts.
- **Platform and model:** premium on Steam first (one-time price), cosmetic-only purchases, no energy, no real-time waiting. Mobile later is possible.
- **Tone:** funny and cozy, light satire of startup and corporate culture, no gore.

## Art direction

Keep Zombie Cafe's readable cartoon look, refreshed with a clean 2026 palette and tech details.

- **Camera:** 2D isometric (3/4 view) on a tile grid, so furniture snaps neatly and the whole café fits on screen.
- **Characters:** chibi proportions — big heads, small bodies, bold dark outlines, flat colours with one shadow tone. Customers are readable at a glance by silhouette.
- **Synths:** each keeps its human silhouette plus tech parts — a glowing visor, a robotic arm, cable “hair”, a screen face showing emotes. Each species has one signature glow colour.
- **World:** warm café interiors against cool neon streets. Holographic menus, vending-machine furniture, LED signs, plants in glass pods.
- **Feedback:** big readable icons above heads (order, mood, battery), juicy pop-ups for tips and conversions.
- **Production:** characters as layered 2D sprites animated with bones (Spine or Unity 2D Animation), so one rig serves many skins — important for cosmetic sales.

## Converting customers into staff

Any customer who leaves fully satisfied can be offered a NanoBrew; that customer becomes a Synth whose species and traits come from the customer type.

1. A customer finishes a meal with high satisfaction and a star appears over their head.
2. You tap them and spend one NanoBrew (brewed from a rare ingredient earned in Night Ops).
3. They walk into a Sync Pod and come out as a Synth, with a random trait from their type's pool.
4. Each Synth needs a free Pod slot. Pods are the staff cap and a main upgrade.
5. Every conversion raises the district's Suspicion (see Night Ops and Suspicion).

| Customer type | Synth species | Best role | Strength | Weakness |
| --- | --- | --- | --- | --- |
| Office worker | Clerkbot | Server | Fast, steady | Gets bored, slows late in shift |
| Gym fan | Bulkform | Raider / carrier | Strong, high battery | Clumsy, breaks dishes |
| Gamer | Glitchling | Chef | Very fast cooking | Random glitches |
| Influencer | Hypeform | Greeter | Attracts more customers | Low work speed |
| Grandparent | Steady-unit | Any | Barely decays | Slow |
| Alien tourist (rare) | Xeno | Chef | Unlocks exotic recipes | Needs special fuel |

Traits add variety on top (examples: Night Owl, Perfectionist, Chatty, Kleptomaniac), so two Clerkbots are never identical.
