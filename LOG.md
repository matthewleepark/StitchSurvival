# LOG.md

Newest entry at the top. One entry per working session: date, who, what changed, what's next, blockers.
"Rosie (with Claude)" means Rosie directed the work and her Claude Code agent wrote the code.

## 2026-11-08 (stickers, saving, Hide & Seek, spectate) — Matthew (with Claude)
Branch `matthew/stickers-and-modes` (from `matthew/shark-redesign`, which isn't merged yet).
**Touches Rosie's files** (client HUD/Roles/Flashlight/CodesPanel/Audio, HotelLobby, Rooms, KillerHotel,
KillerMaze, KillerRooms, Parkour): small hooks only, listed below. Rosie should review those.
- **Sticker sign:** the "20 STICKERS" price on the passive machine is on its own paper tag inside the stitched
  border, so no stitch crosses the words (`Pod.buildGearMachine`).
- **Saving (new `Data.luau`):** Stickers, Wins, passives, look, used codes, daily challenges and lifetime stats
  are saved in a DataStore (`Config.Save`). Offline in Studio without API access (it warns once). If a real load
  fails, that player isn't saved that visit, so a hiccup can't wipe them.
- **Promo codes:** `WELCOME` now gives 100 Stickers. Every code is once per account, ever (was once per visit).
- **Daily challenges (new `Daily.luau`, `client/DailyPanel.luau`):** 3 per player per day from `Config.Daily`,
  progress bars and CLAIM buttons, red dot when something is ready. The server checks every claim.
- **Leaderboards (new `Leaderboards.luau`):** two lit boards on the lobby back wall (above the elevators and
  beside the fireplace), each flipping between two top-10s: wins / top hunters, stickers earned / rounds played.
- **Hide & Seek (new `Levels/HideAndSeek.luau`, rooms 208 and 210):** reuses the Killer Hotel maze with more rooms
  and a wardrobe in every one (`def.rooms` override in KillerMaze). The seeker counts 20 s with the screen
  covered, then hunts with a red aura (Highlight + light + embers); getting close catches a hider. 30 pieces of
  glowing junk lie around; each hider can pick up one (F) and throw it once (click / tap / Q); a hit stuns the
  seeker for 4 s (then 4 s immune). Uses `stage.killer` so doors, wardrobe searches and parkour just work.
- **Spectator mode (new `client/Spectate.luau`, `Spectate.luau`):** SPECTATE button when a round is on and you
  aren't in it; arrows switch players, EXIT goes back. Server streams around the watched player.
  `CameraGuard` now guards whoever the camera follows.
- **Look:** DOLL / ME button switches between the knitted doll and your own avatar (saved; respawns you in the
  lobby, waits until after the round otherwise).
- **Admin:** Kick, Ban (every server, saved, double-tap to confirm), Unban, "Send in a shark" (Bomb Hotel).
  Admins can't be kicked or banned. Banned players are kicked on join.
- **Polish:** flashlight moved from F / L1 to **L / D-pad up** (F and L1 are the Killer Hotel door keys). New
  `client/Menu.luau` stacks CODES / DAILY / DOLL; on phones it moves off the thumbstick and hides in rounds,
  the passive card shrinks to a tag, and the admin button moves beside the score. Admin panel no longer runs
  into the menu. Role tag moved off the health ribbon.
- Hooks in shared files: `InRound` player attribute (round loop), `stage.ctx`, `stage.onHide` (KillerRooms),
  Parkour runs in HideAndSeek too, Rooms `soloTest` for HideAndSeek, lobby glow/icon, Audio reverb.
- **Checked in Studio:** WELCOME +100 then refused; rolls count, CLAIM pays once, unfinished claim refused;
  boards built and fit the wall; sign fixed; look switch respawns; Hide & Seek (solo test): 30 junk pieces,
  aura, seeker frozen while counting, pick up, throw, stun (frozen 4 s, stars, "stun" challenge 1/1); admin
  self-ban refused. luau-lsp clean apart from the 3 old errors (MazeLayout, KillerMaze, Parkour).
- **Not checked:** spectating and catching (need 2 players: use Studio's Test > Clients and Servers), saving to a
  real DataStore (turn on API access), phone layout on a real phone. Screenshots of the maze came out black.
- **Studio note:** the Rojo plugin made two copies of each new script. Disconnect and reconnect Rojo to clean up.

## 2026-11-08 (admin: suweetiepie) — Matthew (with Claude)
Same branch.
- **Admin:** added `suweetiepie` to `Config.Admins` (now 3HBQ, ACKworld, suweetiepie). The server still checks the
  list on every admin command.

## 2026-11-08 (killer throws bombs) — Matthew (with Claude)
Same branch. **Touches Rosie's Killer Hotel files** (`Levels/KillerHotel.luau`, `client/Roles.luau`,
`Config.KillerHotel`), so Rosie should review.
- **Held bomb:** while the killer has bombs, a black bomb with a sparking fuse is welded on top of their head
  (`updateHeldBomb`). It vanishes when they're out, comes back on restock, and is removed when the round ends.
- **Throw anywhere:** click anywhere (PC) or tap anywhere (mobile, `TouchTapInWorld`) to throw a bomb at that spot.
  Q / gamepad X / the BOMB button still work and throw at the mouse (or the middle of the screen). `DropBomb` now
  carries a `Vector3` target; the server still checks role, stock, cooldown and phase, then launches the bomb from
  above the head at `throwSpeed` 80 plus `throwLift` 12 upward. `dropAhead` is gone.
- **Shorter fuse:** `Config.KillerHotel.fuse` 8 -> 4 seconds.
- **Checked:** luau-lsp clean for the changed files (the 3 existing errors in MazeLayout/KillerMaze/Parkour
  were already there before this change). **Not checked in Studio:** Studio isn't connected to the MCP server.

## 2026-11-08 (roof bombs) — Matthew (with Claude)
Same branch.
- **Bombs fall through the roof:** the Bomb Hotel roof is now breakable `RoofTile`s (8x8). Bombs spawn 25 studs above
  a random spot over the whole roof; when one reaches the roof, `Bombs.punchThrough` (hooked in via
  `Bombs.plant`'s `onBomb` option, so Killer Hotel is untouched) shatters the tiles under it and it drops into the
  building. `Config.PlantedBombInterval` 15 -> 5 seconds (still halves by the end of the round).
- **Checked:** luau-lsp clean. **Not checked in Studio:** the Studio MCP connection is down.

## 2026-11-08 — Matthew (with Claude)
Branch `matthew/shark-redesign` (from main after PR #3).
- **New shark body** (`Levels/SharkModel.luau`), shared by the Shark Survival shark (`ClockworkShark.luau`) and the
  Bomb Hotel chaos shark (`FlyingShark.luau`), replacing the felt/gears look. Low-poly great white built from real
  triangles (two-wedge trick): slate-navy back over an off-white belly, hinged lower jaw with two rows of teeth top and
  bottom, red gums, black throat with a cyan glow, glossy black eyes with a cyan glint, five cyan gill slits, scars, a
  torn dorsal fin, long swept pectorals and a crescent tail. Based on the 4 reference images (low-poly shape, great
  white face and mouth, abyssal glow).
- **Cheaper to move:** every triangle is welded to one Root; two Motor6Ds open the jaw and swing the tail, so a frame
  updates 3 things instead of every part. Built once per size, cached in ServerStorage and cloned.
- **Checked:** luau-lsp clean for the new and changed files. **Not checked in Studio yet:** the Studio MCP
  connection dropped before the preview; the look still needs an in-game check (seams at the tail joint, tooth
  placement, colors in the dark).

## 2026-11-04 (admin passives) — Matthew (with Claude)
Same branch.
- **Admin panel PASSIVES section:** a "Give to" box (blank or "me" = yourself, or the start of a player's name), a
  button per passive (in its rarity color) that gives and equips it, "Give ALL passives" (equips the secret), and
  "Take passive away". Server commands `GivePassive`, `GiveAllPassives`, `RemovePassive` in `Admin.luau`
  (replacing MaxGear/ResetGear); the target gets a message when an admin gives them one.
- **Checked:** luau-lsp clean. **Not checked in Studio:** the Rojo plugin is still disconnected.

## 2026-11-04 (passives) — Matthew (with Claude)
Same branch.
- **Gear -> passives that work in every game.** Players see "passives" everywhere now (machine sign, prompt,
  panel, HUD, title help, admin buttons); the code still says Gear internally. New set of 10 in `Config.Gear`:
  Lucky Thread, Quick Laces, Bouncy Stuffing, Thick Felt, Button Magnet, Mending Needle, Spooky Sense, Deep Breath,
  Golden Zipper, and the secret Shark Tooth Charm.
- **New passive types:** `toughness` (less damage from everything, replaces bomb-only armor; applied in
  `Util.damage`), `regen` (heal per second, loop in `Gear.start`), `sense` (new client `Sense.luau` outlines anything
  tagged `Hazard` through walls: bombs, the chaos shark, the clockwork shark). `air` now adds to
  `Config.DefaultOxygen` (raised 5 -> 10). Promo code CHOMP now gives Bouncy Stuffing.
- **Checked:** luau-lsp clean. **Not checked in Studio:** the Rojo plugin had disconnected, so the playtest ran old
  code; needs a retest after reconnecting.

## 2026-11-04 (codes) — Matthew (with Claude)
Same branch.
- **Gear machine easy to find:** moved next to the red runner right in front of the lobby spawn
  (`HotelLobby`, at (-9, 0, 14)), with a glowing floor ring, a spotlight, glowing capsules in the globe and a
  floating "ROLL FOR GEAR!" sign (`Pod.buildGearMachine`, so the old Pod gets it too).
- **Promo codes:** `Config.Codes` (WELCOME +50 Stickers, STITCH +100, CHOMP = Spring Shoes). New server
  `Codes.luau` (RemoteFunction `RedeemCode`, once per player per visit, not case-sensitive) and client
  `CodesPanel.luau` (CODES button bottom left, text box, green/red result message).
- **Checked:** playtest: WELCOME worked once then "already used", a fake code was rejected, CHOMP gave Spring
  Shoes, Stickers 40 -> 90; machine 21 studs from spawn; no new console errors.

## 2026-11-04 (shark) — Matthew (with Claude)
Same branch.
- **One big wandering chaos shark** (`FlyingShark.luau`, `BombHotel.sharkAttacks`, `Config.Chaos`): a chaos round
  now gets a single shark, twice the size (`sharkScale = 2`, about 30 studs long). After the wall crack it chews in,
  then flies to random spots around the hotel instead of chasing players, chewing through whatever is in the way
  and chomping anyone it runs into (once each). It stays until the round ends.
- **Checked:** playtest: max 1 shark at once, ~44 x 22 x 21 studs, path went from outside the wall through the
  hotel; no new console errors.

## 2026-11-04 (later) — Matthew (with Claude)
Same branch.
- **Breakable walls and ground floor over acid** (`BombHotel.luau`): the outer walls are now 8x8 breakable
  cardboard tiles and the lobby floor is breakable wooden tiles. Under and around the hotel is a pool of green
  acid; touching it pops you (`AcidFizz` sound). Invisible boundaries moved out so you can fall through a hole.
  Wall decorations near a break are cleaned up (`stage.cleanDecor`) so nothing floats.
- **Fair chaos sharks** (`FlyingShark.luau`, `Config.Chaos`): no more phasing. A shark appears outside after the
  red crack and has to chew through the wall (one block per 0.45 s, `Bombs.breakBlock`); inside it flops (rolls,
  wiggles, bobs), hunts the closest player at 11 studs/s (slower than walking), chews through floors and pillars
  in its way, and leaves after 22 s.
- **Lobby railings:** stairs and balcony rails are named `Railing` and set `CanQuery = false`, so the camera looks
  through them; invisible guards still stop anyone falling.
- **Checked:** playtest: shark appeared, took ~4 s to chew in; 694 wall/floor tiles; dropping into the acid
  popped me; no new console errors.

## 2026-11-04 — Matthew (with Claude)
Same branch.
- **Gear overhaul** (`Config.Gear`, `server/Gear.luau`, new `client/GearPanel.luau`): 10 items with passives
  (air, speed, jump, bombArmor, magnet, scoreBonus, secondChance) incl. a 0.1% secret (Shark Tooth Charm, shown
  as ??? until owned). Walking up to the gear machine opens a panel listing every item (icon, rarity, chance,
  passives) with a ROLL button; a reel spins and lands on the server's pick. Rolled items go into a collection
  (`OwnedGear`), and you can equip any owned item. The HUD roll button is gone; the HUD card shows what's equipped.
  Passives are applied in `Util.damage` / `Util.kill` (armor, second chance), `Score.add` (bonus, round
  multiplier), a magnet loop in `Score`, `Gear.apply` (speed/jump), and Shark Survival air.
- **Bomb Hotel CHAOS MODE** (`Config.Chaos`, new `Levels/FlyingShark.luau`): 25% of rounds. Double points, and
  battle-scarred sharks burst through the outer walls (red crack warning first), charge at a player and chomp.
  Bombs also drop faster as the round goes on. Admin panel has "Start now: Bomb Hotel CHAOS".
- **Stairs:** solid open-side handrail plus an invisible guard; the wall side is now one clean board; stairs
  sit just off the wall paneling.
- **Stuck "GO!" fixed** (`Hud.luau`): the text faded but its outline didn't; the stamp now hides fully. The level
  banner also hides after sliding out and can't be cut short by an older timer.
- **Checked:** luau-lsp clean; playtest: rolled a Tin Can Helmet (reel result shown, owned + equipped, 10 items
  listed), chaos round showed the banner, a wall crack and a shark, no countdown text left on screen, no new errors.

## 2026-11-03 (bus) — Matthew (with Claude)
Same branch.
- **Normal height:** `Config.Doll.Scale` 1, `WalkSpeed` 16, `JumpHeight` 7.2 (Roblox defaults). The doll keeps a
  slightly bigger head (1.2) but no longer has a shorter body.
- **Buses instead of waiting rooms:** behind each door is now a dark hotel shuttle bus (32 seats in 8 rows of
  2 + 2, an aisle, windows onto the night, an empty driver's seat, and a destination sign over the windshield
  showing the level, count and status). Stepping on the pad seats you on the bus; new client `BusCamera.luau`
  locks first person while you sit in a `WaitSeat` and restores the normal camera when you jump off.
  `Rooms.join` retries the seat once if the avatar was still loading.
- **Checked:** playtest: seated within 0.25 s, first person on the bus, jumping off -> normal camera, out of the
  queue, back on the balcony; no new console errors.

## 2026-11-03 (final) — Matthew (with Claude)
Same branch.
- **Room signs are solid wall boards now**, not floating cards (the always-on-top cards stacked on top of each
  other from the lobby floor). Each sits on the wall above its door with a glowing top edge: icon + name, count,
  and the hint. `HotelLobby.buildRoomEntry`.
- **No walking through things:** most lobby furniture and wall decoration was built non-solid (desk, fireplace,
  piano, elevators, paneling, door frames...). `HotelLobby.build` now makes every visible part with at least
  3 x 1.5 studs of face solid, except join pads and chairs.
- **Bigger doll:** `Config.Doll.Scale` 0.6 -> 0.85 (about 5 studs with head and hat), `WalkSpeed` 10 -> 13,
  `JumpHeight` 4.3 -> 6. Waiting rooms now have 6 rows of 6 larger chairs (36 seats).
- **Checked:** playtest: 0 floating signs, 10 wall signs, reception desk solid, joined room 204 and seated,
  no new console errors.

## 2026-11-03 (latest) — Matthew (with Claude)
Same branch.
- **Waiting-room flicker fixed:** each room's walls were in the same place as the lobby's outer wall (and the next
  room's wall), so they flickered. Walls now sit inside the room's own footprint; rooms are 13 wide with a gap.
  Chairs slightly narrower and their backs set clear of the doll.
- **Big, kid-friendly signs:** each pad has a large always-on-top card: "💣 BOMB HOTEL" / "🦈 SHARK SURVIVAL",
  "0 / 32 players", and "Step on the glowing square!" (or "FULL - try another room"). The waiting-room screen shows
  the level, the count and "Waiting for N more..." / "Starting soon!".
- **Checked:** playtest shows the sign text before/after joining (0/32 -> 1/32), seated, no new console errors.

## 2026-11-03 (late) — Matthew (with Claude)
Same branch. **Rosie, this reworks a lot of your lobby and `Rooms.luau`, please review:**
- **Joining a room is now a pad, not hold-E.** A glowing pad (orange = Bomb Hotel, blue = Shark Survival) sits in
  front of each door with floating text ("Room 201: Bomb Hotel, 1/32 waiting - step in to join"). Stepping on it
  teleports you into that room's **waiting room** behind the wall and seats you in the next free chair (4 rows of
  8, facing a screen that shows the level and the count). Jump to stand up: you leave the queue and are put back
  on the balcony. `Rooms.take` stands everyone up before the round; `Rooms.release` does the same for admin starts.
- **Balconies 12 -> 16 studs wide** so you can walk past the pads; runner rug moved to the walkway.
- **Doors** evenly spaced (every 14 studs, -34 to 22) with a pale frame, brass trim, raised panels, a glowing number
  plate and a light, so they stand out from the wall (`HotelProps.roomDoor`).
- **Pillars** under the balconies: three evenly spaced, tucked under the balcony edge; the corbels are gone.
- **Stairs** pushed flush against the front wall (no gap beside them).
- **Checked:** luau-lsp clean; playtest: stepping on Room 201's pad seated me in its waiting room and the text
  read 1/32; jumping out of Room 202 put me back on the balcony walkway; no new console errors.

## 2026-11-03 (night) — Matthew (with Claude)
Same branch.
- **Dimmer lighting** (`Config.Mood`): moonlight 0.4, exposure -0.15, lamps 1.2x, fill lights 0.22. A step darker
  than the "neutral" pass, still lighter than the original.
- **Camera** (new `client/CameraGuard.luau`, `Config.Camera`): zoom limited to 2-18 studs, and a sphere sweep from
  the head pulls the camera in front of any wall it would slip through.
- **Spooky lobby** (new `Levels/Spooky.luau`, called at the end of `HotelLobby.build`): cobwebs in high corners,
  drifting dust, two portraits by the entrance whose red eyes glow now and then, scattered papers, and new sound
  slots `LobbyCreak` / `LobbyWhisper` (empty IDs for now). Tunables in `Config.Spooky`.
- **Checked:** luau-lsp clean; playtest: zoom 2-18 applied, 60 spooky pieces built, no new console errors.

## 2026-11-03 (evening) — Matthew (with Claude)
Same branch. **Rosie, this changes your mood numbers, please check you're happy with the darkness:**
- **Door glitch fixed** (`Levels/HotelLobby.luau`): the front-wall wainscot ran behind the entrance and poked
  through the doors; the front wall now gets two runs of paneling with a 15-stud gap for the doors.
- **Brighter lobby, still spooky** (`Config.Mood`): ambient/outdoor ambient up, moonlight 0.35 -> 1, exposure
  -0.2 -> 0.15, thinner fog and haze. New `lampBrightness` (2.5x) and `lampRange` (1.4x) boost every lobby lamp
  (`HotelProps.luau`), and new `fillLight` adds 30 soft, non-flickering hidden lights over the floor and balconies
  (13 -> 43 lights). Turn any of these down for a darker hotel.
- **Checked:** luau-lsp clean; playtest shows nothing overlapping the door, 43 lights, no new console errors.

## 2026-11-03 (later) — Matthew (with Claude)
Same branch, `matthew/admin-and-doll`. **Rosie, these touch your files, please review:**
- **Shoulder flashlight:** `Doll.luau` straps a small flashlight to the right shoulder (everyone sees it);
  `client/Flashlight.luau` now shines the beam from its lens ("ShoulderLampLens") and the lens goes dark when off.
- **Stairs** (`Levels/HotelLobby.luau`): both staircases now start on the lobby floor near the entrance
  (x = +/-13, z = 30) facing into the room and climb sideways to the balcony. The balconies run to the front
  wall, and their railing has an opening where the stairs arrive. Luggage cart moved out of the way.
- **Entrance door** (`Levels/HotelProps.luau`): glass panes against the solid wall looked like floating brown
  slabs in the dark, so it's now mahogany double doors with raised panels, brass pulls and a glowing transom.
- **Checked:** luau-lsp clean; in a playtest the ramps run floor -> balcony (top at 15.5, balcony floor 16),
  the door stands 18.7 tall from the floor, the lamp is on the doll, no new console errors.

## 2026-11-03 — Matthew (with Claude)
Branch `matthew/admin-and-doll`, built on top of `rosie/hotel-hub`.
- **Admin panel** (only for names in `Config.Admins`, checked on the server): start a round now in any level
  (pulls everyone in, skipping the room queue), end the round, god mode, fly, speed, heal, respawn,
  teleports, drop a bomb on me, score bubbles, +100 Stickers, best/no scuba gear. F2 opens it.
  New files: `server/Admin.luau`, `server/RoundControl.luau`, `client/AdminPanel.luau`. `Util.kill` replaces
  direct `Health = 0` so god mode works.
- **Round loop** (`init.server.luau`): admin "Start now" makes a pretend room (`adminStart`); normal play still
  goes through `Rooms`.
- **No more heavy-landing slam** (`client/CharacterAudio.luau`): no thump, screen shake or stagger; just the
  soft landing sound. Rosie, please look since you own client files.
- **Doll look** (`Doll.luau`): your own head stays (skin, face, hair, hats), slightly bigger; the body is a
  plush with white seams, two buttons, a knee patch and the zipper.
- **Checked:** luau-lsp analyze clean; Studio playtest: admin recognized, Start now -> Bomb Hotel countdown,
  doll parts present, head color kept, no new console errors.
- **Next:** merge PR #1 first, then open a PR for this branch.

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
