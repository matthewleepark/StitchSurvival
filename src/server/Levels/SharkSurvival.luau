-- Shark Survival: hop between floating cardboard crates while a clockwork shark hunts you.
-- Orange-taped crates sink when you stand on them, and more crates turn orange over time.
-- Underwater you lose oxygen (better scuba gear = more air), but there are bonus bubbles down there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)
local Score = require(script.Parent.Parent.Score)
local Util = require(script.Parent.Parent.Util)
local ClockworkShark = require(script.Parent.ClockworkShark)

local Colors = Config.Colors
local M = Craft.Material

local WATER_DEPTH = 20
local CRATE_XS = { -42, -28, -14, 0, 14, 28, 42 }
local CRATE_TOP = 22.5
local SINK_DISTANCE = 8
local DROWN_DAMAGE_PER_SECOND = 15
local OXYGEN_REFILL_PER_SECOND = 4
local TAPE_COLOR = Color3.fromRGB(235, 215, 160)

local SharkSurvival = {}

local function waterRegion(stage): (CFrame, Vector3)
	local O = stage.origin
	return CFrame.new(O + Vector3.new(0, WATER_DEPTH / 2, 0)), Vector3.new(stage.width, WATER_DEPTH, Config.StageDepth)
end

local function buildCrate(parent: Instance, center: Vector3, index: number)
	local crate = Instance.new("Model")
	crate.Name = "Crate"

	local box = Craft.block(crate, CFrame.new(center), Vector3.new(9, 3, 15), Colors.Cardboard, M.Cardboard)
	box.Name = "Box"
	crate.PrimaryPart = box

	-- Packing tape across the front, and a stamp on some crates.
	local front = center + Vector3.new(0, 0, 7.56)
	local tape = Craft.block(crate, CFrame.new(front), Vector3.new(9.05, 0.8, 0.1), TAPE_COLOR, M.Plastic, Craft.DECOR)
	tape.Name = "Tape"
	if index % 3 == 0 then
		Craft.label(crate, front + Vector3.new(-2, 0.9, 0.05), 4, 0.9, "FRAGILE", Colors.Felt)
	elseif index % 3 == 1 then
		Craft.label(crate, front + Vector3.new(2, -0.9, 0.05), 4.5, 0.8, "THIS SIDE UP", Colors.Ink)
	end

	crate.Parent = parent
	return {
		model = crate,
		box = box,
		tape = tape,
		home = crate:GetPivot(),
		sinking = false,
		busy = false,
	}
end

function SharkSurvival.build(def)
	local O = def.origin
	local W = def.width
	local depth = Config.StageDepth
	local wallZ = -depth / 2

	local model = Instance.new("Model")
	model.Name = "SharkSurvival"
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model

	local function at(x: number, y: number, z: number?): Vector3
		return O + Vector3.new(x, y, z or 0)
	end

	-- Sandy felt seabed with a few mounds.
	Craft.block(model, CFrame.new(at(0, -2)), Vector3.new(W + 8, 4, depth + 8), Colors.Sand, M.Felt)
	for _, x in { -38, -10, 22, 46 } do
		Craft.ball(decor, at(x, -1.5, -3), 7, Color3.fromRGB(220, 188, 128), M.Felt, Craft.DECOR)
	end

	-- Back wall: deep sea below the waterline, sky above.
	Craft.block(model, CFrame.new(at(0, WATER_DEPTH / 2, wallZ - 1)), Vector3.new(W + 8, WATER_DEPTH, 2), Colors.SeaDeep, M.Felt)
	Craft.block(model, CFrame.new(at(0, WATER_DEPTH + 25, wallZ - 1)), Vector3.new(W + 8, 50, 2), Colors.Sky, M.Cardboard)
	Craft.panel(decor, at(0, WATER_DEPTH - 3, wallZ + 0.1), W + 8, 6, Color3.fromRGB(55, 110, 180), M.Felt, { thickness = 0.1 })

	-- Seaweed (sways on the client), rocks and cardboard fish under the water.
	for _ = 1, 16 do
		local height = math.random(6, 13)
		local weed = Craft.block(decor, CFrame.new(at(math.random(-52, 52), height / 2, wallZ + 0.5)), Vector3.new(1.2, height, 0.2), Colors.Seaweed, M.Felt, Craft.DECOR)
		weed:SetAttribute("Phase", math.random() * math.pi * 2)
		Craft.tag(weed, "Sway")
	end
	for _, x in { -48, -20, 8, 34 } do
		Craft.disc(decor, at(x, 1.5, wallZ + 0.4), 4, Color3.fromRGB(130, 130, 140), M.Felt, Craft.DECOR)
	end
	local fishColors = { Colors.Warning, Colors.Gold, Color3.fromRGB(255, 120, 150), Color3.fromRGB(140, 220, 120) }
	for i = 1, 6 do
		local position = at(math.random(-48, 48), math.random(5, 16), wallZ + 0.7)
		local color = fishColors[i % #fishColors + 1]
		local direction = if i % 2 == 0 then 1 else -1
		Craft.disc(decor, position, 2.6, color, M.Felt, Craft.DECOR)
		Craft.diamond(decor, position - Vector3.new(direction * 1.7, 0, 0.05), 1.5, color, M.Felt, Craft.DECOR)
		Craft.disc(decor, position + Vector3.new(direction * 0.6, 0.35, 0.2), 0.6, Color3.new(1, 1, 1), M.Felt, Craft.DECOR)
		Craft.disc(decor, position + Vector3.new(direction * 0.65, 0.35, 0.3), 0.3, Color3.new(0, 0, 0), M.Plastic, Craft.DECOR)
	end

	-- Sky: felt clouds and a cardboard sun.
	for _, cloud in { { -40, 36 }, { -12, 41 }, { 14, 35 }, { 48, 40 } } do
		local center = at(cloud[1], cloud[2], wallZ + 0.4)
		Craft.disc(decor, center, 6, Color3.new(1, 1, 1), M.Felt, Craft.DECOR)
		Craft.disc(decor, center + Vector3.new(-3.6, -0.8, 0.05), 4.4, Color3.new(1, 1, 1), M.Felt, Craft.DECOR)
		Craft.disc(decor, center + Vector3.new(3.4, -1, 0.05), 4, Color3.new(1, 1, 1), M.Felt, Craft.DECOR)
	end
	local sun = at(-30, 44, wallZ + 0.5)
	Craft.disc(decor, sun, 7, Colors.Gold, M.Felt, Craft.DECOR)
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		Craft.block(decor, CFrame.new(sun) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 5.4, -0.1), Vector3.new(0.8, 2.4, 0.2), Colors.Warning, M.Felt, Craft.DECOR)
	end

	Craft.sign(decor, at(16, 45, wallZ + 1), 30, 7, "SHARK SURVIVAL", { bulbs = true, textColor = Colors.SeaDeep })
	Craft.bunting(decor, at(-W / 2, 39, wallZ + 1.4), at(W / 2, 39, wallZ + 1.4))

	-- Water: real terrain water so you can swim, dressed up with tissue-paper waves.
	local cframe, size = waterRegion({ origin = O, width = W })
	workspace.Terrain:FillBlock(cframe, size, Enum.Material.Water)

	local wave = 0
	for x = -W / 2 + 2, W / 2 - 2, 4 do
		wave += 1
		local front = Craft.cylinder(decor, at(x, WATER_DEPTH - 1, depth / 2 - 0.3), 0.4, 3.6, "Z", if wave % 2 == 0 then Colors.Sea else Color3.fromRGB(120, 190, 240), M.Plastic, Craft.DECOR)
		front.Transparency = 0.15
		front:SetAttribute("Phase", wave * 0.7)
		Craft.tag(front, "Wave")

		local back = Craft.cylinder(decor, at(x + 2, WATER_DEPTH - 0.6, wallZ + 0.8), 0.4, 4, "Z", Color3.fromRGB(60, 120, 190), M.Plastic, Craft.DECOR)
		back:SetAttribute("Phase", wave * 0.7 + math.pi)
		Craft.tag(back, "Wave")
	end
	-- Tinted "tissue paper" sheet over the front of the water.
	local sheet = Craft.block(decor, CFrame.new(at(0, (WATER_DEPTH - 2.5) / 2, depth / 2 - 0.05)), Vector3.new(W, WATER_DEPTH - 2.5, 0.05), Colors.Sea, M.Plastic, Craft.DECOR)
	sheet.Transparency = 0.82

	-- Floating crates, and sturdy docks at each end.
	local crates = {}
	for i, x in CRATE_XS do
		table.insert(crates, buildCrate(model, at(x, CRATE_TOP - 1.5, 0.5), i))
	end
	for _, side in { -1, 1 } do
		local x = side * (W / 2 - 4)
		Craft.block(model, CFrame.new(at(x, 23.5, 0.5)), Vector3.new(8, 1, 15), Colors.Wood, M.Wood)
		for _, z in { -6, 6 } do
			Craft.cylinder(decor, at(x - side * 3, 11.5, z), 24, 1.2, "Y", Colors.WoodDark, M.Wood, Craft.DECOR)
		end
	end

	-- Side columns.
	for _, side in { -1, 1 } do
		Craft.block(model, CFrame.new(at(side * (W / 2 + 2), 30, 0)), Vector3.new(4, 64, depth + 8), Colors.CardboardDark)
	end

	Craft.boundaries(model, O, W, 50)

	model.Parent = workspace

	local spawns = {}
	for i, crate in crates do
		spawns[i] = crate.home * CFrame.new(0, 4, Config.Layers[(i % 3) + 1] - 0.5)
	end

	return {
		model = model,
		origin = O,
		width = W,
		waterTop = O.Y + WATER_DEPTH,
		crates = crates,
		spawns = spawns,
		killY = O.Y - 30,
		contains = function(position: Vector3): boolean
			return math.abs(position.X - O.X) <= W / 2 + 2 and math.abs(position.Z - O.Z) <= depth
		end,
	}
end

local function markSinking(crate)
	crate.sinking = true
	crate.tape.Color = Colors.Warning
	crate.box.Color = Color3.fromRGB(210, 150, 100)
end

local function sink(crate)
	crate.busy = true
	-- Wobble first so players get a warning.
	for i = 1, 8 do
		local wobble = CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 3 else -3))
		crate.model:PivotTo(crate.home * wobble)
		task.wait(0.12)
	end

	local progress = Instance.new("NumberValue")
	progress.Changed:Connect(function(value)
		crate.model:PivotTo(crate.home * CFrame.new(0, -SINK_DISTANCE * value, 0))
	end)
	TweenService:Create(progress, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 1 }):Play()
	task.wait(3.8)
	TweenService:Create(progress, TweenInfo.new(1.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 0 }):Play()
	task.wait(1.6)
	progress:Destroy()
	crate.model:PivotTo(crate.home)
	crate.busy = false
end

local function updateOxygen(stage, dt: number)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		local humanoid = Util.aliveHumanoid(player)
		if head and humanoid and stage.contains(head.Position) then
			local gear = Config.getGear(player:GetAttribute("Gear"))
			local maxOxygen = if gear then gear.oxygen else Config.DefaultOxygen
			local oxygen = player:GetAttribute("Oxygen") or maxOxygen

			if head.Position.Y < stage.waterTop - 0.5 then
				oxygen = math.max(0, oxygen - dt)
				if oxygen <= 0 then
					humanoid:TakeDamage(DROWN_DAMAGE_PER_SECOND * dt)
				end
			else
				oxygen = math.min(maxOxygen, oxygen + OXYGEN_REFILL_PER_SECOND * dt)
			end

			player:SetAttribute("MaxOxygen", maxOxygen)
			player:SetAttribute("Oxygen", oxygen)
		end
	end
end

local function spawnBubbles(stage, ctx)
	while ctx.isActive() do
		local position
		if math.random() < 0.6 then
			local crate = stage.crates[math.random(1, #stage.crates)]
			position = crate.home.Position + Vector3.new(math.random(-3, 3), 4.5, Util.randomLayer() - 0.5)
		else
			-- Riskier bubbles underwater.
			position = stage.origin + Vector3.new(math.random(-48, 48), math.random(4, 15), Util.randomLayer())
		end
		Score.spawnBubble(stage.model, position)
		task.wait(1.8)
	end
end

function SharkSurvival.run(stage, ctx)
	workspace.Terrain.WaterColor = Colors.Sea
	workspace.Terrain.WaterTransparency = 0.5
	workspace.Terrain.WaterWaveSize = 0.05
	workspace.Terrain.WaterReflectance = 0.2

	-- Two crates start out sinking; the rest turn orange as time goes on.
	local order = table.clone(stage.crates)
	for i = #order, 2, -1 do
		local j = math.random(1, i)
		order[i], order[j] = order[j], order[i]
	end
	markSinking(order[1])
	markSinking(order[2])
	local nextToSink = 3

	for _, crate in stage.crates do
		crate.box.Touched:Connect(function(hit)
			if crate.sinking and not crate.busy then
				local character = Util.characterFromPart(hit)
				if character and Players:GetPlayerFromCharacter(character) then
					task.spawn(sink, crate)
				end
			end
		end)
	end

	local shark = ClockworkShark.new(stage)
	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		shark:update(dt, ctx.progress())
	end)
	task.spawn(spawnBubbles, stage, ctx)

	local sinceSink = 0
	while ctx.isActive() do
		local dt = task.wait(0.1)
		updateOxygen(stage, dt)

		sinceSink += dt
		if sinceSink > 22 - 10 * ctx.progress() and nextToSink <= #order then
			markSinking(order[nextToSink])
			nextToSink += 1
			sinceSink = 0
		end
	end

	heartbeat:Disconnect()
	shark:destroy()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Oxygen", nil)
	end
end

function SharkSurvival.cleanup(stage)
	local cframe, size = waterRegion(stage)
	workspace.Terrain:FillBlock(cframe, size + Vector3.new(0, 8, 0), Enum.Material.Air)
end

return SharkSurvival
