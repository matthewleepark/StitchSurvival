-- Bombs for Bomb Hotel.
--
-- A bomb is a 4-stud black papier-mache sphere with a short jute fuse. It appears at a random
-- spot inside the hotel with a bicycle-bell ping, drops to whatever floor is below it with a
-- heavy thud, and its fuse starts hissing and sparking. Inside it an egg timer ticks twice a
-- second; for the last 5 seconds it ticks twice as fast. You can only hear it within 30 studs,
-- and the sound comes from where the bomb is, so you can find it by ear.
--
-- When the timer hits zero: CRACK-FOOM. The blocks right next to it shatter into chunks.
-- Everything else within 25 studs (floor blocks, pillars, ramps, railings) rips loose with a
-- Velcro tearing sound and is thrown outward. Falling blocks whistle through the air, land with
-- a thud and a rumble, and squash anyone they land on. Orange cellophane fire spreads outward in
-- a circle and burns anyone who touches it.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)
local Remotes = require(script.Parent.Parent.Remotes)
local Score = require(script.Parent.Parent.Score)
local Util = require(script.Parent.Parent.Util)

local Colors = Config.Colors
local M = Craft.Material

local SHATTER_RADIUS = 7
local DAMAGE_RADIUS = 14
local MAX_DAMAGE = 80
local KNOCKBACK = 60
local FLING_SPEED = 22

local FIRE_DAMAGE = 8
local FIRE_LIFETIME = 7
local CRUSH_SPEED = 18

local Bombs = {}

local function weld(part: BasePart, to: BasePart)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = to
	constraint.Part1 = part
	constraint.Parent = part
	part.Parent = to
end

-- Breaks a block into a few chunks that fly away from the blast.
local function shatter(block: BasePart, origin: Vector3)
	local size = block.Size
	local chunkSize = size / 2
	for i = 1, 4 do
		local offset = Vector3.new((i % 2 - 0.5) * size.X / 2, 0, (if i <= 2 then -0.5 else 0.5) * size.Z / 2)
		local chunk = Craft.block(workspace, block.CFrame * CFrame.new(offset), chunkSize * (0.7 + math.random() * 0.25), block.Color, block.Material)
		chunk.Name = "Chunk"
		chunk.Anchored = false
		chunk.CanQuery = false
		local away = chunk.Position - origin
		local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.yAxis
		chunk.AssemblyLinearVelocity = direction * 30 + Vector3.new(0, 15, 0)
		chunk.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
		Craft.tag(chunk, "LooseDebris")
		Debris:AddItem(chunk, 3)
	end
	block:Destroy()
end

-- Rips a block loose: it's thrown outward from the blast, whistles as it falls,
-- and squashes anyone it lands on.
local function collapse(block: BasePart, origin: Vector3)
	block:SetAttribute("Breakable", false)
	block.Anchored = false
	block.CanQuery = false
	local away = block.Position - origin
	local outward = if away.Magnitude > 0.1 then away.Unit else Vector3.yAxis
	block.AssemblyLinearVelocity = outward * FLING_SPEED + Vector3.new(0, 4, 0)
	block.AssemblyAngularVelocity = Vector3.new(math.random(-2, 2), math.random(-2, 2), math.random(-2, 2))
	block:SetNetworkOwner(nil)
	Craft.tag(block, "LooseDebris")
	if math.random() < 0.3 then
		Util.playSound("DebrisWhistle", block)
	end

	local landed = false
	block.Touched:Connect(function(hit)
		local character, humanoid = Util.characterFromPart(hit)
		if character and humanoid then
			-- Falling down onto someone = squashed flat.
			if block.AssemblyLinearVelocity.Y < -CRUSH_SPEED and block.Position.Y > hit.Position.Y + 1 and humanoid.Health > 0 then
				if Util.kill(humanoid) then
					Util.playSound("Crush", block)
					Remotes.fireAll("Squish", { position = hit.Position })
				end
			end
		elseif not landed and hit.CanCollide and block.AssemblyLinearVelocity.Magnitude > 12 then
			landed = true
			Util.playSound("DebrisThud", block)
			Util.playSound("Rumble", block)
			Remotes.fireAll("Rumble", { position = block.Position })
		end
	end)

	Debris:AddItem(block, 8)
end

-- Orange cellophane fire that spreads outward in a widening circle along the floor.
function Bombs.ignite(stage, center: Vector3)
	local crackle = Craft.block(stage.model, CFrame.new(center), Vector3.one, Color3.new(), nil, Craft.DECOR)
	crackle.Transparency = 1
	Craft.tag(crackle, "Occluded")
	Util.loopSound("FireCrackle", crackle)
	Debris:AddItem(crackle, FIRE_LIFETIME + 2)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { stage.model }

	local lastBurn: { [Humanoid]: number } = {}
	local function flameAt(spot: Vector3, lifetime: number)
		local result = workspace:Raycast(spot + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), params)
		if not result then
			return
		end
		local size = 2.2 + math.random() * 1.4
		local position = result.Position + Vector3.new(0, size * 0.55, 0)
		local flame = Craft.block(
			stage.model,
			CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi, math.rad(45)),
			Vector3.new(size, size, 0.15),
			if math.random() < 0.5 then Colors.Warning else Colors.Gold,
			M.Glass,
			{ CanCollide = false, CanQuery = false, Transparency = 0.2, Name = "Flame" }
		)
		Craft.tag(flame, "Flicker")
		flame.Touched:Connect(function(hit)
			local character, humanoid = Util.characterFromPart(hit)
			local player = character and Players:GetPlayerFromCharacter(character)
			if player and humanoid and humanoid.Health > 0 then
				local now = os.clock()
				if now - (lastBurn[humanoid] or 0) > 0.6 then
					lastBurn[humanoid] = now
					Util.damage(humanoid, FIRE_DAMAGE, true)
					Score.breakCombo(player)
					local root = Util.rootPart(player)
					if root then
						Util.playSound("Gasp", root)
					end
				end
			end
		end)
		Debris:AddItem(flame, lifetime)
	end

	-- Rings of flames, each one wider than the last.
	flameAt(center, FIRE_LIFETIME)
	for ring = 1, 4 do
		if stage.frozen then
			return
		end
		task.wait(0.45)
		local radius = ring * 2.6
		local count = ring * 4
		for i = 1, count do
			local angle = i / count * math.pi * 2 + math.random() * 0.3
			flameAt(center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), FIRE_LIFETIME - ring * 0.5)
		end
	end
end

function Bombs.explode(stage, position: Vector3)
	local blastRadius = Config.PlantedBombBlastRadius
	Remotes.fireAll("Boom", { position = position, radius = DAMAGE_RADIUS })
	Util.soundAt("Bang", position)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { stage.breakables }

	local broke, collapsed = false, false
	for _, part in workspace:GetPartBoundsInRadius(position, blastRadius, params) do
		if part:GetAttribute("Breakable") and part.Parent and part.Anchored then
			if (part.Position - position).Magnitude <= SHATTER_RADIUS then
				shatter(part, position)
				broke = true
			else
				collapse(part, position)
				collapsed = true
			end
		end
	end
	if broke then
		Util.soundAt("BlockBreak", position)
	end
	if collapsed then
		Util.soundAt("VelcroRip", position + Vector3.new(0, 4, 0))
	end

	for _, player in Players:GetPlayers() do
		local humanoid = Util.aliveHumanoid(player)
		local root = Util.rootPart(player)
		if humanoid and root then
			local offset = root.Position - position
			local distance = offset.Magnitude
			if distance < DAMAGE_RADIUS then
				Util.damage(humanoid, MAX_DAMAGE * (1 - 0.5 * distance / DAMAGE_RADIUS), true)
				Score.breakCombo(player)
				local flat = Util.flatten(offset)
				local push = (if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis) * KNOCKBACK
				Remotes.fire(player, "Knock", { velocity = push + Vector3.new(0, KNOCKBACK * 0.6, 0) })
			end
		end
	end

	task.spawn(Bombs.ignite, stage, position)
end

local function buildBomb(stage, position: Vector3)
	-- Black papier-mache ball.
	local bomb = Craft.ball(stage.model, position, 4, Colors.Bomb, M.Cardboard)
	bomb.Name = "Bomb"
	bomb.Anchored = false
	bomb.CustomPhysicalProperties = PhysicalProperties.new(3, 0.9, 0.05)

	-- Jute twine fuse with sparks fizzing off the end.
	local fuse = Craft.block(stage.model, CFrame.new(position + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(15)), Vector3.new(0.3, 1, 0.3), Color3.fromRGB(190, 160, 110), M.Felt)
	weld(fuse, bomb)
	local tip = Instance.new("Attachment")
	tip.Position = Vector3.new(0, 0.5, 0)
	tip.Parent = fuse
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Colors.Gold, Colors.Warning)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.4, 0)
	sparks.Lifetime = NumberRange.new(0.2, 0.45)
	sparks.Speed = NumberRange.new(3, 7)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 60
	sparks.Parent = tip
	local glow = Instance.new("PointLight")
	glow.Color = Colors.Warning
	glow.Range = 8
	glow.Brightness = 1.5
	glow.Parent = fuse

	-- Countdown number floating above it.
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(80, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = bomb
	local number = Instance.new("TextLabel")
	number.BackgroundTransparency = 1
	number.Size = UDim2.fromScale(1, 1)
	number.Font = Enum.Font.FredokaOne
	number.TextSize = 40
	number.TextColor3 = Colors.Paper
	number.TextStrokeTransparency = 0
	number.TextStrokeColor3 = Colors.Felt
	number.Parent = billboard

	bomb:SetNetworkOwner(nil) -- server-controlled so everyone sees the same blast
	Craft.tag(bomb, "Occluded") -- its sounds get muffled when a floor or wall is in the way
	return bomb, number
end

-- Drop a bomb at a spot inside the hotel. Runs until it explodes (or the round ends).
function Bombs.plant(stage, position: Vector3)
	local bomb, number = buildBomb(stage, position)
	Util.playSound("BombBell", bomb)
	Util.loopSound("FuseHiss", bomb)

	local landed = false
	bomb.Touched:Connect(function(hit)
		if not landed and hit.CanCollide and not hit:IsDescendantOf(bomb) then
			landed = true
			Util.playSound("BombLand", bomb)
		end
	end)

	local fuse = Config.PlantedBombFuse
	local elapsed = 0
	while elapsed < fuse and bomb.Parent and not stage.frozen do
		local timeLeft = fuse - elapsed
		number.Text = tostring(math.ceil(timeLeft))
		-- 120 ticks a minute, doubling for the last 5 seconds.
		local interval = if timeLeft <= 5 then 0.25 else 0.5
		bomb.Color = Colors.Felt
		Util.playSound("BombTick", bomb)
		task.wait(interval * 0.4)
		if bomb.Parent then
			bomb.Color = Colors.Bomb
		end
		task.wait(interval * 0.6)
		elapsed += interval
	end
	if not bomb.Parent or stage.frozen then
		return
	end

	local at = bomb.Position
	bomb:Destroy()
	Bombs.explode(stage, at)
end

return Bombs
