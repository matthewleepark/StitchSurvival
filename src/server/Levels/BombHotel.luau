-- Bomb Hotel: a dollhouse-style cutaway of a hotel. Floors are polystyrene foam that bombs
-- blow holes in, so players drop lower and lower as the round goes on.
--
-- Layout (side view, y is up):
--   y 76+   HOTEL KABOOM marquee + egg timer, bomb chutes hang below it
--   y 64    foam floor 4   (hole on the right) <- players start here
--   y 48    foam floor 3   (hole on the left)
--   y 32    foam floor 2   (hole on the right) <- grandfather clock on this floor's wall
--   y 16    foam floor 1   (hole on the left)
--   y 0     solid wood lobby floor
-- Foam steps under each hole let players climb back up.
--
-- Round timeline: a few calm seconds (hum + clock), then the egg timer buzzes and spins,
-- then bombs start falling from the chutes and a planted time bomb appears every 15 seconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)
local Score = require(script.Parent.Parent.Score)
local Util = require(script.Parent.Parent.Util)
local Bombs = require(script.Parent.Bombs)

local Colors = Config.Colors
local M = Craft.Material

local function findDef()
	for _, def in Config.Levels do
		if def.name == "BombHotel" then
			return def
		end
	end
	error("BombHotel is missing from Config.Levels")
end

local FLOOR_HEIGHT = 16
local FOAM_FLOORS = findDef().floors - 1
local BLOCK = 4
local SLAB_DEPTH = 15 -- leaves a small gap in front of the back wall for the wallpaper
local SLAB_Z = 0.5
local CHUTE_XS = { -40, -24, -8, 8, 24, 40 }
local CHUTE_BOTTOM = (FOAM_FLOORS + 1) * FLOOR_HEIGHT - 4

local BombHotel = {}

-- Tall wooden clock with a swinging pendulum (the client swings anything tagged "Pendulum").
local function buildGrandfatherClock(parent: Instance, base: Vector3)
	local wood, dark = Colors.Wood, Colors.WoodDark
	Craft.block(parent, CFrame.new(base + Vector3.new(0, 5, 0)), Vector3.new(3.2, 10, 1.4), dark, M.Wood, Craft.DECOR)
	Craft.block(parent, CFrame.new(base + Vector3.new(0, 10.4, 0)), Vector3.new(3.8, 1, 1.6), wood, M.Wood, Craft.DECOR)
	Craft.block(parent, CFrame.new(base + Vector3.new(0, 4.6, 0.72)), Vector3.new(2.2, 5.2, 0.05), Color3.fromRGB(70, 50, 40), M.Plastic, Craft.DECOR)

	local faceCenter = base + Vector3.new(0, 8.6, 0.75)
	local face = Craft.disc(parent, faceCenter, 2.4, Colors.Paper, M.Plastic, Craft.DECOR)
	Craft.block(parent, CFrame.new(faceCenter + Vector3.new(0, 0.4, 0.2)), Vector3.new(0.12, 0.8, 0.05), Colors.Ink, M.Plastic, Craft.DECOR)
	Craft.block(parent, CFrame.new(faceCenter + Vector3.new(0.3, 0, 0.2)), Vector3.new(0.6, 0.12, 0.05), Colors.Ink, M.Plastic, Craft.DECOR)

	local pivot = base + Vector3.new(0, 7, 0.8)
	local rod = Craft.block(parent, CFrame.new(pivot + Vector3.new(0, -1.8, 0)), Vector3.new(0.15, 3.6, 0.05), Colors.Gold, M.Metal, Craft.DECOR)
	local bob = Craft.disc(parent, pivot + Vector3.new(0, -3.8, 0.05), 1, Colors.Gold, M.Metal, Craft.DECOR)
	for _, part in { rod, bob } do
		part:SetAttribute("Pivot", pivot)
		Craft.tag(part, "Pendulum")
	end

	Util.loopSound("ClockTock", face)
end

-- Kitchen egg timer stuck to the marquee. The hand spins while the client sees Speed > 0.
local function buildEggTimer(parent: Instance, center: Vector3)
	Craft.disc(parent, center, 4.4, Colors.Felt, M.Plastic, Craft.DECOR)
	Craft.disc(parent, center + Vector3.new(0, 0, 0.1), 3.4, Colors.Paper, M.Plastic, Craft.DECOR)
	Craft.block(parent, CFrame.new(center + Vector3.new(0, 2.5, 0)), Vector3.new(1, 0.8, 0.8), Colors.Felt, M.Plastic, Craft.DECOR)
	local hand = Craft.block(parent, CFrame.new(center + Vector3.new(0, 0.7, 0.3)), Vector3.new(0.2, 1.4, 0.05), Colors.Ink, M.Plastic, Craft.DECOR)
	hand:SetAttribute("Pivot", center + Vector3.new(0, 0, 0.3))
	hand:SetAttribute("Speed", 0)
	Craft.tag(hand, "Spin")
	return hand
end

function BombHotel.build(def)
	local O = def.origin
	local W = def.width
	local depth = Config.StageDepth
	local wallZ = -depth / 2

	local model = Instance.new("Model")
	model.Name = "BombHotel"
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	local foam = Instance.new("Folder")
	foam.Name = "Foam"
	foam.Parent = model

	local function at(x: number, y: number, z: number?): Vector3
		return O + Vector3.new(x, y, z or 0)
	end

	-- Lobby floor: solid wood with a checkered tile pattern.
	Craft.block(model, CFrame.new(at(0, -2)), Vector3.new(W + 8, 4, depth + 8), Colors.WoodDark, M.Wood)
	for i = 0, W / BLOCK - 1 do
		for row = 0, 1 do
			local color = if (i + row) % 2 == 0 then Colors.Paper else Color3.fromRGB(70, 60, 70)
			local x = -W / 2 + BLOCK / 2 + i * BLOCK
			Craft.block(decor, CFrame.new(at(x, 0.03, -4 + row * 8)), Vector3.new(BLOCK, 0.06, 8), color, M.Plastic, Craft.DECOR)
		end
	end

	-- Back wall, then one wallpaper band per floor with rooms on it.
	local topY = (FOAM_FLOORS + 1) * FLOOR_HEIGHT
	Craft.block(model, CFrame.new(at(0, (topY + 30) / 2, wallZ - 1)), Vector3.new(W + 8, topY + 30, 2), Colors.CardboardDark)

	for floor = 1, FOAM_FLOORS + 1 do
		local base, stripe = Config.Wallpapers[floor][1], Config.Wallpapers[floor][2]
		local bottom = (floor - 1) * FLOOR_HEIGHT
		Craft.panel(decor, at(0, bottom + FLOOR_HEIGHT / 2, wallZ + 0.1), W, FLOOR_HEIGHT, base, M.Felt, { thickness = 0.2 })
		for x = -W / 2 + 2, W / 2 - 2, 4 do
			Craft.block(decor, CFrame.new(at(x, bottom + FLOOR_HEIGHT / 2, wallZ + 0.25)), Vector3.new(1.2, FLOOR_HEIGHT, 0.1), stripe, M.Felt, Craft.DECOR)
		end
		-- Skirting board.
		Craft.block(decor, CFrame.new(at(0, bottom + 0.6, wallZ + 0.4)), Vector3.new(W, 1.2, 0.3), Colors.WoodDark, M.Wood, Craft.DECOR)

		for room = 1, 3 do
			local x = (room - 2) * 32
			Craft.window(decor, at(x, bottom + 7.5, wallZ + 0.6), 7, 5.5, Colors.Sky, Colors.Felt)
			Craft.picture(decor, at(x + 11, bottom + 8, wallZ + 0.5), 3.5, 2.6, Config.Wallpapers[(floor % #Config.Wallpapers) + 1][1])
			Craft.lamp(decor, at(x - 9, bottom + 7, wallZ + 0.5))

			-- Gold room number plate above the window.
			Craft.block(decor, CFrame.new(at(x, bottom + 12.4, wallZ + 0.5)), Vector3.new(3.2, 1.4, 0.2), Colors.Gold, M.Metal, Craft.DECOR)
			Craft.label(decor, at(x, bottom + 12.4, wallZ + 0.65), 2.8, 1.2, tostring(floor * 100 + room), Colors.Ink)
		end
	end

	-- Ground floor extras: reception desk and a welcome sign.
	Craft.block(model, CFrame.new(at(0, 2, -4.5)), Vector3.new(10, 4, 3), Colors.Wood, M.Wood)
	Craft.block(decor, CFrame.new(at(0, 4.15, -4.5)), Vector3.new(10.4, 0.3, 3.4), Colors.Felt, M.Felt, Craft.DECOR)
	Craft.label(decor, at(0, 2, -2.9), 8, 1.6, "RECEPTION", Colors.Paper)

	-- The grandfather clock ticks away on the third floor.
	buildGrandfatherClock(decor, at(-15, 2 * FLOOR_HEIGHT, wallZ + 1.2))

	-- A low, cozy building hum that fills the whole hotel.
	local humSpot = Craft.block(decor, CFrame.new(at(0, (FOAM_FLOORS + 1) * FLOOR_HEIGHT / 2, 0)), Vector3.one, Color3.new(), nil, Craft.DECOR)
	humSpot.Transparency = 1
	Util.loopSound("HotelHum", humSpot)

	-- Foam floors with a hole on alternating sides, plus foam steps leading up to each hole.
	for level = 1, FOAM_FLOORS do
		local top = level * FLOOR_HEIGHT
		local side = if level % 2 == 1 then -1 else 1

		for j = 0, W / BLOCK - 1 do
			local x = -W / 2 + BLOCK / 2 + j * BLOCK
			local inHole = side * x >= 30
			if not inHole then
				Craft.foam(foam, CFrame.new(at(x, top - 1, SLAB_Z)), Vector3.new(BLOCK, 2, SLAB_DEPTH), j % 2 == 0)
			end
		end

		local below = top - FLOOR_HEIGHT
		for step = 1, 3 do
			local x = side * (44 - 6 * (step - 1))
			Craft.foam(foam, CFrame.new(at(x, below + 4 * step - 1, SLAB_Z)), Vector3.new(BLOCK, 2, SLAB_DEPTH), step % 2 == 0)
		end

		-- A couple of foam crates on the lower floors to hide behind or climb.
		-- (The top floor stays clear because that's where players spawn.)
		if level < FOAM_FLOORS then
			for _ = 1, 2 do
				local x = math.random(-6, 6) * 3
				Craft.foam(foam, CFrame.new(at(x, top + 2, Util.randomLayer())), Vector3.new(4, 4, 4), true)
			end
		end
	end

	-- Roof: a beam holding the bomb chutes, and the marquee above it.
	Craft.block(model, CFrame.new(at(0, CHUTE_BOTTOM + 9, -2)), Vector3.new(W + 8, 2, 6), Colors.WoodDark, M.Wood)
	local chutes = {}
	for _, x in CHUTE_XS do
		Craft.cylinder(decor, at(x, CHUTE_BOTTOM + 4, 0), 8, 4, "Y", Colors.Cardboard, M.Cardboard, Craft.DECOR)
		Craft.cylinder(decor, at(x, CHUTE_BOTTOM + 0.3, 0), 0.6, 4.8, "Y", Colors.Felt, M.Felt, Craft.DECOR)
		table.insert(chutes, at(x, CHUTE_BOTTOM - 2))
	end
	Craft.sign(decor, at(0, CHUTE_BOTTOM + 16, wallZ + 1), 46, 9, "HOTEL KABOOM", { bulbs = true, textColor = Colors.Felt })
	Craft.bunting(decor, at(-W / 2, CHUTE_BOTTOM + 10.5, wallZ + 2), at(W / 2, CHUTE_BOTTOM + 10.5, wallZ + 2))
	Craft.sticker(decor, at(-36, CHUTE_BOTTOM + 15, wallZ + 1), 5, Colors.Warning, "BOOM!")
	local timerCenter = at(-28.5, CHUTE_BOTTOM + 16, wallZ + 1.2)
	local timerHand = buildEggTimer(decor, timerCenter)
	Craft.sticker(decor, at(36, CHUTE_BOTTOM + 15, wallZ + 1), 5, Color3.fromRGB(90, 160, 220), "POW!")

	-- Brick-ish cardboard columns on the sides.
	for _, side in { -1, 1 } do
		Craft.block(model, CFrame.new(at(side * (W / 2 + 2), (topY + 30) / 2, 0)), Vector3.new(4, topY + 30, depth + 8), Colors.CardboardDark)
		-- Mortar lines on the camera-facing side so the columns read as bricks.
		local front = depth / 2 + 4.05
		for y = 4, topY + 26, 4 do
			Craft.block(decor, CFrame.new(at(side * (W / 2 + 2), y, front)), Vector3.new(4, 0.25, 0.1), Colors.Cardboard, M.Plastic, Craft.DECOR)
			local jointX = side * (W / 2 + 2) + (if (y / 4) % 2 == 0 then -1 else 1)
			Craft.block(decor, CFrame.new(at(jointX, y + 2, front)), Vector3.new(0.25, 4, 0.1), Colors.Cardboard, M.Plastic, Craft.DECOR)
		end
	end

	Craft.boundaries(model, O, W, topY + 20)

	model.Parent = workspace

	local spawns = {}
	for i, x in { -12, -4, 4, 12, -20, 20 } do
		table.insert(spawns, CFrame.new(at(x, FOAM_FLOORS * FLOOR_HEIGHT + 3, Config.Layers[(i % 3) + 1])))
	end

	return {
		model = model,
		foam = foam,
		origin = O,
		width = W,
		chutes = chutes,
		spawns = spawns,
		killY = O.Y - 20,
		timerHand = timerHand,
		frozen = false,
	}
end

-- A random spot on top of an intact foam floor block, on a random layer.
local function plantSpot(stage): Vector3?
	local candidates = {}
	for _, block in stage.foam:GetChildren() do
		if block:IsA("BasePart") and block.Anchored and block:GetAttribute("Breakable") and block.Size.Z == SLAB_DEPTH then
			table.insert(candidates, block)
		end
	end
	if #candidates == 0 then
		return nil
	end
	local block = candidates[math.random(1, #candidates)]
	local top = block.Position.Y + block.Size.Y / 2
	return Vector3.new(block.Position.X, top + 1.2, stage.origin.Z + Util.randomLayer())
end

local function plantBombs(stage, ctx)
	while ctx.isActive() do
		local spot = plantSpot(stage)
		if spot then
			task.spawn(Bombs.plant, stage, spot)
		end
		task.wait(Config.PlantedBombInterval)
	end
end

local function spawnBubbles(stage, ctx)
	while ctx.isActive() do
		local floor = math.random(0, FOAM_FLOORS)
		local x = math.random(-40, 40)
		local position = stage.origin + Vector3.new(x, floor * FLOOR_HEIGHT + 3, Util.randomLayer())
		Score.spawnBubble(stage.model, position)
		task.wait(2.2)
	end
end

function BombHotel.run(stage, ctx)
	task.spawn(spawnBubbles, stage, ctx)

	-- A few calm seconds: just the hum and the clock.
	task.wait(3)
	if not ctx.isActive() then
		return
	end

	-- Then the egg timer goes off: buzz-whir, and the spring grinds while the hand spins.
	local timerFace = stage.timerHand
	Util.playSound("AlarmBuzz", timerFace)
	local spring = Util.loopSound("EggTimer", timerFace)
	timerFace:SetAttribute("Speed", 14)
	task.wait(2.5)
	timerFace:SetAttribute("Speed", 0)
	if spring then
		spring:Stop()
	end

	task.spawn(plantBombs, stage, ctx)

	while ctx.isActive() do
		local progress = ctx.progress()
		local count = 1 + math.floor(progress * 3)
		for _ = 1, count do
			local chute = stage.chutes[math.random(1, #stage.chutes)]
			local kind = if progress > 0.3 and math.random() < 0.3 then "Impact" else "Fuse"
			Bombs.drop(stage, chute + Vector3.new(math.random(-2, 2), 0, Util.randomLayer()), kind)
			task.wait(0.15)
		end
		task.wait(2.4 - 1.6 * progress)
	end
end

-- Round over: everything stops exactly where it is.
function BombHotel.freeze(stage)
	stage.frozen = true
	for _, part in stage.model:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then
			part.Anchored = true
		end
	end
end

return BombHotel
