# Stitch Survival

A handmade-scrapbook survival game for Roblox, inspired by LittleBigPlanet's survival levels,
rebuilt in full 3D with the normal Roblox third-person camera. Players are little knitted dolls
(about 3 studs tall) in a floaty, low-gravity world of cardboard, felt and foam.

## Levels

- **Bomb Hotel**: a 96 x 96 stud, five-floor hotel with an open atrium, ramps and foam pillars.
  Every 15 seconds a ticking bomb drops somewhere inside. When it goes off, everything within
  25 studs rips loose and flies outward, falling blocks squash anyone underneath, and fire spreads.
- **Shark Survival**: a 300 x 300 stud tissue-paper ocean with floating foam rafts that tip under
  your weight. A clockwork shark patrols, hunts anyone within 45 studs, smashes rafts and pops
  whoever it catches. Underwater you use up air.
- **Killer Hotel**: a three-floor maze hotel. One killer throws bombs at everyone else; the
  innocents hide and run until the timer ends.
- **Hide & Seek**: the same kind of maze, no bombs. One seeker (glowing red) counts while everyone
  hides in wardrobes and rooms, then catches anyone they reach. Each hider can pick up one piece of
  junk and throw it at the seeker to stun them.

In the lobby: **DAILY** challenges pay out Stickers, **CODES** takes promo codes (try `WELCOME`),
**DOLL / ME** switches between the knitted doll and your own avatar, and two leaderboards hang on
the back wall. Progress is saved between visits. If you're out of a round, press **SPECTATE** to
watch the players still in it.

Between levels everyone waits in **the Pod**, a closed cardboard toybox where the gear machine
sells scuba gear rolls. Better gear means more air underwater.

## Controls

- **W A S D**: walk around
- **Right mouse drag**: turn the camera. **Mouse wheel**: zoom.
- **Space**: jump (and swim up)
- **E** (hold): grab walls, rafts and blocks. Press jump while hanging to launch off.
  Grabbing something loose and heavy lets you drag it at half speed.
- **L**: flashlight on/off (D-pad up on a gamepad, the Light button on phones)
- **F** (hold): kick doors, hide in wardrobes, pick up junk (in the maze levels). **G**: lock a door.
- **Click / tap** anywhere: throw your bomb (killer) or your junk (hider) there. **Q** throws too.
- **Left Shift**: run (maze levels). **Left / Right arrows**: switch who you're spectating.

## Running it

1. Run `rojo serve` in this folder.
2. In Roblox Studio, open a new **Baseplate** place and delete the `Baseplate` part.
3. In the Plugins tab, click **Rojo**, then **Connect**.
4. Press **Play**.

To build a place file instead: `rojo build -o StitchSurvival.rbxlx`

## Where things live

| Path | What it does |
| --- | --- |
| `src/shared/Config.luau` | All the numbers, colors, gear odds and sound IDs. Start here. |
| `src/server/init.server.luau` | Round loop: Pod, level, countdown, results. |
| `src/server/Craft.luau` | Building blocks for the handmade look (stitches, felt, foam, signs). |
| `src/server/Levels/` | The Pod, Bomb Hotel (+ bombs), Shark Survival (+ clockwork shark). |
| `src/server/Score.luau` | Points, score bubbles and the combo multiplier. |
| `src/server/Gear.luau` | Scuba gear rolls (server-side so they can't be cheated). |
| `src/server/Doll.luau` | Turns characters into burlap dolls with a zipper. |
| `src/client/` | HUD, audio, effects, grabbing and screen shake. |

## Sounds

Every sound in the game has a slot in `Config.Sounds` (and footsteps in `Config.Footsteps`), each
with a comment describing what it should sound like. Find audio in Studio (Toolbox > Audio) and
paste the ID into the slot's `id`, e.g. `id = "rbxassetid://1234567890"`.

Slots with a `fallback` already play a sound built into Roblox until you replace it. The rest are
silent until you fill them in. Everything about *when* and *where* sounds play is already wired up:
3D positions, pitch changes, the music changing each round phase, room echo, underwater muffling,
the end-of-round freeze ducking everything, and the low-health heartbeat.

| Client file | What it does |
| --- | --- |
| `src/client/Audio.luau` | Sound groups, music per phase, room echo, underwater muffle, ducking. |
| `src/client/CharacterAudio.luau` | Footsteps by material, jump/land, oof + zipper, death slide whistle. |
| `src/client/Danger.luau` | Low-health heartbeat and red screen edges. |
| `src/client/Grab.luau` | Hold E to grab. |
| `src/client/TitleScreen.luau` | Main menu with PLAY / HOW TO PLAY. |
