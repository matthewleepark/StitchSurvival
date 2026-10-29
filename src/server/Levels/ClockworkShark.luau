-- The clockwork shark.
--
-- Body: about 15 studs long, built from three plywood segments covered in coarse gray felt and
-- joined by brass hinges. Glowing gold clockwork gears spin in the gaps between segments, and a
-- wind-up key turns on its back. The segments swing side to side as it swims (faster when it's
-- hunting). Its plywood jaws are lined with white felt teeth and button eyes sit on each side.
--
-- Behavior:
--   Patrol: it cruises a loop of points around the ocean, a few studs under the paper surface.
--     Its motor purrs low and slow, muffled by the water.
--   Hunt: five times a second it looks for the closest living player within 45 studs (on a raft
--     or in the water). Once it locks on, the motor pitches up and races.
--   Swimmers: if it reaches a player in the water, its jaws CLACK shut on them. Instantly popped.
--   Raft riders: it gets underneath, then breaches up through the paper (RIP-CRUNCH), arcs
--     through the target and dives back in. Anyone it hits is popped, and any raft in its path
--     SNAPs into pieces.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)
local Remotes = require(script.Parent.Parent.Remotes)
local Score = require(script.Parent.Parent.Score)
local Util = require(script.Parent.Parent.Util)

local Colors = Config.Colors
local M = Craft.Material

local FELT_GRAY = Color3.fromRGB(128, 128, 136)
local PLYWOOD = Color3.fromRGB(200, 166, 116)
local BITE_RANGE = 4.5
local LEAP_TIME = 1.4
local LEAP_HIT_RANGE = 5.5
local LEAP_COOLDOWN = 3
local TARGET_CHECK_INTERVAL = 0.2
local PATROL_DEPTH = 5 -- studs under the surface while cruising

-- Segment lengths, front to back, and the gaps between them where the gears show.
local HEAD_LENGTH = 5
local MID_LENGTH = 4
local REAR_LENGTH = 3.4
local GAP = 0.6

local ClockworkShark = {}
ClockworkShark.__index = ClockworkShark

local NO_COLLIDE = { CanCollide = false, CanQuery = false, CanTouch = false }

-- Builds one part at the origin; pose() moves it into place every frame.
local function piece(model: Instance, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local part = Craft.block(model, CFrame.identity, size, color, material, NO_COLLIDE)
	if shape then
		part.Shape = shape
	end
	return part
end

function ClockworkShark.new(stage)
	local self = setmetatable({}, ClockworkShark)
	self.stage = stage
	self.yaw = 0
	self.pitch = 0
	self.swim = 0 -- drives the side-to-side wiggle
	self.gearAngle = 0
	self.jawOpen = 0
	self.jawTarget = 0
	self.state = "patrol"
	self.target = nil
	self.targetCheck = 0
	self.leapCooldown = 4
	self.mood = "patrol"

	-- Patrol loop: a ring of points around the middle of the ocean.
	self.nodes = {}
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		table.insert(self.nodes, stage.origin + Vector3.new(math.cos(angle) * 60, 0, math.sin(angle) * 60))
	end
	self.nodeIndex = 1
	self.position = self.nodes[1] + Vector3.new(0, stage.waterTop - stage.origin.Y - PATROL_DEPTH, 0)

	local model = Instance.new("Model")
	model.Name = "ClockworkShark"
	self.model = model

	-- Head: plywood box covered in felt, with a rounded snout, button eyes, and teeth.
	self.head = piece(model, Vector3.new(HEAD_LENGTH, 3.4, 3.6), FELT_GRAY, M.Felt)
	self.snout = piece(model, Vector3.new(3.4, 3.4, 3.4), FELT_GRAY, M.Felt, Enum.PartType.Ball)
	self.upperJaw = piece(model, Vector3.new(3, 0.6, 3.4), PLYWOOD, M.Wood)
	self.lowerJaw = piece(model, Vector3.new(3.6, 0.8, 3.2), PLYWOOD, M.Wood)
	self.eyes = {}
	for _, side in { -1, 1 } do
		table.insert(self.eyes, { white = piece(model, Vector3.new(0.3, 1.4, 1.4), Color3.new(1, 1, 1), M.Felt, Enum.PartType.Cylinder), button = piece(model, Vector3.new(0.3, 0.7, 0.7), Color3.fromRGB(30, 30, 30), M.Plastic, Enum.PartType.Cylinder), side = side })
	end
	self.teeth = {}
	for i = 0, 3 do
		for _, side in { -1, 1 } do
			table.insert(self.teeth, { upper = piece(model, Vector3.new(0.4, 0.6, 0.3), Color3.new(1, 1, 1), M.Felt), lower = piece(model, Vector3.new(0.4, 0.5, 0.3), Color3.new(1, 1, 1), M.Felt), x = 0.4 + i * 0.7, side = side })
		end
	end

	-- Middle and rear segments, a tail fin, a dorsal fin, and side fins.
	self.mid = piece(model, Vector3.new(MID_LENGTH, 3.2, 3.4), FELT_GRAY, M.Felt)
	self.rear = piece(model, Vector3.new(REAR_LENGTH, 2.6, 2.8), FELT_GRAY, M.Felt)
	self.tail = piece(model, Vector3.new(2.6, 2.6, 0.3), FELT_GRAY, M.Felt)
	self.dorsal = piece(model, Vector3.new(2.4, 2.4, 0.3), FELT_GRAY, M.Felt)
	self.fins = { piece(model, Vector3.new(1.8, 0.3, 1.8), FELT_GRAY, M.Felt), piece(model, Vector3.new(1.8, 0.3, 1.8), FELT_GRAY, M.Felt) }

	-- Brass hinges and glowing gears in the two gaps.
	self.hinges = { piece(model, Vector3.new(0.5, 2.4, 0.5), Colors.Gold, M.Metal), piece(model, Vector3.new(0.5, 2, 0.5), Colors.Gold, M.Metal) }
	self.gears = {}
	for _ = 1, 2 do
		local gear = piece(model, Vector3.new(0.4, 2.6, 2.6), Colors.Gold, M.Neon, Enum.PartType.Cylinder)
		local light = Instance.new("PointLight")
		light.Color = Colors.Gold
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = gear
		table.insert(self.gears, gear)
	end
	self.key = piece(model, Vector3.new(0.3, 1.6, 2.6), Colors.Gold, M.Metal)
	self.keyShaft = piece(model, Vector3.new(0.4, 1.4, 0.4), Colors.Gold, M.Metal)

	model.Parent = stage.model
	Craft.tag(self.mid, "Occluded")

	-- Clockwork motor: low and muffled while patrolling underwater, high and fast when hunting.
	self.motor = Util.loopSound("SharkMotor", self.mid)
	if self.motor then
		local muffle = Instance.new("EqualizerSoundEffect")
		muffle.LowGain = 6
		muffle.MidGain = -6
		muffle.HighGain = -24
		muffle.Parent = self.motor
		self.muffle = muffle
	end

	self:pose()
	return self
end

-- Moves every part into place for this frame: the head leads, and each segment behind it
-- swings a little further on its hinge, like a swimming fish.
function ClockworkShark:pose()
	local wiggleSize = if self.mood == "patrol" then 0.18 else 0.32
	local w1 = math.sin(self.swim) * wiggleSize
	local w2 = math.sin(self.swim - 0.9) * wiggleSize * 1.4

	local root = CFrame.new(self.position) * CFrame.Angles(0, self.yaw, 0) * CFrame.Angles(0, 0, self.pitch)

	-- Head (the shark faces +X in its own space).
	self.head.CFrame = root
	self.snout.CFrame = root * CFrame.new(HEAD_LENGTH / 2, 0, 0)
	self.upperJaw.CFrame = root * CFrame.new(HEAD_LENGTH / 2 + 0.3, -1, 0)
	local jawHinge = root * CFrame.new(0.6, -1.4, 0)
	self.lowerJaw.CFrame = jawHinge * CFrame.Angles(0, 0, -self.jawOpen) * CFrame.new(1.8, -0.3, 0)
	for _, tooth in self.teeth do
		tooth.upper.CFrame = root * CFrame.new(HEAD_LENGTH / 2 - 0.4 + tooth.x - 1.2, -1.5, tooth.side * 1.4)
		tooth.lower.CFrame = self.lowerJaw.CFrame * CFrame.new(tooth.x - 1, 0.6, tooth.side * 1.3)
	end
	for _, eye in self.eyes do
		local spot = root * CFrame.new(1.2, 0.6, eye.side * 1.85) * CFrame.Angles(0, math.rad(90), 0)
		eye.white.CFrame = spot
		eye.button.CFrame = spot * CFrame.new(-eye.side * 0.12, 0, 0)
	end
	self.fins[1].CFrame = root * CFrame.new(-0.5, -1.4, 2.4) * CFrame.Angles(math.rad(-25), math.rad(45), 0)
	self.fins[2].CFrame = root * CFrame.new(-0.5, -1.4, -2.4) * CFrame.Angles(math.rad(25), math.rad(45), 0)

	-- First hinge and gear, then the middle segment.
	local hinge1 = root * CFrame.new(-HEAD_LENGTH / 2 - GAP / 2, 0, 0)
	self.hinges[1].CFrame = hinge1
	self.gears[1].CFrame = hinge1 * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(self.gearAngle, 0, 0)
	local midFrame = hinge1 * CFrame.Angles(0, w1, 0) * CFrame.new(-GAP / 2 - MID_LENGTH / 2, 0, 0)
	self.mid.CFrame = midFrame
	self.dorsal.CFrame = midFrame * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(45))
	self.keyShaft.CFrame = midFrame * CFrame.new(-0.8, 2, 0)
	self.key.CFrame = midFrame * CFrame.new(-0.8, 2.9, 0) * CFrame.Angles(0, self.gearAngle * 0.5, 0)

	-- Second hinge and gear, then the rear segment and tail.
	local hinge2 = midFrame * CFrame.new(-MID_LENGTH / 2 - GAP / 2, 0, 0)
	self.hinges[2].CFrame = hinge2
	self.gears[2].CFrame = hinge2 * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(-self.gearAngle, 0, 0)
	local rearFrame = hinge2 * CFrame.Angles(0, w2, 0) * CFrame.new(-GAP / 2 - REAR_LENGTH / 2, 0, 0)
	self.rear.CFrame = rearFrame
	self.tail.CFrame = rearFrame * CFrame.new(-REAR_LENGTH / 2 - 1, 0, 0) * CFrame.Angles(0, w2, math.rad(45))
end

function ClockworkShark:setMotor(mood: string, dt: number)
	self.mood = mood
	local motor = self.motor
	if not motor then
		return
	end
	local targets = {
		patrol = { speed = 0.6, volume = 0.6 },
		hunt = { speed = 1.9, volume = 1 },
		leap = { speed = 2.3, volume = 1.2 },
	}
	local target = targets[mood]
	local baseVolume = Config.Sounds.SharkMotor.volume or 0.6
	local blend = math.min(1, dt * 4)
	motor.PlaybackSpeed += (target.speed - motor.PlaybackSpeed) * blend
	motor.Volume += (baseVolume * target.volume - motor.Volume) * blend
	if self.muffle then
		self.muffle.Enabled = self.position.Y < self.stage.waterTop - 1
	end
end

-- Keep the shark inside the ocean and under the surface.
function ClockworkShark:clampToWater(point: Vector3, surfaceGap: number): Vector3
	local stage = self.stage
	local halfX, halfZ = stage.width / 2 - 10, stage.depth / 2 - 10
	return Vector3.new(
		math.clamp(point.X, stage.origin.X - halfX, stage.origin.X + halfX),
		math.clamp(point.Y, stage.origin.Y + 3, stage.waterTop - surfaceGap),
		math.clamp(point.Z, stage.origin.Z - halfZ, stage.origin.Z + halfZ)
	)
end

function ClockworkShark:faceAlong(direction: Vector3)
	if Vector3.new(direction.X, 0, direction.Z).Magnitude > 0.02 then
		self.yaw = math.atan2(-direction.Z, direction.X)
	end
end

function ClockworkShark:moveToward(goal: Vector3, speed: number, dt: number)
	local offset = goal - self.position
	if offset.Magnitude < 0.05 then
		return
	end
	local step = offset.Unit * math.min(offset.Magnitude, speed * dt)
	self.position += step
	self:faceAlong(step)
	local targetPitch = math.clamp(math.atan2(step.Y, Vector3.new(step.X, 0, step.Z).Magnitude + 0.01), -0.5, 0.5)
	self.pitch += (targetPitch - self.pitch) * math.min(1, dt * 6)
end

local function isOnRaft(stage, root: BasePart): boolean
	return root.Position.Y > stage.waterTop
end

-- The closest living player within the hunt radius, or nil.
function ClockworkShark:findTarget(): (Player?, BasePart?)
	local best, bestRoot, bestDistance = nil, nil, Config.SharkHuntRadius
	for _, player in Players:GetPlayers() do
		local root = Util.rootPart(player)
		if root and Util.aliveHumanoid(player) and self.stage.contains(root.Position) then
			local distance = Util.flatten(root.Position - self.position).Magnitude
			if distance < bestDistance then
				best, bestRoot, bestDistance = player, root, distance
			end
		end
	end
	return best, bestRoot
end

function ClockworkShark:pop(player: Player)
	local humanoid = Util.aliveHumanoid(player)
	if not humanoid then
		return
	end
	humanoid.Health = 0
	Score.breakCombo(player)
	Util.playSound("Chomp", self.head)
	self.jawOpen = 0
	self.jawTarget = 0
end

function ClockworkShark:startLeap(target: BasePart)
	local stage = self.stage
	local across = Util.flatten(target.Position - self.position)
	local direction = if across.Magnitude > 0.1 then across.Unit else Vector3.xAxis
	self.leapStart = self.position
	self.leapApex = target.Position + Vector3.new(0, 2, 0)
	local landing = target.Position + direction * 12
	self.leapEnd = self:clampToWater(Vector3.new(landing.X, stage.waterTop - 7, landing.Z), 2)
	self.leapT = 0
	self.leapHit = {}
	self.jawTarget = 0.7
	self.state = "leap"
	Remotes.fireAll("Splash", { position = Vector3.new(self.position.X, stage.waterTop, self.position.Z) })
	Util.playSound("Breach", self.head)
end

function ClockworkShark:update(dt: number, progress: number)
	local stage = self.stage
	local speedUp = 1 + progress * 0.6
	self.gearAngle += dt * (if self.mood == "patrol" then 3 else 9)
	self.swim += dt * (if self.mood == "patrol" then 3 else 8)
	self.jawOpen += (self.jawTarget - self.jawOpen) * math.min(1, dt * 14)
	self.leapCooldown -= dt

	if self.state ~= "leap" then
		-- Re-check who to chase five times a second.
		self.targetCheck -= dt
		if self.targetCheck <= 0 then
			self.targetCheck = TARGET_CHECK_INTERVAL
			local player, root = self:findTarget()
			self.target = player
			self.targetRoot = root
		end
		local player, root = self.target, self.targetRoot
		if player and (not root or not root.Parent or not Util.aliveHumanoid(player)) then
			player, root = nil, nil
			self.target = nil
		end

		if player and root then
			self:setMotor("hunt", dt)
			if isOnRaft(stage, root) then
				-- Get right underneath them, then breach.
				local below = self:clampToWater(Vector3.new(root.Position.X, stage.waterTop - 7, root.Position.Z), 2)
				self:moveToward(below, 20 * speedUp, dt)
				self.jawTarget = 0
				if Util.flatten(below - self.position).Magnitude < 3 and self.leapCooldown <= 0 then
					self:startLeap(root)
				end
			else
				-- Swimmer: chase them down and bite.
				self:moveToward(self:clampToWater(root.Position, 1.5), 16 * speedUp, dt)
				local distance = (root.Position - self.position).Magnitude
				self.jawTarget = if distance < 10 then 0.6 else 0
				if distance < BITE_RANGE + HEAD_LENGTH / 2 then
					self:pop(player)
				end
			end
		else
			-- Patrol the loop of points.
			self:setMotor("patrol", dt)
			self.jawTarget = 0
			local node = self.nodes[self.nodeIndex]
			local goal = Vector3.new(node.X, stage.waterTop - PATROL_DEPTH, node.Z)
			self:moveToward(goal, 10, dt)
			if Util.flatten(goal - self.position).Magnitude < 4 then
				self.nodeIndex = self.nodeIndex % #self.nodes + 1
			end
		end
	else
		self:setMotor("leap", dt)
		local before = self.position
		self.leapT = math.min(1, self.leapT + dt / LEAP_TIME)
		local t = self.leapT
		-- Curve that passes through the apex halfway through the jump.
		local control = 2 * self.leapApex - 0.5 * (self.leapStart + self.leapEnd)
		self.position = (1 - t) ^ 2 * self.leapStart + 2 * (1 - t) * t * control + t ^ 2 * self.leapEnd
		local velocity = self.position - before
		self:faceAlong(velocity)
		self.pitch = math.clamp(math.atan2(velocity.Y, Vector3.new(velocity.X, 0, velocity.Z).Magnitude + 0.01), -1.1, 1.1)

		if t >= 0.5 and self.jawTarget > 0 then
			self.jawTarget = 0 -- CLACK
			Util.playSound("Chomp", self.head)
		end

		for _, player in Players:GetPlayers() do
			local root = Util.rootPart(player)
			if root and not self.leapHit[player] and (root.Position - self.position).Magnitude < LEAP_HIT_RANGE then
				self.leapHit[player] = true
				self:pop(player)
			end
		end

		-- Any raft in the way snaps.
		for _, raft in stage.raftList do
			if not raft.broken and raft.core.Parent and (raft.core.Position - self.position).Magnitude < 7.5 then
				stage.smashRaft(raft)
			end
		end

		if before.Y >= stage.waterTop and self.position.Y < stage.waterTop then
			Remotes.fireAll("Splash", { position = Vector3.new(self.position.X, stage.waterTop, self.position.Z) })
			Util.playSound("Splash", self.head)
		end

		if t >= 1 then
			self.state = "hunt"
			self.leapCooldown = LEAP_COOLDOWN
		end
	end

	self:pose()
end

function ClockworkShark:destroy()
	self.model:Destroy()
end

return ClockworkShark
