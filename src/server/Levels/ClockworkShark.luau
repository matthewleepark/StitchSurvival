-- The Shark Survival shark. Its body (a low-poly great white with a hinged, gaping jaw and a swinging
-- tail) is built by SharkModel.luau, which the Bomb Hotel chaos shark shares.
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
local SharkModel = require(script.Parent.SharkModel)

local BITE_RANGE = 4.5
local LEAP_TIME = 1.4
local LEAP_HIT_RANGE = 5.5
local LEAP_COOLDOWN = 3
local TARGET_CHECK_INTERVAL = 0.2
local PATROL_DEPTH = 5 -- studs under the surface while cruising

local MOUTH_REACH = 2.5 -- how far in front of the body's center its bite reaches

local ClockworkShark = {}
ClockworkShark.__index = ClockworkShark

function ClockworkShark.new(stage)
	local self = setmetatable({}, ClockworkShark)
	self.stage = stage
	self.yaw = 0
	self.pitch = 0
	self.swim = 0 -- drives the side-to-side wiggle
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

	-- The body: one low-poly great white, about 15 studs long.
	self.body = SharkModel.new(1, "Shark", stage.model)
	self.model = self.body.model
	self.head = self.body.root -- sounds come from the shark itself
	Craft.tag(self.body.root, "Occluded")
	Craft.tag(self.model, "Hazard") -- the Spooky Sense passive shows it through walls

	-- Clockwork motor: low and muffled while patrolling underwater, high and fast when hunting.
	self.motor = Util.loopSound("SharkMotor", self.body.root)
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

-- Moves the shark into place for this frame: the body sways a little, the tail swings further
-- behind it (faster and wider when it's hunting), and the jaw opens and shuts.
function ClockworkShark:pose()
	local wiggleSize = if self.mood == "patrol" then 0.12 else 0.22
	local sway = math.sin(self.swim) * wiggleSize
	local tail = math.sin(self.swim - 0.9) * wiggleSize * 2.2
	local root = CFrame.new(self.position) * CFrame.Angles(0, self.yaw + sway, 0) * CFrame.Angles(0, 0, self.pitch)
	self.body:pose(root, self.jawOpen, tail)
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
	if Util.kill(humanoid) then
		Remotes.fire(player, "Jumpscare", {}) -- the victim's screen only
	end
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
				if distance < BITE_RANGE + MOUTH_REACH then
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
