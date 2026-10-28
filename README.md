# Stitch Survival

A handmade-scrapbook survival game for Roblox, inspired by LittleBigPlanet's survival levels.
Knitted dolls hop between three depth layers in side-on dioramas made of cardboard, felt and foam.

## Levels

- **Bomb Hotel**: a dollhouse cutaway of a hotel. Bombs drop from chutes in the roof and blow
  holes in the foam floors. Orange bombs explode on impact. Grab score bubbles, don't get popped.
- **Shark Survival**: hop between floating cardboard crates while a clockwork shark hunts you.
  Orange-taped crates sink when you stand on them. Dive to grab bonus bubbles, but watch your air.

Between levels everyone waits in **the Pod**, where the gear machine sells scuba gear rolls.
Better gear means more air underwater.

## Controls

- **A / D**: walk left and right
- **W / S** (tap): hop to the layer behind or in front
- **Space**: jump (and swim up)

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
| `src/client/` | Side-on camera, depth layers, HUD and effects. |

## Sounds

Every sound slot in `Config.Sounds` starts empty. Find audio in Studio (Toolbox > Audio) and paste
the IDs in, e.g. `Bang = "rbxassetid://1234567890"`.
