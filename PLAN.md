# PLAN.md — Artifact 4 team plan

Items marked **TODO** need Matthew and Rosie to decide. Anything marked "proposed" is not agreed until
Matthew says so (edit this file in a PR to confirm).

## Team
- Matthew Park (repo owner), Rosie Choi

## Who it is for (not on our team)
- **TODO:** name the person or group (a friend who plays Roblox, a club, a class, ...). The assignment
  needs someone outside our team.
- **TODO:** how we'll find out what they need — e.g. 3–5 questions asked in person/Discord, then a
  playtest with them. Write their answers under "What they told us" below.

## What we're building
Stitch Survival: a co-op survival game for Roblox.

**Direction (Rosie proposed it, Matthew agreed on 2026-11-01):** turn it into a **horror survival** game
with a **hotel hub**. Players arrive in a dark hotel lobby, walk around, and join a numbered guest-room
queue (up to 32 players) for Bomb Hotel or Shark Survival. We still want the user's input once we know
who it is. Pull request: [#1](https://github.com/matthewleepark/StitchSurvival/pull/1), open for review.

- **TODO:** one-sentence goal for the next two weeks, chosen from what the user tells us.

Done on branch `rosie/hotel-hub` (built with Rojo; end-to-end playtest still in progress):
- [x] Hotel lobby hub replaces the toybox Pod
- [x] Game rooms: ten guest-room doors queue for a level, up to 32 players each
- [x] Horror look: darkness, haze, flickering lamps (`Config.Mood`)
- [x] Flashlight (`Config.Flashlight`)
- [x] Normal gravity, jump height and walk speed (`Config.Doll`, `Config.Gravity`)
- [x] Lobby slimmed down and spaced out

Next / candidates:
- [ ] Playtest the whole loop (join room, start round, return to hub), fix bugs
- [ ] Measure part count and frame rate on a phone
- [ ] Horror audio (the sound slots are still toybox sounds)
- [ ] Horror pass on Bomb Hotel and Shark Survival
- [ ] Walk-in guest-room suites behind the doors
- [ ] Simultaneous rooms (needs per-room game state: Phase, Status, Score, level copies)
- [ ] Save Wins / Stickers between sessions
- [ ] Fix `RequestRoll` so it checks you are near the gear machine

## Who owns what (proposed — edit freely)
| Area | Owner |
| --- | --- |
| `src/server/init.server.luau`, `Remotes`, `Score`, `Gear` (round loop and rules) | Matthew |
| `src/server/Levels/BombHotel`, `Bombs`, `SharkSurvival`, `ClockworkShark` | **TODO** (e.g. Matthew = BombHotel, Rosie = SharkSurvival) |
| `src/server/Levels/HotelLobby`, `HotelProps`, `Rooms`, `Mood`, `src/client/Flashlight` (new) | Rosie |
| `src/client/*` (HUD, audio, effects) | Rosie |
| `src/shared/Config.luau` | Shared: small edits only, announce in `LOG.md`, PR touching it gets a second look |

Rosie's hub branch already edited some of Matthew's files (listed in `LOG.md`): he should review those first.

## How we avoid collisions
- Branches: `matthew/<topic>`, `rosie/<topic>`; never work on `main`.
- Pull requests into `main`; the other person reviews and merges.
- **Who merges:** TODO (proposal: the non-author merges after a quick playtest).
- `rosie/hotel-hub` is large; consider splitting it into smaller PRs (movement, mood, hub, rooms).
- Only one person runs `rojo serve` into a given Studio place at a time. Test in your own copy of the place.
- Both agents read this file and `CLAUDE.md` at the start of every session.

## What they told us
- (empty until we ask)

## Milestones
- [ ] Plan agreed and merged to `main`
- [ ] User interviewed; goal chosen above
- [x] Build started (Rosie: hub, rooms, mood, flashlight, movement on `rosie/hotel-hub`)
- [ ] Playtest with the user, collect feedback
- [ ] Hand over (**TODO:** date) and fill in portfolio cards
