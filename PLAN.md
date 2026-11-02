# PLAN.md — Artifact 4 team plan

Items marked **TODO** need Matthew and Rosie to decide before anyone builds. This is a draft.

## Team
- Matthew Park (repo owner), Rosie Choi

## Who it is for (not on our team)
- **TODO:** name the person or group (a friend who plays Roblox, a club, a class, ...).
- **TODO:** how we'll find out what they need — e.g. 3–5 questions asked in person/Discord, then a
  playtest with them. Write their answers under "What they told us" below.

## What we're building
Stitch Survival: a co-op survival game in handmade scrapbook style.
- **TODO:** one-sentence goal for the next two weeks, chosen from what the user tells us.
- Candidate tasks (pick from these once we hear from them):
  - [ ] Fill empty sound slots in `Config.Sounds`
  - [ ] Add a new level or hazard
  - [ ] More gear / cosmetics in the Pod
  - [ ] Difficulty and balance pass in `Config.luau`
  - [ ] Mobile controls / performance check

## Who owns what (proposed — edit freely)
| Area | Owner |
| --- | --- |
| `src/server/init.server.luau`, `Remotes`, `Score`, `Gear` (round loop and rules) | Matthew |
| `src/server/Levels/*` | **TODO** (split by level, e.g. Matthew = BombHotel, Rosie = SharkSurvival) |
| `src/client/*` (HUD, audio, effects) | Rosie |
| `src/shared/Config.luau` | Shared: small edits only, announce in `LOG.md`, PR touching it gets a second look |

## How we avoid collisions
- Branches: `matthew/<topic>`, `rosie/<topic>`; never work on `main`.
- Pull requests into `main`; the other person reviews and merges.
- **Who merges:** TODO (proposal: the non-author merges after a quick playtest).
- Only one person runs `rojo serve` into a given Studio place at a time. Test in your own copy of the place.
- Both agents read this file and `CLAUDE.md` at the start of every session.

## What they told us
- (empty until we ask)

## Milestones
- [ ] Plan agreed and merged to `main`
- [ ] User interviewed; goal chosen above
- [ ] Build (each person on their own branch)
- [ ] Playtest with the user, collect feedback
- [ ] Hand over (**TODO:** date) and fill in portfolio cards
