# CLAUDE.md — Stitch Survival

Shared agent instructions for everyone working in this repo (Matthew and Rosie, and their agents).
Your agents do not talk to each other, so this file and `PLAN.md` are the single source of truth.
Personal notes go in `CLAUDE.local.md`, which is git-ignored and never committed.

## What this is
A handmade-scrapbook, LittleBigPlanet-style survival game for Roblox (Bomb Hotel, Shark Survival,
the Pod lobby). See `README.md` for controls and the file map.

## Where the newer systems live
- Hub: `Levels/HotelLobby.luau` (layout) and `Levels/HotelProps.luau` (furniture). The hub keeps the name
  `Config.Pod` for its size. The old toybox is `Levels/Pod.luau`.
- Map vote: `Vote.luau` pops up map pads at the reception desk between rounds (`Config.Vote`); the round loop in
  `init.server.luau` plays the winner with everyone in the server (max `Config.MaxPlayers` = 12). One round at a time.
- Look: `Mood.luau` reads `Config.Mood`. Lights tagged `FlickerLight` stutter.
- Movement: `Config.Gravity` and `Config.Doll.WalkSpeed` / `JumpHeight`. Don't hard-code speeds.
- Client flashlight: `client/Flashlight.luau`, `Config.Flashlight`.

## Read first, every session
1. `PLAN.md` — what we're building, who it's for, who owns which files, task status.
2. Top entry of `LOG.md` — what changed last.

## Team rules
- **Never commit to `main`.** Work on a branch: `matthew/<topic>` or `rosie/<topic>`.
- **Merge through pull requests.** The other person reviews; the author of the PR does not merge their own
  (see "Who merges" in `PLAN.md`).
- **Stay in your lane.** Edit the files you own in `PLAN.md`. For a file you don't own, ask its owner first.
- **Sync before you start:** `git fetch origin`, `git pull --ff-only` on main, then branch.
- **Small commits, small PRs.** One topic per branch so conflicts stay tiny.
- **Never force-push, never rewrite shared history, never push without the human saying so.**
- **Log it.** End each session with a short `LOG.md` entry (newest at top): date, who, what changed, what's next.

## Code rules (from the existing codebase)
- Numbers, colors, gear odds and sound IDs live in `src/shared/Config.luau`. Don't hard-code them elsewhere.
- Server authority: scoring, gear rolls and damage are decided on the server. Clients send intents only.
- Match the surrounding Luau style. Run with Rojo: `rojo serve`, then connect the Studio plugin and press Play.
