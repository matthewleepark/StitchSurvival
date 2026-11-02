# LOG.md

Newest entry at the top. One entry per working session: date, who, what changed, what's next, blockers.
"Rosie (with Claude)" means Rosie directed the work and her Claude Code agent wrote the code.

## 2026-11-01 (later) — Rosie (with Claude)
- Matthew agreed to the changes below, so `rosie/hotel-hub` was pushed (commit `6bd9af2`) and pull request
  [matthewleepark/StitchSurvival#1](https://github.com/matthewleepark/StitchSurvival/pull/1) was opened
  against `main`. It is open and waiting for Matthew's review; nothing is merged yet.
- `PLAN.md` now records the horror-hub direction as agreed.
- Still open: the Studio playtest results (add them here), who it is for, and the hand-over date.

## 2026-11-01 — Rosie (with Claude)

**Planned (Rosie's direction; Matthew agreed to it later the same day, see the entry above):** the game wasn't how Rosie imagined it, so
change it into a horror survival game with a hotel hub: players arrive in a hotel lobby, walk around,
and queue for games through numbered guest-room doors (up to 32 players). Rosie chose these when asked:
- Rooms are **game queues** (not private parties, not just a bigger server cap).
- Rooms offer the two existing levels, **Bomb Hotel** and **Shark Survival**.

**Changed** (branch `rosie/hotel-hub`, commit "Add hotel hub, game rooms, horror mood, flashlight and
normal movement"):
- **Hub:** new `Levels/HotelLobby.luau` + `Levels/HotelProps.luau` replace the toybox Pod as the lobby:
  marble hall, reception desk, fireplace, elevators, two lounge sets, balconies upstairs reached by two
  staircases, library and piano nooks, and the existing gear machine. `Config.Pod` now holds the hub's
  size (112 x 80 x 38). The old `Levels/Pod.luau` still exists; swap the `require` in
  `init.server.luau` to bring it back.
- **Game rooms:** new `Rooms.luau`. Each of the ten guest-room doors (201-210) is a queue for one level
  (`Config.Rooms`). Hold E at a door to join or leave; the door sign shows the count. The round loop now
  waits for a ready room and takes only that room's players into the level. Rooms take turns because
  the game keeps its round state in single global places (Phase/Status/TimeLeft attributes, Score,
  fixed level origins), so two rounds can't run at once without a rewrite.
- **Horror look:** new `Mood.luau` applies a dark, hazy night from `Config.Mood`, and makes tagged lamps
  flicker (with an occasional power surge). Lobby palette and lamps are darker and sicklier.
- **Flashlight:** new client `Flashlight.luau` (F / L1 / mobile "Light" button), tuned in
  `Config.Flashlight`. Only the local player sees their own beam.
- **Movement:** gravity back to 196.2 (was 35, which made jumps huge); `Config.Doll.WalkSpeed` = 10 and
  `JumpHeight` = 4.3, scaled for a 3-stud doll. `Grab.luau` and `CharacterAudio.luau` now read these
  instead of hard-coded 16 and 8.
- **Optimization / spacing:** fewer pieces and more empty floor in the lobby (about 18 floor tiles instead
  of 70, no wallpaper stripes or pillar flutes, four pillars, two chandeliers, fewer windows, lamps and
  plants); parts under 3 studs no longer cast shadows.

**Files of Matthew's that were edited (please review these first):** `init.server.luau` (round loop:
intermission, `playRound(room)`, Mood and Rooms startup), `Config.luau` (new tables, gravity, Doll,
MinPlayers comment), `Levels/Pod.luau` (one line exposing `buildGearMachine`), `Doll.luau` (sets walk
speed and jump height), plus `Grab.luau`, `CharacterAudio.luau` and `init.client.luau`.

**Checked:** `rojo build` succeeds after every change. **Not checked:** the code has not been verified by
an automated linter, and the end-to-end playtest was still in progress when this was written (joining a
room, the round starting, stairs, the flashlight, mobile layout and frame rate). No part count or FPS
measurement yet.

**Next:**
- Playtest in Studio, fix whatever breaks, then update this entry.
- Ask the person this is for (still unchosen, see `PLAN.md`) what they would want from a horror hub.
- Matthew reviews the round-loop change; decide whether to split this branch into smaller PRs.
- Later ideas: real walk-in suites behind the doors, simultaneous rooms (needs per-room game state),
  horror audio (the sound slots are still the toybox sounds), horror pass on the two levels.

**Blockers:** Matthew hasn't seen any of this yet; the "who it is for" decision is still open.

## 2026-10-31 — Rosie (with Claude)
- Cloned repo; drafted `CLAUDE.md`, `PLAN.md`, `LOG.md` on branch `rosie/team-plan` for Matthew to review.
- Set up Rojo 7.7.1 from the repo's `rokit.toml` (the Studio plugin was 7.4.4 and had to be reinstalled
  with `rojo plugin install`).
- Reviewed the code: round loop in `init.server.luau`, config-driven numbers, server-side gear rolls.
  Notes for Matthew: `RequestRoll` doesn't check distance to the machine, nothing is saved between
  sessions, and no file uses `--!strict`.
- Next: Matthew edits the TODOs in `PLAN.md`; pick who this is for and ask them what they need.
- Blockers: none yet.
