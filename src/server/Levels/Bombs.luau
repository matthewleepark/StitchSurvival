-- Bombs for Bomb Hotel.
--   Falling bombs: drop from the roof chutes. "Fuse" bombs blink and tick; orange "Impact" bombs
--     go off the moment they hit something.
--   Planted time bombs: appear on a random floor with a bike-bell ping, beep faster and faster
--     (you can only hear the beeping within 30 studs, so it tells you where it is), hold a solid
--     tone, then blow up big: the blocks next to it shatter, the ring of blocks around that rips
--     loose and falls (crushing anyone underneath), and cellophane fire spreads outward.

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

local FUSE_TIME = 3
local IMPACT_ARM_TIME = 0.4
local KNOCKBACK = 70

local SMALL_BLAST = { radius = 9, breakRadius = 5.5, collapseRadius = 0, damage = 60, fire = false }
local BIG_BLAST = { radius = 12, breakRadius = 6.5, collapseRadius = 13, damage = 80, fire = true }

local FIRE_DAMAGE = 8
local FIRE_LIFETIME = 6
local CRUSH_SPEED = 20

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

-- Breaks a foam block into a few chunks that fly away from the blast.
local function shatter(block: BasePart, origin: Vector3)
	local size = block.Size
	local chunkSize = Vector3.new(size.X / 2, size.Y, math.min(size.Z, 4))
	for i = 1, 4 do
		local offset = Vector3.new((i % 2 - 0.5) * size.X / 2, 0, (math.random() - 0.5) * size.Z * 0.8)
		local chunk = Craft.block(workspace, block.CFrame * CFrame.new(offset), chunkSize * (0.6 + math.random() * 0.3), block.Color, block.Material)
		chunk.Name = "Chunk"
		chunk.Anchored = false
		chunk.CanQuery = false
		local away = chunk.Position - origin
		local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.yAxis
		chunk.AssemblyLinearVelocity = direction * 35 + Vector3.new(0, 25, 0)
		chunk.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
		Craft.tag(chunk, "LooseDebris")
		Debris:AddItem(chunk, 2.5)
	end
	block:Destroy()
end

-- Rips a block loose: it tumbles outward and down, crushing anyone it lands on.
local function collapse(block: BasePart, origin: Vector3)
	block:SetAttribute("Breakable", false)
	block.Anchored = false
	block.CanQuery = false
	local flat = Vector3.new(block.Position.X - origin.X, 0, 0)
	local outward = if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis
	block.AssemblyLinearVelocity = outward * 18 + Vector3.new(0, 8, 0)
	block.AssemblyAngularVelocity = Vector3.new(0, 0, math.random(-3, 3))
	block:SetNetworkOwner(nil)
	Craft.tag(block, "LooseDebris")

	local thudded = false
	block.Touched:Connect(function(hit)
		local character, humanoid = Util.characterFromPart(hit)
		if character and humanoid then
			-- Falling down onto someone = squished.
			if block.AssemblyLinearVelocity.Y < -CRUSH_SPEED and block.Position.Y > hit.Position.Y + 1 and humanoid.Health > 0 then
				humanoid.Health = 0
				Util.playSound("Crush", block)
				Remotes.fireAll("Squish", { position = hit.Position })
			end
		elseif not thudded and hit.CanCollide and block.AssemblyLinearVelocity.Magnitude > 15 then
			thudded = true
			Util.playSound("DebrisThud", block)
		end
	end)

	Debris:AddItem(block, 6)
end

-- Cellophane fire that spreads outward in rings along the floor.
function Bombs.ignite(stage, center: Vector3)
	local crackle = Instance.new("Part")
	crackle.Anchored = true
	crackle.CanCollide = false
	crackle.CanQuery = false
	crackle.CanTouch = false
	crackle.Transparency = 1
	crackle.Position = center
	crackle.Parent = stage.model
	Util.loopSound("FireCrackle", crackle)
	Debris:AddItem(crackle, FIRE_LIFETIME + 2)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { stage.model }

	local lastBurn: { [Humanoid]: number } = {}
	for ring = 0, 4 do
		if stage.frozen then
			return
		end
		local offsets = if ring == 0 then { 0 } else { -ring * 2.6, ring * 2.6 }
		for _, dx in offsets do
			local from = center + Vector3.new(dx, 3, 0)
			local result = workspace:Raycast(from, Vector3.new(0, -14, 0), params)
			if result then
				local size = 2 + math.random() * 1.2
				local spot = Vector3.new(result.Position.X, result.Position.Y + size * 0.55, stage.origin.Z + Util.randomLayer())
				local flame = Craft.block(
					stage.model,
					CFrame.new(spot) * CFrame.Angles(0, 0, math.rad(45)),
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
							humanoid:TakeDamage(FIRE_DAMAGE)
							Score.breakCombo(player)
						end
					end
				end)
				Debris:AddItem(flame, FIRE_LIFETIME - ring * 0.4)
			end
		end
		task.wait(0.45)
	end
end

function Bombs.explode(stage, position: Vector3, blast)
	blast = blast or SMALL_BLAST
	Remotes.fireAll("Boom", { position = position, radius = blast.radius })
	Util.soundAt("Bang", position)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { stage.foam }

	local reach = math.max(blast.breakRadius, blast.collapseRadius)
	local broke, collapsed = false, false
	for _, part in workspace:GetPartBoundsInRadius(position, reach, params) do
		if part:GetAttribute("Breakable") and part.Parent then
			local distance = (part.Position - position).Magnitude
			if distance <= blast.breakRadius + 1 then
				shatter(part, position)
				broke = true
			elseif blast.collapseRadius > 0 then
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
			if distance < blast.radius then
				humanoid:TakeDamage(blast.damage * (1 - 0.5 * distance / blast.radius))
				Score.breakCombo(player)
				-- Push sideways and up, but never out of your layer.
				local flat = Vector3.new(offset.X, 0, 0)
				local push = (if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis) * KNOCKBACK
				Remotes.fire(player, "Knock", { velocity = push + Vector3.new(0, KNOCKBACK * 0.7, 0) })
			end
		end
	end

	if blast.fire then
		task.spawn(Bombs.ignite, stage, position)
	end
end

-- Falling bombs ---------------------------------------------------------------------------

local function buildFallingBomb(stage, position: Vector3, kind: string): Part
	local isImpact = kind == "Impact"
	local bomb = Craft.ball(stage.model, position, 3, if isImpact then Colors.Warning else Colors.Bomb, M.Plastic)
	bomb.Name = "Bomb"
	bomb.Anchored = false
	bomb.CustomPhysicalProperties = PhysicalProperties.new(2, 0.8, 0.1)

	weld(Craft.cylinder(stage.model, position + Vector3.new(0, 1.5, 0), 0.6, 1.2, "Y", Color3.fromRGB(150, 150, 160), M.Metal), bomb)

	if isImpact then
		-- White felt band so impact bombs read differently at a glance.
		weld(Craft.cylinder(stage.model, position, 0.6, 3.1, "Z", Color3.new(1, 1, 1), M.Felt), bomb)
	else
		local fuse = Craft.block(stage.model, CFrame.new(position + Vector3.new(0, 2.2, 0)), Vector3.new(0.2, 0.9, 0.2), Colors.Paper, M.Felt)
		weld(fuse, bomb)

		local tip = Instance.new("Attachment")
		tip.Position = Vector3.new(0, 0.45, 0)
		tip.Parent = fuse
		local sparks = Instance.new("ParticleEmitter")
		sparks.Color = ColorSequence.new(Colors.Gold, Colors.Warning)
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new(0.35, 0)
		sparks.Lifetime = NumberRange.new(0.2, 0.4)
		sparks.Speed = NumberRange.new(3, 6)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Rate = 40
		sparks.Parent = tip
	end

	bomb:SetNetworkOwner(nil) -- keep bombs server-controlled so everyone sees the same blast
	return bomb
end

function Bombs.drop(stage, position: Vector3, kind: string)
	local bomb = buildFallingBomb(stage, position, kind)
	local exploded = false
	local function detonate()
		if exploded or not bomb.Parent or stage.frozen then
			return
		end
		exploded = true
		local at = bomb.Position
		bomb:Destroy()
		Bombs.explode(stage, at, SMALL_BLAST)
	end

	if kind == "Impact" then
		task.delay(IMPACT_ARM_TIME, function()
			if not bomb.Parent then
				return
			end
			bomb.Touched:Connect(function(hit)
				if hit.CanCollide and not hit:IsDescendantOf(bomb) then
					detonate()
				end
			end)
		end)
		task.delay(8, detonate) -- in case it never touches anything
	else
		task.spawn(function()
			local elapsed = 0
			while elapsed < FUSE_TIME and bomb.Parent and not stage.frozen do
				local blink = math.max(0.1, 0.5 * (1 - elapsed / FUSE_TIME))
				bomb.Color = Colors.Felt
				Util.playSound("Tick", bomb)
				task.wait(blink / 2)
				if bomb.Parent then
					bomb.Color = Colors.Bomb
				end
				task.wait(blink / 2)
				elapsed += blink
			end
			detonate()
		end)
	end
end

-- Planted time bombs -----------------------------------------------------------------------

local function buildTimeBomb(stage, position: Vector3)
	local body = Craft.block(stage.model, CFrame.new(position), Vector3.new(2.8, 2, 2), Colors.Felt, M.Felt)
	body.Name = "TimeBomb"
	body.Anchored = false

	-- Clock face on the front, and a red light on top.
	weld(Craft.disc(stage.model, position + Vector3.new(0, 0, 1.05), 1.5, Colors.Paper, M.Plastic), body)
	weld(Craft.block(stage.model, CFrame.new(position + Vector3.new(0, 0.3, 1.25)), Vector3.new(0.12, 0.6, 0.05), Colors.Ink, M.Plastic), body)
	local light = Craft.ball(stage.model, position + Vector3.new(0, 1.3, 0), 0.8, Color3.fromRGB(120, 20, 20), M.Neon)
	weld(light, body)
	for _, side in { -1, 1 } do
		weld(Craft.cylinder(stage.model, position + Vector3.new(side * 1.6, 0, 0), 2.2, 0.8, "Y", Color3.fromRGB(200, 60, 50), M.Plastic), body)
	end

	-- Big countdown number floating above it.
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(80, 50)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = body
	local number = Instance.new("TextLabel")
	number.BackgroundTransparency = 1
	number.Size = UDim2.fromScale(1, 1)
	number.Font = Enum.Font.FredokaOne
	number.TextSize = 40
	number.TextColor3 = Colors.Paper
	number.TextStrokeTransparency = 0
	number.TextStrokeColor3 = Colors.Felt
	number.Parent = billboard

	body:SetNetworkOwner(nil)
	return body, light, number
end

function Bombs.plant(stage, position: Vector3)
	local body, light, number = buildTimeBomb(stage, position)
	Util.playSound("BombBell", body)
	Remotes.fireAll("Popup", { text = "!", position = position + Vector3.new(0, 2, 0), color = Colors.Felt })

	local fuse = Config.PlantedBombFuse
	local beepTime = fuse - 1
	local elapsed = 0
	while elapsed < beepTime and body.Parent and not stage.frozen do
		number.Text = tostring(math.ceil(fuse - elapsed))
		local urgency = (elapsed / beepTime) ^ 1.5
		local interval = 0.9 - 0.82 * urgency
		light.Color = Color3.fromRGB(255, 60, 60)
		Util.playSound("BombBeep", body)
		task.wait(interval * 0.4)
		if light.Parent then
			light.Color = Color3.fromRGB(120, 20, 20)
		end
		task.wait(interval * 0.6)
		elapsed += interval
	end
	if not body.Parent or stage.frozen then
		return
	end

	-- Solid tone for the last second.
	number.Text = "!"
	light.Color = Color3.fromRGB(255, 60, 60)
	local tone = Util.loopSound("BombTone", body)
	task.wait(1)
	if tone then
		tone:Stop()
	end
	if not body.Parent or stage.frozen then
		return
	end

	local at = body.Position
	body:Destroy()
	Bombs.explode(stage, at, BIG_BLAST)
end

return Bombs
