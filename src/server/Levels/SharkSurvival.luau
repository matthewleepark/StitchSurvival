-- Shark Survival: a 300 by 300 stud ocean of blue tissue paper with foam rafts floating on it,
-- and a clockwork shark underneath.
--
--   * The water is real Roblox water (so you can swim), covered by a grid of thin, see-through
--     blue tissue-paper sheets that gently tilt and bob like waves (animated on each player's
--     screen). The whole ocean rustles constantly.
--   * Rafts are six-sided blocks of light white foam, 12 studs across. They really float: they
--     bob, tip when you stand near an edge, and dip under when several people crowd one side.
--     A soft spring keeps each one from drifting away. Landing on one squeaks; an edge dipping
--     under sloshes.
--   * Underwater you use up air (better scuba gear = more air) and start to drown at zero.
--   * When the shark smashes a raft it SNAPs into five pieces that sink with a gurgle, and a
--     fresh raft pops back in its place 12 seconds later.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)
local Remotes = require(script.Parent.Parent.Remotes)
local Score = require(script.Parent.Parent.Score)
local Util = require(script.Parent.Parent.Util)
local ClockworkShark = require(script.Parent.ClockworkShark)

local Colors = Config.Colors
local M = Craft.Material

local RAFT_SIZE = 12
local RAFT_SPACING = 20
local RAFT_GRID = 8 -- 8 x 8 rafts in the middle of the ocean
local RAFT_DENSITY = 0.08 -- very light, so a few players can tip it
local RAFT_REBUILD_TIME = 12
local SHEET_SIZE = 20
local DROWN_DAMAGE_PER_SECOND = 15
local OXYGEN_REFILL_PER_SECOND = 4

local SharkSurvival = {}

local function waterRegion(stage): (CFrame, Vector3)
	local O = stage.origin
	return CFrame.new(O + Vector3.new(0, stage.waterDepth / 2, 0)), Vector3.new(stage.width, stage.waterDepth, stage.depth)
end

-- A hexagonal foam raft: three 12-stud bars crossed at 60 degrees and welded together.
local function buildRaft(stage, home: Vector3)
	local raft = Instance.new("Model")
	raft.Name = "Raft"

	-- Three bars 12 long and 12/sqrt(3) wide, turned 0/60/120 degrees, make a perfect hexagon.
	local barWidth = RAFT_SIZE / math.sqrt(3)
	local core
	for i = 0, 2 do
		local bar = Craft.block(raft, CFrame.new(home) * CFrame.Angles(0, math.rad(60 * i), 0), Vector3.new(RAFT_SIZE, 2, barWidth), if i == 0 then Colors.Foam else Colors.FoamShade, M.Foam)
		bar.Anchored = false
		bar.CustomPhysicalProperties = PhysicalProperties.new(RAFT_DENSITY, 0.8, 0.1)
		if core then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = core
			weld.Part1 = bar
			weld.Parent = bar
		else
			core = bar
			bar.Name = "Core"
		end
	end
	raft.PrimaryPart = core

	-- A soft sideways spring back to its home spot. Up/down and tipping are left to the water.
	local attachment = Instance.new("Attachment")
	attachment.Parent = core
	local spring = Instance.new("AlignPosition")
	spring.Mode = Enum.PositionAlignmentMode.OneAttachment
	spring.Attachment0 = attachment
	spring.Position = home
	spring.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	spring.MaxAxesForce = Vector3.new(4000, 0, 4000)
	spring.Responsiveness = 6
	spring.Parent = core

	raft.Parent = stage.rafts
	core:SetNetworkOwner(nil)

	local entry = { model = raft, core = core, home = home, broken = false, tipped = false, lastSqueak = 0 }

	-- Damp foam squeak when someone lands on it.
	for _, bar in raft:GetChildren() do
		if bar:IsA("BasePart") then
			bar.Touched:Connect(function(hit)
				local character = Util.characterFromPart(hit)
				if character and hit.AssemblyLinearVelocity.Y < -8 and os.clock() - entry.lastSqueak > 0.5 then
					entry.lastSqueak = os.clock()
					Util.playSound("RaftSqueak", core)
					Util.playSound("PlatformSwish", core)
				end
			end)
		end
	end
	return entry
end

-- The shark bit a raft: SNAP, five heavy pieces scatter and sink, then a new raft pops back.
local function smashRaft(stage, raft)
	if raft.broken or stage.frozen then
		return
	end
	raft.broken = true
	local center = raft.core.Position
	Util.soundAt("PlatformSnap", center)
	raft.model:Destroy()

	for i = 1, 5 do
		local angle = i / 5 * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * 3, 0, math.sin(angle) * 3)
		local piece = Craft.block(workspace, CFrame.new(center + offset) * CFrame.Angles(0, angle, 0), Vector3.new(4.5, 1.8, 3.5), Colors.Foam, M.Foam)
		piece.Name = "RaftPiece"
		piece.Anchored = false
		piece.CustomPhysicalProperties = PhysicalProperties.new(3, 0.5, 0.2) -- heavy now: it sinks
		piece.AssemblyLinearVelocity = offset.Unit * 12 + Vector3.new(0, 10, 0)
		piece.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-6, 6), math.random(-6, 6))
		Craft.tag(piece, "LooseDebris")
		Debris:AddItem(piece, 5) -- the debris cleaner
	end
	task.delay(0.6, Util.soundAt, "PlatformSink", center)

	task.delay(RAFT_REBUILD_TIME, function()
		if stage.model.Parent and not stage.frozen then
			local fresh = buildRaft(stage, raft.home)
			for key, value in fresh do
				raft[key] = value
			end
			Util.playSound("TeleportPop", raft.core)
			Remotes.fireAll("Poof", { position = raft.home + Vector3.new(0, 2, 0), color = Colors.Foam })
		end
	end)
end

function SharkSurvival.build(def)
	local O = def.origin
	local W, D = def.width, def.depth
	local waterDepth = def.waterDepth
	local waterTop = waterDepth

	local model = Instance.new("Model")
	model.Name = "SharkSurvival"
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	local rafts = Instance.new("Folder")
	rafts.Name = "Rafts"
	rafts.Parent = model

	local function at(x: number, y: number, z: number?): Vector3
		return O + Vector3.new(x, y, z or 0)
	end

	-- Sandy felt seabed with rocks and swaying seaweed.
	Craft.block(model, CFrame.new(at(0, -2)), Vector3.new(W + 8, 4, D + 8), Colors.Sand, M.Felt)
	for _ = 1, 30 do
		local spot = Util.randomAround(O, W / 2 - 8, D / 2 - 8)
		Craft.ball(decor, spot + Vector3.new(0, -1, 0), math.random(4, 9), Color3.fromRGB(130 + math.random(0, 30), 130, 140), M.Felt, Craft.DECOR)
	end
	for _ = 1, 90 do
		local height = math.random(6, 15)
		local spot = Util.randomAround(O, W / 2 - 4, D / 2 - 4)
		local weed = Craft.block(decor, CFrame.new(spot + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, math.random() * math.pi, 0), Vector3.new(1.2, height, 0.25), Colors.Seaweed, M.Felt, Craft.DECOR)
		weed:SetAttribute("Phase", math.random() * math.pi * 2)
		Craft.tag(weed, "Sway")
	end

	-- Walls all around: deep sea below the waterline, felt sky above.
	local wallHeight = waterTop + 40
	for _, side in { -1, 1 } do
		for _, alongX in { true, false } do
			local offset = if alongX then Vector3.new(0, 0, side * (D / 2 + 1)) else Vector3.new(side * (W / 2 + 1), 0, 0)
			local size = if alongX then Vector3.new(W + 4, 0, 2) else Vector3.new(2, 0, D + 4)
			Craft.block(model, CFrame.new(at(0, waterTop / 2) + offset), size + Vector3.new(0, waterTop, 0), Colors.SeaDeep, M.Felt)
			Craft.block(model, CFrame.new(at(0, waterTop + (wallHeight - waterTop) / 2) + offset), size + Vector3.new(0, wallHeight - waterTop, 0), Colors.Sky, M.Cardboard)
		end
	end

	-- Felt clouds and a cardboard sun on the back wall, plus the sign.
	local backZ = -D / 2 + 0.5
	for _, cloud in { { -110, 44 }, { -50, 50 }, { 20, 42 }, { 90, 48 } } do
		local center = at(cloud[1], cloud[2], backZ)
		Craft.disc(decor, center, 14, Color3.new(1, 1, 1), M.Felt, Craft.DECOR)
		Craft.disc(decor, center + Vector3.new(-8, -2, 0.05), 10, Color3.new(1, 1, 1), M.Felt, Craft.DECOR)
		Craft.disc(decor, center + Vector3.new(8, -2.5, 0.05), 9, Color3.new(1, 1, 1), M.Felt, Craft.DECOR)
	end
	local sun = at(120, 50, backZ + 0.2)
	Craft.disc(decor, sun, 16, Colors.Gold, M.Felt, Craft.DECOR)
	for i = 0, 7 do
		Craft.block(decor, CFrame.new(sun) * CFrame.Angles(0, 0, i / 8 * math.pi * 2) * CFrame.new(0, 12, -0.1), Vector3.new(2, 6, 0.2), Colors.Warning, M.Felt, Craft.DECOR)
	end
	Craft.sign(decor, at(0, waterTop + 26, backZ + 0.6), 50, 10, "SHARK SURVIVAL", { bulbs = true, textColor = Colors.SeaDeep })

	-- Real water (so you can swim), with the tissue-paper sheets floating on top.
	local cframe, size = waterRegion({ origin = O, width = W, depth = D, waterDepth = waterDepth })
	workspace.Terrain:FillBlock(cframe, size, Enum.Material.Water)
	local sheetIndex = 0
	for x = -W / 2 + SHEET_SIZE / 2, W / 2 - SHEET_SIZE / 2, SHEET_SIZE do
		for z = -D / 2 + SHEET_SIZE / 2, D / 2 - SHEET_SIZE / 2, SHEET_SIZE do
			sheetIndex += 1
			local color = if sheetIndex % 3 == 0 then Color3.fromRGB(150, 205, 245) else Colors.Sea
			local sheet = Craft.block(decor, CFrame.new(at(x, waterTop + 0.15, z)), Vector3.new(SHEET_SIZE + 1.5, 0.1, SHEET_SIZE + 1.5), color, M.Plastic, Craft.DECOR)
			sheet.Transparency = 0.45
			sheet.CastShadow = false
			sheet:SetAttribute("Phase", (x + z) * 0.05)
			Craft.tag(sheet, "Sheet")
		end
	end
	local rustleSpot = Craft.block(decor, CFrame.new(at(0, waterTop, 0)), Vector3.one, Color3.new(), nil, Craft.DECOR)
	rustleSpot.Transparency = 1
	Util.loopSound("WaterRustle", rustleSpot)

	Craft.boundaries(model, O, W, wallHeight, D)
	model.Parent = workspace

	local stage = {
		model = model,
		rafts = rafts,
		raftList = {},
		origin = O,
		width = W,
		depth = D,
		waterDepth = waterDepth,
		waterTop = O.Y + waterTop,
		spawns = {},
		killY = O.Y - 30,
		frozen = false,
		contains = function(position: Vector3): boolean
			return math.abs(position.X - O.X) <= W / 2 + 2 and math.abs(position.Z - O.Z) <= D / 2 + 2
		end,
	}

	-- The rafts, in a loose grid in the middle of the ocean.
	local half = (RAFT_GRID - 1) / 2 * RAFT_SPACING
	for i = 0, RAFT_GRID - 1 do
		for j = 0, RAFT_GRID - 1 do
			local jitter = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
			local home = at(-half + i * RAFT_SPACING, waterTop + 0.6, -half + j * RAFT_SPACING) + jitter
			table.insert(stage.raftList, buildRaft(stage, home))
		end
	end

	-- Spawn players on the rafts closest to the middle.
	local byDistance = table.clone(stage.raftList)
	table.sort(byDistance, function(a, b)
		return (a.home - O).Magnitude < (b.home - O).Magnitude
	end)
	for i = 1, math.min(12, #byDistance) do
		table.insert(stage.spawns, CFrame.new(byDistance[i].home + Vector3.new(0, 4, 0)))
	end

	stage.smashRaft = function(raft)
		smashRaft(stage, raft)
	end
	return stage
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

			if head.Position.Y < stage.waterTop - 0.3 then
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

-- Wet slosh when a raft tips far enough that an edge dips under.
local function updateRaftSounds(stage)
	for _, raft in stage.raftList do
		if not raft.broken and raft.core.Parent then
			local tilt = math.deg(math.acos(math.clamp(raft.core.CFrame.UpVector.Y, -1, 1)))
			local tipped = tilt > 12
			if tipped and not raft.tipped then
				Util.playSound("PlatformSlosh", raft.core)
			end
			raft.tipped = tipped
		end
	end
end

local function spawnBubbles(stage, ctx)
	while ctx.isActive() do
		local position
		if math.random() < 0.65 then
			local raft = stage.raftList[math.random(1, #stage.raftList)]
			position = raft.home + Vector3.new(math.random(-3, 3), 4.5, math.random(-3, 3))
		else
			-- Riskier bubbles underwater.
			position = Util.randomAround(stage.origin, 70, 70) + Vector3.new(0, math.random(4, stage.waterDepth - 4), 0)
		end
		Score.spawnBubble(stage.model, position)
		task.wait(1.2)
	end
end

function SharkSurvival.run(stage, ctx)
	workspace.Terrain.WaterColor = Colors.Sea
	workspace.Terrain.WaterTransparency = 0.6
	workspace.Terrain.WaterWaveSize = 0.08
	workspace.Terrain.WaterReflectance = 0.2

	local shark = ClockworkShark.new(stage)
	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		shark:update(dt, ctx.progress())
	end)
	task.spawn(spawnBubbles, stage, ctx)

	while ctx.isActive() do
		local dt = task.wait(0.1)
		updateOxygen(stage, dt)
		updateRaftSounds(stage)
	end

	heartbeat:Disconnect()
	shark:destroy()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Oxygen", nil)
	end
end

-- Round over: rafts stop exactly where they are.
function SharkSurvival.freeze(stage)
	stage.frozen = true
	for _, raft in stage.raftList do
		if raft.core.Parent then
			raft.core.AssemblyLinearVelocity = Vector3.zero
			raft.core.AssemblyAngularVelocity = Vector3.zero
			raft.core.Anchored = true
		end
	end
end

function SharkSurvival.cleanup(stage)
	local cframe, size = waterRegion(stage)
	workspace.Terrain:FillBlock(cframe, size + Vector3.new(8, 8, 8), Enum.Material.Air)
end

return SharkSurvival
