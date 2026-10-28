-- Bombs for Bomb Hotel. "Fuse" bombs blink and tick before going off; orange "Impact"
-- bombs explode the moment they hit something. Explosions shatter foam blocks.

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
local BLAST_RADIUS = 9
local BREAK_RADIUS = 5.5
local MAX_DAMAGE = 60
local KNOCKBACK = 70

local Bombs = {}

local function weld(part: BasePart, to: BasePart)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = to
	constraint.Part1 = part
	constraint.Parent = part
end

-- Breaks a foam block into a few chunks that fly away from the blast.
local function shatter(block: BasePart, origin: Vector3)
	local size = block.Size
	local chunkSize = Vector3.new(size.X / 2, size.Y, math.min(size.Z, 4))
	for i = 1, 4 do
		local offset = Vector3.new((i % 2 - 0.5) * size.X / 2, 0, (math.random() - 0.5) * size.Z * 0.8)
		local chunk = Craft.block(workspace, block.CFrame * CFrame.new(offset), chunkSize * (0.6 + math.random() * 0.3), block.Color, block.Material)
		chunk.Anchored = false
		chunk.CanQuery = false
		local away = chunk.Position - origin
		local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.yAxis
		chunk.AssemblyLinearVelocity = direction * 35 + Vector3.new(0, 25, 0)
		chunk.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
		Debris:AddItem(chunk, 2.5)
	end
	block:Destroy()
end

function Bombs.explode(stage, position: Vector3)
	Remotes.fireAll("Boom", { position = position, radius = BLAST_RADIUS })

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { stage.foam }
	for _, part in workspace:GetPartBoundsInRadius(position, BREAK_RADIUS, params) do
		if part:GetAttribute("Breakable") and part.Parent then
			shatter(part, position)
		end
	end

	for _, player in Players:GetPlayers() do
		local humanoid = Util.aliveHumanoid(player)
		local root = Util.rootPart(player)
		if humanoid and root then
			local offset = root.Position - position
			local distance = offset.Magnitude
			if distance < BLAST_RADIUS then
				humanoid:TakeDamage(MAX_DAMAGE * (1 - 0.5 * distance / BLAST_RADIUS))
				Score.breakCombo(player)
				-- Push sideways and up, but never out of your layer.
				local flat = Vector3.new(offset.X, 0, 0)
				local push = (if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis) * KNOCKBACK
				Remotes.fire(player, "Knock", { velocity = push + Vector3.new(0, KNOCKBACK * 0.7, 0) })
			end
		end
	end
end

local function buildBomb(stage, position: Vector3, kind: string): Part
	local isImpact = kind == "Impact"
	local bomb = Craft.ball(stage.model, position, 3, if isImpact then Colors.Warning else Colors.Bomb, M.Plastic)
	bomb.Name = "Bomb"
	bomb.Anchored = false
	bomb.CustomPhysicalProperties = PhysicalProperties.new(2, 0.8, 0.1)

	local cap = Craft.cylinder(stage.model, position + Vector3.new(0, 1.5, 0), 0.6, 1.2, "Y", Color3.fromRGB(150, 150, 160), M.Metal)
	weld(cap, bomb)
	cap.Parent = bomb

	if isImpact then
		-- White felt band so impact bombs read differently at a glance.
		local band = Craft.cylinder(stage.model, position, 0.6, 3.1, "Z", Color3.new(1, 1, 1), M.Felt)
		weld(band, bomb)
		band.Parent = bomb
	else
		local fuse = Craft.block(stage.model, CFrame.new(position + Vector3.new(0, 2.2, 0)), Vector3.new(0.2, 0.9, 0.2), Colors.Paper, M.Felt)
		weld(fuse, bomb)
		fuse.Parent = bomb

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

	bomb.Parent = stage.model
	bomb:SetNetworkOwner(nil) -- keep bombs server-controlled so everyone sees the same blast
	return bomb
end

function Bombs.drop(stage, position: Vector3, kind: string)
	local bomb = buildBomb(stage, position, kind)
	local exploded = false
	local function detonate()
		if exploded or not bomb.Parent then
			return
		end
		exploded = true
		local at = bomb.Position
		bomb:Destroy()
		Bombs.explode(stage, at)
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
			while elapsed < FUSE_TIME and bomb.Parent do
				local blink = math.max(0.1, 0.5 * (1 - elapsed / FUSE_TIME))
				bomb.Color = Colors.Felt
				Util.playSound("Tick", bomb, 0.3)
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

return Bombs
