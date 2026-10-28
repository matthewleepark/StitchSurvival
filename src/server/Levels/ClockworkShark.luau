-- A wind-up toy shark. It patrols with its fin poking out of the water, chases swimmers,
-- and every few seconds stalks someone standing on a crate and leaps out at them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)
local Remotes = require(script.Parent.Parent.Remotes)
local Score = require(script.Parent.Parent.Score)
local Util = require(script.Parent.Parent.Util)

local Colors = Config.Colors
local M = Craft.Material

local BODY_COLOR = Color3.fromRGB(96, 124, 160)
local BELLY_COLOR = Color3.fromRGB(226, 220, 200)
local BITE_RANGE = 4.5
local BITE_DAMAGE = 35
local BITE_COOLDOWN = 1.5
local LEAP_TIME = 1.3
local LEAP_DAMAGE = 60
local LEAP_HIT_RANGE = 5

local ClockworkShark = {}
ClockworkShark.__index = ClockworkShark

local function jawOffset(open: number): CFrame
	return CFrame.new(3.2, -1.5, 0) * CFrame.Angles(0, 0, -open) * CFrame.new(2.2, -0.4, 0)
end

function ClockworkShark.new(stage)
	local self = setmetatable({}, ClockworkShark)
	self.stage = stage
	self.pieces = {}
	self.position = stage.origin + Vector3.new(0, 8, 0)
	self.facing = 1
	self.pitch = 0
	self.keyAngle = 0
	self.jawOpen = 0
	self.jawTarget = 0
	self.state = "swim"
	self.leapTimer = 6
	self.patrolX = 0
	self.lastBite = {}

	local model = Instance.new("Model")
	model.Name = "ClockworkShark"
	self.model = model

	local props = { CanCollide = false, CanQuery = false, CanTouch = false }
	local function piece(part: BasePart, localPosition: Vector3)
		table.insert(self.pieces, { part = part, offset = CFrame.new(localPosition) * part.CFrame.Rotation })
		return part
	end

	-- Body: a felt tube with rounded ends. The shark faces +X in its own space.
	piece(Craft.cylinder(model, Vector3.zero, 11, 5, "X", BODY_COLOR, M.Felt, props), Vector3.zero)
	piece(Craft.ball(model, Vector3.zero, 4.8, BODY_COLOR, M.Felt, props), Vector3.new(5.4, 0.1, 0))
	piece(Craft.ball(model, Vector3.zero, 3.4, BODY_COLOR, M.Felt, props), Vector3.new(-5.6, 0, 0))
	piece(Craft.block(model, CFrame.identity, Vector3.new(10, 1, 4.4), BELLY_COLOR, M.Felt, props), Vector3.new(0.5, -2, 0))
	piece(Craft.diamond(model, Vector3.zero, 3.6, BODY_COLOR, M.Felt, props), Vector3.new(-0.5, 2.5, 0))
	piece(Craft.diamond(model, Vector3.zero, 4.2, BODY_COLOR, M.Felt, props), Vector3.new(-8.6, 0.4, 0))
	piece(Craft.diamond(model, Vector3.zero, 2, BODY_COLOR, M.Felt, props), Vector3.new(1.5, -2.6, 0))

	-- Button eyes on both sides so it looks right facing either way.
	for _, side in { -1, 1 } do
		piece(Craft.disc(model, Vector3.zero, 1.5, Color3.new(1, 1, 1), M.Felt, props), Vector3.new(4.6, 1, side * 2.45))
		piece(Craft.disc(model, Vector3.zero, 0.8, Color3.fromRGB(30, 30, 30), M.Plastic, props), Vector3.new(4.8, 1, side * 2.6))
		for i = 0, 2 do
			piece(Craft.block(model, CFrame.identity, Vector3.new(0.4, 0.6, 0.2), Color3.new(1, 1, 1), M.Plastic, props), Vector3.new(5.6 + i * 0.6, -1.2, side * 2.1))
		end
	end

	-- Plywood lower jaw on a hinge.
	self.jaw = Craft.block(model, CFrame.identity, Vector3.new(4.4, 0.9, 3.6), Color3.fromRGB(196, 160, 110), M.Wood, props)

	-- Wind-up key.
	piece(Craft.cylinder(model, Vector3.zero, 1.4, 0.5, "Y", Colors.Gold, M.Metal, props), Vector3.new(-1.5, 3.2, 0))
	self.key = Craft.block(model, CFrame.identity, Vector3.new(0.3, 1.4, 3), Colors.Gold, M.Metal, props)

	model.Parent = stage.model

	-- Clockwork motor: low and muffled while patrolling underwater, high and fast when hunting.
	self.motor = Util.loopSound("SharkMotor", self.pieces[1].part)
	if self.motor then
		local muffle = Instance.new("EqualizerSoundEffect")
		muffle.LowGain = 4
		muffle.MidGain = -6
		muffle.HighGain = -20
		muffle.Parent = self.motor
		self.muffle = muffle
	end

	self:pose()
	return self
end

-- How the motor sounds in each mood.
local MOTOR = {
	patrol = { speed = 0.6, volume = 0.6 },
	hunt = { speed = 1.9, volume = 1 },
	leap = { speed = 2.3, volume = 1.2 },
}

function ClockworkShark:setMotor(mood: string, dt: number)
	local motor = self.motor
	if not motor then
		return
	end
	local target = MOTOR[mood]
	local baseVolume = Config.Sounds.SharkMotor.volume or 0.6
	local blend = math.min(1, dt * 4)
	motor.PlaybackSpeed += (target.speed - motor.PlaybackSpeed) * blend
	motor.Volume += (baseVolume * target.volume - motor.Volume) * blend
	if self.muffle then
		self.muffle.Enabled = self.position.Y < self.stage.waterTop - 1
	end
end

function ClockworkShark:pose()
	local root = CFrame.new(self.position)
		* CFrame.Angles(0, if self.facing == 1 then 0 else math.pi, 0)
		* CFrame.Angles(0, 0, self.pitch)
	for _, piece in self.pieces do
		piece.part.CFrame = root * piece.offset
	end
	self.jaw.CFrame = root * jawOffset(self.jawOpen)
	self.key.CFrame = root * CFrame.new(-1.5, 4.4, 0) * CFrame.Angles(0, self.keyAngle, 0)
end

function ClockworkShark:clampToWater(point: Vector3, surfaceGap: number): Vector3
	local stage = self.stage
	local half = stage.width / 2 - 7
	return Vector3.new(
		math.clamp(point.X, stage.origin.X - half, stage.origin.X + half),
		math.clamp(point.Y, stage.origin.Y + 3, stage.waterTop - surfaceGap),
		math.clamp(point.Z, stage.origin.Z - 5, stage.origin.Z + 5)
	)
end

function ClockworkShark:moveToward(goal: Vector3, speed: number, dt: number)
	local offset = goal - self.position
	if offset.Magnitude < 0.05 then
		return
	end
	local step = offset.Unit * math.min(offset.Magnitude, speed * dt)
	self.position += step
	if math.abs(step.X) > 0.02 then
		self.facing = if step.X > 0 then 1 else -1
	end
	local targetPitch = math.clamp(math.atan2(step.Y, math.abs(step.X) + 0.01), -0.5, 0.5)
	self.pitch += (targetPitch - self.pitch) * math.min(1, dt * 6)
end

-- Players in this stage, with a filter. Returns the closest one to `from`.
function ClockworkShark:closestPlayer(from: Vector3, filter: (BasePart) -> boolean)
	local best, bestRoot, bestHumanoid, bestDistance = nil, nil, nil, math.huge
	for _, player in Players:GetPlayers() do
		local humanoid = Util.aliveHumanoid(player)
		local root = Util.rootPart(player)
		if humanoid and root and self.stage.contains(root.Position) and filter(root) then
			local distance = (root.Position - from).Magnitude
			if distance < bestDistance then
				best, bestRoot, bestHumanoid, bestDistance = player, root, humanoid, distance
			end
		end
	end
	return best, bestRoot, bestHumanoid, bestDistance
end

function ClockworkShark:hurt(player: Player, humanoid: Humanoid, damage: number)
	humanoid:TakeDamage(damage)
	Score.breakCombo(player)
	local root = Util.rootPart(player)
	if root then
		local away = root.Position.X - self.position.X
		Remotes.fire(player, "Knock", { velocity = Vector3.new(if away >= 0 then 40 else -40, 45, 0) })
	end
	Util.playSound("Chomp", self.jaw)
end

function ClockworkShark:startLeap(target: BasePart)
	local stage = self.stage
	local direction = if target.Position.X >= self.position.X then 1 else -1
	self.leapStart = self.position
	self.leapApex = Vector3.new(target.Position.X, target.Position.Y + 2, target.Position.Z)
	self.leapEnd = self:clampToWater(Vector3.new(target.Position.X + direction * 12, stage.waterTop - 7, target.Position.Z), 2)
	self.leapT = 0
	self.leapHit = {}
	self.jawTarget = 0.6
	self.state = "leap"
	-- The tissue-paper water rips open as it breaks the surface.
	Remotes.fireAll("Splash", { position = Vector3.new(self.position.X, stage.waterTop, self.position.Z) })
	Util.playSound("Breach", self.pieces[1].part)
end

function ClockworkShark:update(dt: number, progress: number)
	local stage = self.stage
	self.keyAngle += dt * 5
	self.jawOpen += (self.jawTarget - self.jawOpen) * math.min(1, dt * 14)

	local inWater = function(root: BasePart)
		return root.Position.Y < stage.waterTop - 1
	end
	local onCrate = function(root: BasePart)
		return root.Position.Y > stage.waterTop
	end

	if self.state == "swim" then
		self.leapTimer -= dt
		local player, root, humanoid, distance = self:closestPlayer(self.position, inWater)
		if player and root and humanoid then
			self:moveToward(self:clampToWater(root.Position, 1.8), 12 + 8 * progress, dt)
			self.jawTarget = if distance < 9 then 0.5 else 0
			local now = os.clock()
			if distance < BITE_RANGE and now - (self.lastBite[player] or 0) > BITE_COOLDOWN then
				self.lastBite[player] = now
				self.jawOpen = 0
				self:hurt(player, humanoid, BITE_DAMAGE)
			end
		else
			-- Cruise just under the surface so the fin shows.
			self.jawTarget = 0
			local goal = Vector3.new(stage.origin.X + self.patrolX, stage.waterTop - 2.4, stage.origin.Z)
			self:moveToward(self:clampToWater(goal, 2.4), 10, dt)
			if math.abs(self.position.X - goal.X) < 3 then
				self.patrolX = math.random(-45, 45)
			end
		end

		self:setMotor(if player then "hunt" else "patrol", dt)

		-- Lock on to someone standing on a crate within 60 studs.
		if self.leapTimer <= 0 then
			local victim, victimRoot, _, victimDistance = self:closestPlayer(self.position, onCrate)
			if victim and victimRoot and victimDistance <= 60 then
				self.state = "stalk"
				self.victim = victim
				self.stalkTime = 0
			else
				self.leapTimer = 2
			end
		end
	elseif self.state == "stalk" then
		local root = self.victim and Util.rootPart(self.victim)
		if not root or not Util.aliveHumanoid(self.victim) then
			self.state = "swim"
			self.leapTimer = 3
		else
			self.stalkTime += dt
			self:setMotor("hunt", dt)
			local below = self:clampToWater(Vector3.new(root.Position.X - self.facing * 6, stage.waterTop - 7, root.Position.Z), 2)
			self:moveToward(below, 30, dt)
			if (self.position - below).Magnitude < 1.5 or self.stalkTime > 1.6 then
				self:startLeap(root)
			end
		end
	elseif self.state == "leap" then
		local before = self.position
		self.leapT = math.min(1, self.leapT + dt / LEAP_TIME)
		local t = self.leapT
		-- Curve that passes through the apex halfway through the jump.
		local control = 2 * self.leapApex - 0.5 * (self.leapStart + self.leapEnd)
		self.position = (1 - t) ^ 2 * self.leapStart + 2 * (1 - t) * t * control + t ^ 2 * self.leapEnd
		local velocity = self.position - before
		if math.abs(velocity.X) > 0.01 then
			self.facing = if velocity.X > 0 then 1 else -1
		end
		self.pitch = math.clamp(math.atan2(velocity.Y, math.abs(velocity.X) + 0.01), -1.1, 1.1)

		if t >= 0.5 and self.jawTarget > 0 then
			self.jawTarget = 0 -- SNAP
			Util.playSound("Chomp", self.jaw)
		end

		self:setMotor("leap", dt)

		for _, player in Players:GetPlayers() do
			local humanoid = Util.aliveHumanoid(player)
			local root = Util.rootPart(player)
			if humanoid and root and not self.leapHit[player] and (root.Position - self.position).Magnitude < LEAP_HIT_RANGE then
				self.leapHit[player] = true
				self:hurt(player, humanoid, LEAP_DAMAGE)
			end
		end

		-- Crashing through a crate snaps it into pieces.
		for _, crate in stage.crates do
			if not crate.broken and not crate.busy then
				local localPoint = crate.box.CFrame:PointToObjectSpace(self.position)
				local half = crate.box.Size / 2 + Vector3.new(2, 2, 2)
				if math.abs(localPoint.X) < half.X and math.abs(localPoint.Y) < half.Y and math.abs(localPoint.Z) < half.Z then
					stage.smashCrate(crate)
				end
			end
		end

		if before.Y >= stage.waterTop and self.position.Y < stage.waterTop then
			Remotes.fireAll("Splash", { position = Vector3.new(self.position.X, stage.waterTop, self.position.Z) })
			Util.playSound("Splash", self.pieces[1].part)
			self.jawTarget = 0
		end

		if t >= 1 then
			self.state = "swim"
			self.leapTimer = 7 - 4 * progress + math.random() * 2
		end
	end

	self:pose()
end

function ClockworkShark:destroy()
	self.model:Destroy()
end

return ClockworkShark
