-- Bomb Hotel CHAOS MODE sharks: big, battle-scarred great whites that burst in through the hotel's
-- outer walls and charge across the building, jaws snapping. A red crack glows on the wall first so
-- players get a moment to dive out of the way.
--
-- Look (based on the reference art): charcoal back, grimy off-white belly, scars and gashes all over,
-- a torn dorsal fin, a chunk bitten out of the tail, a gaping mouth with rows of jagged teeth (one
-- snapped off), dark blood around the jaws and a dead black eye.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)
local Remotes = require(script.Parent.Parent.Remotes)
local Util = require(script.Parent.Parent.Util)

local FlyingShark = {}

local CHARCOAL = Color3.fromRGB(42, 46, 52)
local BELLY = Color3.fromRGB(196, 194, 186)
local SCAR = Color3.fromRGB(150, 146, 140)
local GASH = Color3.fromRGB(92, 22, 26)
local BLOOD = Color3.fromRGB(70, 12, 16)
local TOOTH = Color3.fromRGB(232, 228, 214)
local SKIN = Enum.Material.SmoothPlastic
local BITE_RANGE = 6

local NO_COLLIDE = { CanCollide = false, CanQuery = false, CanTouch = false }

local function part(model: Instance, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Craft.block(model, CFrame.identity, size, color, material or SKIN, NO_COLLIDE)
	if shape then
		p.Shape = shape
	end
	p.CastShadow = false
	return p
end

-- Builds the shark around the origin, facing +X. Returns the model, its parts with their offsets
-- (for moving it), and the lower jaw (which opens and shuts).
local function build(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "ChaosShark"
	local pieces = {}
	local function add(p: Part, offset: CFrame)
		table.insert(pieces, { part = p, offset = offset })
	end

	-- Body: a thick charcoal torpedo with a pale belly.
	add(part(model, Vector3.new(12, 5.6, 5.2), CHARCOAL, SKIN, Enum.PartType.Cylinder), CFrame.identity)
	add(part(model, Vector3.new(5.8, 5.8, 5.8), CHARCOAL, SKIN, Enum.PartType.Ball), CFrame.new(5.2, 0.2, 0))
	add(part(model, Vector3.new(11, 2.2, 4.6), BELLY, SKIN), CFrame.new(0.6, -2, 0))
	add(part(model, Vector3.new(4.6, 3.6, 3.6), CHARCOAL, SKIN, Enum.PartType.Cylinder), CFrame.new(-7.5, 0, 0))
	add(part(model, Vector3.new(3, 2.4, 2.4), CHARCOAL, SKIN, Enum.PartType.Cylinder), CFrame.new(-10.5, 0, 0))

	-- Tail fin, with a chunk bitten out of the top lobe.
	add(part(model, Vector3.new(0.4, 5.4, 2.2), CHARCOAL, SKIN), CFrame.new(-12.4, 2.2, 0) * CFrame.Angles(0, 0, math.rad(-35)))
	add(part(model, Vector3.new(0.4, 3.6, 2), CHARCOAL, SKIN), CFrame.new(-12.2, -1.8, 0) * CFrame.Angles(0, 0, math.rad(35)))
	add(part(model, Vector3.new(0.5, 1.2, 1.2), BLOOD, SKIN), CFrame.new(-13.2, 3.4, 0) * CFrame.Angles(0, 0, math.rad(-35))) -- the bitten edge

	-- Torn dorsal fin: two pieces with a notch ripped out between them.
	add(part(model, Vector3.new(3.4, 4.4, 0.5), CHARCOAL, SKIN), CFrame.new(-0.4, 4, 0) * CFrame.Angles(0, 0, math.rad(-28)))
	add(part(model, Vector3.new(1.4, 1.6, 0.55), GASH, SKIN), CFrame.new(-0.9, 5.2, 0) * CFrame.Angles(0, 0, math.rad(-28)))
	-- Pectoral fins.
	for _, side in { -1, 1 } do
		add(part(model, Vector3.new(4, 0.4, 2.6), CHARCOAL, SKIN), CFrame.new(1.6, -2.4, side * 3.2) * CFrame.Angles(math.rad(side * -20), math.rad(side * 30), 0))
	end

	-- Scars and gashes along both sides.
	local scars = {
		{ 2, 1.2, 0.18, 3.4, 25, SCAR },
		{ -2.5, 0.4, 0.14, 4.2, -15, SCAR },
		{ -5, 1.4, 0.2, 2.6, 40, GASH },
		{ 0, -0.6, 0.22, 3, 70, GASH },
		{ 3.6, 2, 0.12, 2.2, -50, SCAR },
	}
	for _, side in { -1, 1 } do
		for _, s in scars do
			add(part(model, Vector3.new(s[4], s[3], 0.1), s[6], SKIN), CFrame.new(s[1], s[2], side * 2.62) * CFrame.Angles(0, 0, math.rad(s[5])))
		end
		-- Gills.
		for i = 0, 3 do
			add(part(model, Vector3.new(0.15, 2, 0.1), Color3.fromRGB(28, 30, 34), SKIN), CFrame.new(2.6 - i * 0.55, 0.2, side * 2.65))
		end
		-- Dead black eye with a thin pale ring.
		add(part(model, Vector3.new(0.12, 1, 1), SCAR, SKIN, Enum.PartType.Cylinder), CFrame.new(6.3, 1.2, side * 2.35) * CFrame.Angles(0, math.rad(90), 0))
		add(part(model, Vector3.new(0.2, 0.8, 0.8), Color3.fromRGB(8, 8, 10), Enum.Material.Glass, Enum.PartType.Cylinder), CFrame.new(6.35, 1.2, side * 2.42) * CFrame.Angles(0, math.rad(90), 0))
	end

	-- Upper jaw: rows of jagged teeth (one snapped short) and blood around the mouth.
	add(part(model, Vector3.new(3.4, 0.8, 4.4), BELLY, SKIN), CFrame.new(6.4, -1.1, 0))
	add(part(model, Vector3.new(3.6, 0.6, 4.6), BLOOD, SKIN), CFrame.new(6.3, -1.5, 0))
	for i = 0, 5 do
		for _, z in { -1.7, -0.6, 0.6, 1.7 } do
			local length = if i == 2 and z == 0.6 then 0.3 else 0.9 -- the broken one
			add(part(model, Vector3.new(0.3, length, 0.3), TOOTH, SKIN), CFrame.new(5.1 + i * 0.45, -1.9 - length / 2 + 0.45, z) * CFrame.Angles(0, 0, math.rad(45)))
		end
	end

	-- Lower jaw on a hinge, with its own teeth and blood.
	local jaw = Instance.new("Model")
	jaw.Name = "Jaw"
	jaw.Parent = model
	local jawPieces = {}
	local function addJaw(p: Part, offset: CFrame)
		p.Parent = jaw
		table.insert(jawPieces, { part = p, offset = offset })
	end
	addJaw(part(model, Vector3.new(3.8, 0.9, 4.2), BELLY, SKIN), CFrame.new(1.9, -0.45, 0))
	addJaw(part(model, Vector3.new(3.6, 0.5, 4.3), BLOOD, SKIN), CFrame.new(1.9, 0.05, 0))
	for i = 0, 5 do
		for _, z in { -1.6, -0.5, 0.5, 1.6 } do
			addJaw(part(model, Vector3.new(0.3, 0.8, 0.3), TOOTH, SKIN), CFrame.new(0.4 + i * 0.5, 0.5, z) * CFrame.Angles(0, 0, math.rad(45)))
		end
	end

	model.Parent = parent
	return model, pieces, jawPieces
end

-- One shark attack: warning crack on the wall, then it bursts in and charges across the hotel.
function FlyingShark.attack(stage, target: Player)
	local root = Util.rootPart(target)
	if not root then
		return
	end
	local settings = Config.Chaos
	local O, halfW, halfD = stage.origin, stage.width / 2, stage.depth / 2

	-- Come in through the outer wall nearest the target's side, at the target's height.
	local aim = root.Position
	local sides = {
		{ normal = Vector3.new(-1, 0, 0), wall = O.X - halfW },
		{ normal = Vector3.new(1, 0, 0), wall = O.X + halfW },
		{ normal = Vector3.new(0, 0, -1), wall = O.Z - halfD },
		{ normal = Vector3.new(0, 0, 1), wall = O.Z + halfD },
	}
	local side = sides[math.random(1, #sides)]
	local entry
	if side.normal.X ~= 0 then
		entry = Vector3.new(side.wall, aim.Y + 1, aim.Z + math.random(-10, 10))
	else
		entry = Vector3.new(aim.X + math.random(-10, 10), aim.Y + 1, side.wall)
	end

	-- The warning: a jagged red crack glowing on the inside of the wall.
	local crack = Instance.new("Model")
	crack.Name = "WallCrack"
	local facing = CFrame.lookAt(entry - side.normal * 0.4, entry - side.normal * 2)
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		local length = 3 + math.random() * 3
		local piece = Craft.block(crack, facing * CFrame.Angles(0, 0, angle) * CFrame.new(0, length / 2, 0), Vector3.new(0.3, length, 0.1), Color3.fromRGB(255, 40, 30), Enum.Material.Neon, NO_COLLIDE)
		piece.CastShadow = false
	end
	crack.Parent = stage.model
	Util.soundAt("WallCrack", entry)
	Remotes.fireAll("Rumble", { position = entry })
	task.wait(settings.warning)
	crack:Destroy()
	if stage.frozen or not stage.model.Parent then
		return
	end

	-- Burst in.
	local model, pieces, jawPieces = build(stage.model)
	local position = entry + side.normal * 14 -- start just outside the wall
	local currentRoot = Util.rootPart(target)
	local heading = ((if currentRoot then currentRoot.Position else aim) - position).Unit
	local travelled, maxTravel = 0, math.max(stage.width, stage.depth) * 1.6
	local jawTime = 0
	local bitten: { [Player]: boolean } = {}
	Util.soundAt("SharkRoar", entry)
	Util.soundAt("BlockBreak", entry)
	Remotes.fireAll("Boom", { position = entry, radius = 4 })

	local finished = false
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if stage.frozen or not model.Parent then
			finished = true
			connection:Disconnect()
			return
		end

		-- Steer a little toward the target for the first stretch, then commit to a straight line.
		local targetRoot = Util.rootPart(target)
		if targetRoot and travelled < maxTravel * 0.35 then
			local wanted = (targetRoot.Position - position).Unit
			heading = heading:Lerp(wanted, math.min(1, dt * 1.5)).Unit
		end
		local step = settings.sharkSpeed * dt
		position += heading * step
		travelled += step

		-- Pose: body facing along the heading, with a slow side-to-side sway, jaw snapping.
		jawTime += dt
		local sway = math.sin(jawTime * 6) * 0.12
		local rootFrame = CFrame.lookAt(position, position + heading) * CFrame.Angles(0, math.rad(90) + sway, 0)
		for _, piece in pieces do
			piece.part.CFrame = rootFrame * piece.offset
		end
		local open = (math.sin(jawTime * 9) + 1) / 2 * 0.6
		local hinge = rootFrame * CFrame.new(4.2, -1.6, 0) * CFrame.Angles(0, 0, -open)
		for _, piece in jawPieces do
			piece.part.CFrame = hinge * piece.offset
		end

		-- Chomp anyone in reach of the mouth.
		local mouth = rootFrame * Vector3.new(6.5, -1, 0)
		for _, player in Players:GetPlayers() do
			local humanoid = Util.aliveHumanoid(player)
			local playerRoot = Util.rootPart(player)
			if humanoid and playerRoot and not bitten[player] and (playerRoot.Position - mouth).Magnitude < BITE_RANGE then
				bitten[player] = true
				Util.playSound("Chomp", pieces[1].part)
				Util.kill(humanoid)
			end
		end

		if travelled >= maxTravel then
			finished = true
			connection:Disconnect()
			model:Destroy()
		end
	end)

	while not finished do
		task.wait(0.2)
	end
end

return FlyingShark
