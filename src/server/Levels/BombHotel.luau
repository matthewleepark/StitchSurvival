-- Bomb Hotel: a five-floor hotel you can walk all the way around in 3D.
--
-- Layout (all numbers in studs, measured from the center of the lobby floor):
--   * The building is 96 wide (X) by 96 deep (Z). Four cardboard outer walls, a cardboard roof.
--   * Floor 1 (the lobby) is solid wood with a checkered tile pattern and a reception desk.
--   * Floors 2-5 are made of 8x8 foam blocks, 16 studs apart. Each has a 32x32 hole in the
--     middle (the atrium) with low railings around it, so you can look down into the lobby.
--   * Wooden ramps connect each floor to the next. Odd ramps run along the back wall, even ramps
--     along the front wall, and the floor above each ramp has a gap so you can walk up through it.
--   * Six thick foam pillars wrapped in brown paper hold the floors up.
--   * Every wall has wallpaper, windows with curtains, pictures, lamps and room numbers.
--     A grandfather clock tocks on the third floor; a HOTEL KABOOM sign with an egg timer
--     hangs in the middle of the atrium under the roof.
--
-- Round timeline: a few calm seconds (hum + clock), then the egg timer buzzes and spins,
-- then a bomb is dropped somewhere in the hotel every 15 seconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)
local Score = require(script.Parent.Parent.Score)
local Util = require(script.Parent.Parent.Util)
local Bombs = require(script.Parent.Bombs)
local RoundControl = require(script.Parent.Parent.RoundControl)
local FlyingShark = require(script.Parent.FlyingShark)
local Remotes = require(script.Parent.Parent.Remotes)

local Colors = Config.Colors
local M = Craft.Material

local BLOCK = 8
local ATRIUM_HALF = 16
local RAMP_RUN = 32 -- how far a ramp travels sideways while climbing one floor
local RAILING_HEIGHT = 1.6

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

	Craft.tag(face, "Occluded")
	Util.loopSound("ClockTock", face)
end

-- Kitchen egg timer. The hand spins while its "Speed" attribute is above 0.
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

-- Decorations for one wall, built as if it were the back wall (facing +Z), then rotated
-- into place around the middle of the hotel. Returns the model.
local function decorateWall(parent: Instance, O: Vector3, W: number, D: number, floors: number, floorHeight: number, rotation: number, wallIndex: number)
	local wall = Instance.new("Model")
	wall.Name = "WallDecor"
	local wallZ = -D / 2

	local function at(x: number, y: number, z: number): Vector3
		return O + Vector3.new(x, y, z)
	end

	for floor = 1, floors do
		local base, stripe = Config.Wallpapers[floor][1], Config.Wallpapers[floor][2]
		local bottom = (floor - 1) * floorHeight
		Craft.panel(wall, at(0, bottom + floorHeight / 2, wallZ + 0.1), W, floorHeight, base, M.Felt, { thickness = 0.2 })
		for x = -W / 2 + 3, W / 2 - 3, 6 do
			Craft.block(wall, CFrame.new(at(x, bottom + floorHeight / 2, wallZ + 0.25)), Vector3.new(1.4, floorHeight, 0.1), stripe, M.Felt, Craft.DECOR)
		end
		Craft.block(wall, CFrame.new(at(0, bottom + 0.6, wallZ + 0.4)), Vector3.new(W, 1.2, 0.3), Colors.WoodDark, M.Wood, Craft.DECOR)

		for room = 1, 3 do
			local x = (room - 2) * 32
			Craft.window(wall, at(x, bottom + 7.5, wallZ + 0.6), 7, 5.5, Colors.Sky, Colors.Felt)
			Craft.picture(wall, at(x + 11, bottom + 8, wallZ + 0.5), 3.5, 2.6, Config.Wallpapers[(floor % #Config.Wallpapers) + 1][1])
			Craft.lamp(wall, at(x - 9, bottom + 7, wallZ + 0.5))
			local number = floor * 100 + wallIndex * 3 + room
			Craft.block(wall, CFrame.new(at(x, bottom + 12.4, wallZ + 0.5)), Vector3.new(3.2, 1.4, 0.2), Colors.Gold, M.Metal, Craft.DECOR)
			Craft.label(wall, at(x, bottom + 12.4, wallZ + 0.65), 2.8, 1.2, tostring(number), Colors.Ink)
		end
	end

	-- The grandfather clock stands against the back wall on the third floor
	-- (on the right side, away from the ramp that runs along the left half of this wall).
	if wallIndex == 0 then
		buildGrandfatherClock(wall, at(20, 2 * floorHeight, wallZ + 1.2))
	end

	wall.Parent = parent
	local turn = CFrame.new(O) * CFrame.Angles(0, rotation, 0) * CFrame.new(-O)
	wall:PivotTo(turn * wall:GetPivot())
	return wall
end

-- A wooden plank ramp climbing from `from` to `to` (both points on the walking surface).
local function buildRamp(parent: Instance, from: Vector3, to: Vector3, width: number)
	local middle = (from + to) / 2
	local length = (to - from).Magnitude
	local plank = Craft.block(parent, CFrame.lookAt(middle, to) * CFrame.new(0, -0.5, 0), Vector3.new(width, 1, length + 1), Colors.Wood, M.Wood)
	plank.Name = "Ramp"
	plank:SetAttribute("Breakable", true)
	-- Darker slats across it so it reads as planks.
	for i = 1, math.floor(length / 3) do
		local point = from:Lerp(to, i / math.floor(length / 3 + 1))
		Craft.block(parent, CFrame.lookAt(point, to) * CFrame.new(0, 0.02, 0), Vector3.new(width, 0.05, 0.3), Colors.WoodDark, M.Wood, Craft.DECOR)
	end
	return plank
end

function BombHotel.build(def)
	local O = def.origin
	local W, D = def.width, def.depth
	local floors = def.floors
	local H = def.floorHeight
	local roofY = floors * H

	local model = Instance.new("Model")
	model.Name = "BombHotel"
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	-- Everything bombs can blow apart lives in here.
	local breakables = Instance.new("Folder")
	breakables.Name = "Breakables"
	breakables.Parent = model

	local function at(x: number, y: number, z: number?): Vector3
		return O + Vector3.new(x, y, z or 0)
	end

	-- Lobby floor: checkered wooden tiles that bombs (and sharks) can break, so the ground floor can
	-- fall away too.
	for i = 0, W / BLOCK - 1 do
		for j = 0, D / BLOCK - 1 do
			local color = if (i + j) % 2 == 0 then Colors.Paper else Color3.fromRGB(70, 60, 70)
			local tile = Craft.block(breakables, CFrame.new(at(-W / 2 + BLOCK / 2 + i * BLOCK, -1, -D / 2 + BLOCK / 2 + j * BLOCK)), Vector3.new(BLOCK, 2, BLOCK), color, M.Wood)
			tile.Name = "FloorTile"
			tile:SetAttribute("Breakable", true)
		end
	end

	-- Outer walls: breakable cardboard tiles, so bombs can blow holes in them and sharks can chew
	-- their way in. The roof stays solid.
	local wallHeight = roofY + 2
	local rows = math.ceil(wallHeight / 8)
	local tileHeight = wallHeight / rows
	local function wallTiles(center: Vector3, length: number, alongX: boolean)
		local count = math.ceil(length / 8)
		local tileWidth = length / count
		for i = 0, count - 1 do
			for row = 0, rows - 1 do
				local offset = -length / 2 + tileWidth / 2 + i * tileWidth
				local position = center + (if alongX then Vector3.new(offset, 0, 0) else Vector3.new(0, 0, offset)) + Vector3.new(0, tileHeight / 2 + row * tileHeight, 0)
				local size = if alongX then Vector3.new(tileWidth, tileHeight, 2) else Vector3.new(2, tileHeight, tileWidth)
				local color = if (i + row) % 2 == 0 then Colors.CardboardDark else Color3.fromRGB(140, 102, 66)
				local tile = Craft.block(breakables, CFrame.new(position), size, color, M.Cardboard)
				tile.Name = "WallTile"
				tile:SetAttribute("Breakable", true)
			end
		end
	end
	for _, side in { -1, 1 } do
		wallTiles(at(0, 0, side * (D / 2 + 1)), W + 4, true) -- front and back
		wallTiles(at(side * (W / 2 + 1), 0, 0), D, false) -- left and right
	end
	Craft.block(model, CFrame.new(at(0, roofY + 1, 0)), Vector3.new(W + 4, 2, D + 4), Colors.Cardboard)

	-- Green acid all around and underneath. Fall through a hole in the floor or out of a broken wall
	-- and you land in it: popped.
	local acid = Craft.block(model, CFrame.new(at(0, -16, 0)), Vector3.new(W + 160, 2, D + 160), Color3.fromRGB(110, 255, 70), M.Neon, { CanCollide = false, CanQuery = false, Name = "Acid" })
	acid.Transparency = 0.15
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(110, 255, 70)
	glow.Range = 40
	glow.Brightness = 1.5
	glow.Parent = acid
	local fizz = Instance.new("ParticleEmitter")
	fizz.Color = ColorSequence.new(Color3.fromRGB(170, 255, 120))
	fizz.LightEmission = 0.6
	fizz.Size = NumberSequence.new(0.6, 0)
	fizz.Lifetime = NumberRange.new(1, 2)
	fizz.Speed = NumberRange.new(2, 5)
	fizz.Rate = 60
	fizz.SpreadAngle = Vector2.new(10, 10)
	fizz.EmissionDirection = Enum.NormalId.Top
	fizz.Parent = acid
	acid.Touched:Connect(function(hit)
		local character, humanoid = Util.characterFromPart(hit)
		if character and humanoid and humanoid.Health > 0 and Util.kill(humanoid) then
			Util.soundAt("AcidFizz", hit.Position)
			Remotes.fireAll("Poof", { position = hit.Position, color = Color3.fromRGB(110, 255, 70) })
		end
	end)

	for wallIndex, rotation in { 0, math.pi / 2, math.pi, -math.pi / 2 } do
		decorateWall(decor, O, W, D, floors, H, rotation, wallIndex - 1)
	end

	-- Reception desk against the back wall.
	local deskZ = -D / 2 + 6
	Craft.block(model, CFrame.new(at(0, 2, deskZ)), Vector3.new(12, 4, 3), Colors.Wood, M.Wood)
	Craft.block(decor, CFrame.new(at(0, 4.15, deskZ)), Vector3.new(12.4, 0.3, 3.4), Colors.Felt, M.Felt, Craft.DECOR)
	Craft.label(decor, at(0, 2, deskZ + 1.6), 9, 1.6, "RECEPTION", Colors.Paper)

	-- Ramp lanes: odd ramps along the back wall, even ramps along the front wall.
	local laneZ = { -D / 2 + BLOCK / 2, D / 2 - BLOCK / 2 }
	local function rampFor(level: number)
		local lane = if level % 2 == 1 then 1 else 2
		local direction = if lane == 1 then 1 else -1 -- back ramps climb toward +X, front ramps toward -X
		local startX = -direction * (W / 2 - BLOCK)
		return laneZ[lane], startX, startX + direction * RAMP_RUN
	end

	-- Foam floors 2-5, each with the atrium hole and a gap above the ramp coming up to it.
	for level = 1, floors - 1 do
		local top = level * H
		local rampZ, rampStartX, rampEndX = rampFor(level)
		local gapMin, gapMax = math.min(rampStartX, rampEndX), math.max(rampStartX, rampEndX)

		for i = 0, W / BLOCK - 1 do
			for j = 0, D / BLOCK - 1 do
				local x = -W / 2 + BLOCK / 2 + i * BLOCK
				local z = -D / 2 + BLOCK / 2 + j * BLOCK
				local inAtrium = math.abs(x) < ATRIUM_HALF and math.abs(z) < ATRIUM_HALF
				local inRampGap = z == rampZ and x > gapMin - BLOCK / 2 and x < gapMax
				if not inAtrium and not inRampGap then
					Craft.foam(breakables, CFrame.new(at(x, top - 1, z)), Vector3.new(BLOCK, 2, BLOCK), (i + j) % 2 == 0)
				end
			end
		end

		-- Low wooden railings around the atrium.
		for _, side in { -1, 1 } do
			for _, size in { Vector3.new(ATRIUM_HALF * 2, RAILING_HEIGHT, 0.4), Vector3.new(0.4, RAILING_HEIGHT, ATRIUM_HALF * 2) } do
				local offset = if size.X > 1 then Vector3.new(0, 0, side * ATRIUM_HALF) else Vector3.new(side * ATRIUM_HALF, 0, 0)
				local rail = Craft.block(breakables, CFrame.new(at(0, top + RAILING_HEIGHT / 2, 0) + offset), size, Colors.WoodDark, M.Wood)
				rail.Name = "Railing"
				rail:SetAttribute("Breakable", true)
			end
		end

		-- The ramp from the floor below up to this one.
		local ramp = buildRamp(breakables, at(rampStartX, top - H, rampZ), at(rampEndX, top, rampZ), BLOCK - 0.4)
		ramp.Parent = breakables
	end

	-- Foam pillars wrapped in brown packing paper, one segment per floor.
	for _, spot in { Vector2.new(-20, -20), Vector2.new(20, -20), Vector2.new(-20, 20), Vector2.new(20, 20), Vector2.new(-40, 0), Vector2.new(40, 0) } do
		for level = 0, floors - 1 do
			local bottom = level * H
			local segmentHeight = H - 2
			local pillar = Craft.cylinder(breakables, at(spot.X, bottom + segmentHeight / 2, spot.Y), segmentHeight, 5, "Y", Color3.fromRGB(178, 140, 96), M.Cardboard)
			pillar.Name = "Pillar"
			pillar:SetAttribute("Breakable", true)
		end
	end

	-- The marquee hanging in the middle of the atrium, visible from every floor.
	local signY = roofY - 7
	for _, turn in { 0, math.pi } do
		local face = Instance.new("Model")
		face.Name = "Marquee"
		Craft.sign(face, at(0, signY, 0.6), 30, 7, "HOTEL KABOOM", { bulbs = true, textColor = Colors.Felt })
		face.Parent = decor
		face:PivotTo(CFrame.new(at(0, signY, 0)) * CFrame.Angles(0, turn, 0) * CFrame.new(-at(0, signY, 0)) * face:GetPivot())
	end
	local timerHand = buildEggTimer(decor, at(-19, signY, 1.2))
	Craft.bunting(decor, at(-ATRIUM_HALF, signY + 5, 0), at(ATRIUM_HALF, signY + 5, 0))

	-- A low, cozy building hum that fills the hotel.
	local humSpot = Craft.block(decor, CFrame.new(at(0, roofY / 2, 0)), Vector3.one, Color3.new(), nil, Craft.DECOR)
	humSpot.Transparency = 1
	Util.loopSound("HotelHum", humSpot)

	Craft.boundaries(model, O, W + 40, roofY + 10, D + 40)

	model.Parent = workspace

	-- Everyone starts on the top floor, around the atrium.
	local topY = (floors - 1) * H + 3
	local spawns = {}
	for _, spot in { Vector2.new(-28, -28), Vector2.new(28, -28), Vector2.new(-28, 28), Vector2.new(28, 28), Vector2.new(0, -30), Vector2.new(0, 30) } do
		table.insert(spawns, CFrame.new(at(spot.X, topY, spot.Y)))
	end

	return {
		model = model,
		breakables = breakables,
		origin = O,
		width = W,
		depth = D,
		floors = floors,
		floorHeight = H,
		roofY = roofY,
		spawns = spawns,
		killY = O.Y - 25,
		-- Wall decorations (wallpaper, windows, lamps) near a spot where the wall was broken go too,
		-- so nothing is left floating in mid-air.
		cleanDecor = function(position: Vector3, radius: number)
			for _, part in decor:GetDescendants() do
				if part:IsA("BasePart") and (part.Position - position).Magnitude < radius then
					local offset = part.Position - O
					if math.abs(offset.X) > W / 2 - 3 or math.abs(offset.Z) > D / 2 - 3 then
						part:Destroy()
					end
				end
			end
		end,
		timerHand = timerHand,
		frozen = false,
	}
end

-- Score bubbles float above random intact floor blocks (or the lobby floor).
local function spawnBubbles(stage, ctx)
	while ctx.isActive() do
		local blocks = {}
		for _, block in stage.breakables:GetChildren() do
			if block.Name == "Foam" and block:IsA("BasePart") and block.Anchored then
				table.insert(blocks, block)
			end
		end
		local position
		if #blocks > 0 and math.random() < 0.8 then
			local block = blocks[math.random(1, #blocks)]
			position = block.Position + Vector3.new(0, 4, 0)
		else
			position = Util.randomAround(stage.origin, stage.width / 2 - 6, stage.depth / 2 - 6) + Vector3.new(0, 3, 0)
		end
		Score.spawnBubble(stage.model, position)
		task.wait(2.2)
	end
end

-- Drop a bomb at a random spot anywhere inside the hotel: every 15 seconds at first, getting faster
-- (down to half that) as the round goes on.
local function dropBombs(stage, ctx)
	while ctx.isActive() do
		local height = math.random(2, stage.roofY - 6)
		local spot = Util.randomAround(stage.origin, stage.width / 2 - 6, stage.depth / 2 - 6) + Vector3.new(0, height, 0)
		task.spawn(Bombs.plant, stage, spot)
		task.wait(Config.PlantedBombInterval * (1 - 0.5 * ctx.progress()))
	end
end

-- CHAOS MODE: one big flying shark chews its way in a few seconds into the round and roams the
-- hotel until the round ends.
local function sharkAttacks(stage, ctx)
	task.wait(Config.Chaos.firstShark)
	if ctx.isActive() then
		FlyingShark.attack(stage, ctx)
	end
end

function BombHotel.run(stage, ctx)
	task.spawn(spawnBubbles, stage, ctx)

	-- Sometimes the round is CHAOTIC: double points, but sharks come through the walls.
	if RoundControl.forceChaos or math.random() < Config.Chaos.chance then
		RoundControl.forceChaos = false
		Score.setRoundMultiplier(Config.Chaos.scoreMultiplier)
		Remotes.fireAll("Chaos", { multiplier = Config.Chaos.scoreMultiplier })
		task.spawn(sharkAttacks, stage, ctx)
	end

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

	dropBombs(stage, ctx)
end

-- Round over: everything stops exactly where it is.
function BombHotel.freeze(stage)
	stage.frozen = true
	for _, part in stage.model:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.Anchored = true
		end
	end
end

return BombHotel
