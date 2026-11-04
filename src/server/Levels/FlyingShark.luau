-- The Bomb Hotel CHAOS MODE shark: one huge, battle-scarred flying great white per chaos round.
-- A red crack glows on an outer wall first, then the shark appears and has to CHEW its way in, one
-- block at a time. Inside, it flops slowly around the hotel on its own wandering path (it doesn't
-- chase anyone), biting through any wall, floor or pillar in its way and chomping whoever it hits.
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
local Bombs = require(script.Parent.Bombs)

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

-- Scales the whole shark up (sizes and positions), so one big shark is built from the same plan.
local function scaleUp(list, scale: number)
	for _, piece in list do
		piece.part.Size *= scale
		piece.offset = CFrame.new(piece.offset.Position * scale) * piece.offset.Rotation
	end
end

-- The chaos shark: a red crack warns where it'll come in, it chews its way through the outer wall,
-- then it flies around the hotel on its own wandering path until the round ends, chewing through
-- anything in its way and chomping anyone it runs into. It doesn't chase people.
function FlyingShark.attack(stage, ctx)
	local settings = Config.Chaos
	local S = settings.sharkScale
	local O, halfW, halfD = stage.origin, stage.width / 2, stage.depth / 2

	-- Pick a random spot on a random outer wall to come in through.
	local sides = {
		{ normal = Vector3.new(-1, 0, 0), wall = O.X - halfW },
		{ normal = Vector3.new(1, 0, 0), wall = O.X + halfW },
		{ normal = Vector3.new(0, 0, -1), wall = O.Z - halfD },
		{ normal = Vector3.new(0, 0, 1), wall = O.Z + halfD },
	}
	local side = sides[math.random(1, #sides)]
	local height = O.Y + math.random(6, stage.roofY - 8)
	local entry = if side.normal.X ~= 0
		then Vector3.new(side.wall, height, O.Z + math.random(-30, 30))
		else Vector3.new(O.X + math.random(-30, 30), height, side.wall)

	-- The warning: a big jagged red crack glowing on the inside of the wall.
	local crack = Instance.new("Model")
	crack.Name = "WallCrack"
	local facing = CFrame.lookAt(entry - side.normal * 0.4, entry - side.normal * 2)
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		local length = (3 + math.random() * 3) * S
		local piece = Craft.block(crack, facing * CFrame.Angles(0, 0, angle) * CFrame.new(0, length / 2, 0), Vector3.new(0.4, length, 0.1), Color3.fromRGB(255, 40, 30), Enum.Material.Neon, NO_COLLIDE)
		piece.CastShadow = false
	end
	crack.Parent = stage.model
	Util.soundAt("WallCrack", entry)
	Remotes.fireAll("Rumble", { position = entry })
	task.wait(settings.warning)
	crack:Destroy()
	if stage.frozen or not stage.model.Parent or not ctx.isActive() then
		return
	end

	-- It appears just outside the wall, facing in.
	local model, pieces, jawPieces = build(stage.model)
	scaleUp(pieces, S)
	scaleUp(jawPieces, S)
	local position = entry + side.normal * 9 * S
	local heading = -side.normal
	local bitten: { [Player]: boolean } = {}
	local clock, chewTimer = 0, 0
	Util.soundAt("SharkRoar", entry)

	-- Wandering: fly toward a random spot inside the hotel, then pick another one.
	local function randomSpot(): Vector3
		return Vector3.new(
			O.X + math.random(-(halfW - 10), halfW - 10),
			O.Y + math.random(5, stage.roofY - 6),
			O.Z + math.random(-(halfD - 10), halfD - 10)
		)
	end
	local goal = entry - side.normal * 30 -- first, straight in through the hole it makes

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { stage.breakables }

	local finished = false
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if stage.frozen or not model.Parent or not ctx.isActive() then
			finished = true
			connection:Disconnect()
			if model.Parent and not stage.frozen then
				Remotes.fireAll("Poof", { position = position, color = CHARCOAL })
				model:Destroy()
			end
			return
		end
		clock += dt
		chewTimer -= dt

		-- Reached the spot it was heading for? Pick a new one somewhere else.
		if (goal - position).Magnitude < 6 * S then
			goal = randomSpot()
		end
		heading = heading:Lerp((goal - position).Unit, math.min(1, dt * 0.8)).Unit

		-- Anything breakable right in front of its mouth has to be chewed through first.
		local mouthAhead = position + heading * 7 * S
		local blocking = nil
		for _, part in workspace:GetPartBoundsInRadius(mouthAhead, 3.5 * S, params) do
			if part:GetAttribute("Breakable") and part.Anchored then
				blocking = part
				break
			end
		end
		local open
		if blocking then
			-- CHOMP: one block at a time, with a short pause between bites.
			open = (math.sin(clock * 14) + 1) / 2 * 0.7
			if chewTimer <= 0 then
				chewTimer = settings.sharkChew
				Util.playSound("Chomp", pieces[1].part)
				Bombs.breakBlock(stage, blocking, position)
			end
		else
			open = (math.sin(clock * 7) + 1) / 2 * 0.55
			position += heading * settings.sharkSpeed * dt
		end

		-- Pose: flopping back and forth (rolling, wiggling and bobbing) as it flies.
		local roll = math.sin(clock * 5) * 0.4
		local wiggle = math.sin(clock * 7) * 0.22
		local bob = Vector3.new(0, math.sin(clock * 3) * 0.6 * S, 0)
		local rootFrame = CFrame.lookAt(position + bob, position + bob + heading) * CFrame.Angles(0, math.rad(90) + wiggle, 0) * CFrame.Angles(roll, 0, 0)
		for _, piece in pieces do
			piece.part.CFrame = rootFrame * piece.offset
		end
		local hinge = rootFrame * CFrame.new(4.2 * S, -1.6 * S, 0) * CFrame.Angles(0, 0, -open)
		for _, piece in jawPieces do
			piece.part.CFrame = hinge * piece.offset
		end

		-- Chomp anyone it runs into (each player only once per round).
		local mouth = rootFrame * Vector3.new(6.5 * S, -1 * S, 0)
		for _, player in Players:GetPlayers() do
			local humanoid = Util.aliveHumanoid(player)
			local playerRoot = Util.rootPart(player)
			if humanoid and playerRoot and not bitten[player] and (playerRoot.Position - mouth).Magnitude < BITE_RANGE * S then
				bitten[player] = true
				Util.playSound("Chomp", pieces[1].part)
				Util.kill(humanoid)
			end
		end
	end)

	while not finished do
		task.wait(0.2)
	end
end

return FlyingShark
