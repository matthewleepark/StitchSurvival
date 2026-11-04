local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundBank = require(ReplicatedStorage.Shared.SoundBank)
local Remotes = require(script.Parent.Remotes)

local Util = {}

-- Newer materials like Cardboard may not exist in every engine version, so fall back safely.
function Util.material(name: string, fallback: Enum.Material): Enum.Material
	local ok, result = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and result then result else fallback
end

-- One-shot sound attached to a part (it moves with the part, and you hear where it is).
function Util.playSound(name: string, parent: Instance): Sound?
	local sound = SoundBank.create(name)
	if sound then
		sound.Parent = parent
		sound:Play()
		Debris:AddItem(sound, 12)
	end
	return sound
end

-- One-shot sound at a spot in the world, for things that are about to be destroyed.
function Util.soundAt(name: string, position: Vector3)
	local holder = Instance.new("Part")
	holder.Name = "SoundSpot"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position
	holder.Parent = workspace
	Util.playSound(name, holder)
	Debris:AddItem(holder, 12)
end

-- Looping sound on a part. Stops when the part is destroyed.
function Util.loopSound(name: string, parent: Instance): Sound?
	local sound = SoundBank.create(name)
	if sound then
		sound.Looped = true
		sound.Parent = parent
		sound:Play()
	end
	return sound
end

function Util.characterFromPart(part: BasePart): (Model?, Humanoid?)
	local model = part:FindFirstAncestorOfClass("Model")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return model, humanoid
	end
	return nil, nil
end

function Util.aliveHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

function Util.rootPart(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Util.weightedPick(list)
	local total = 0
	for _, entry in list do
		total += entry.weight
	end
	local roll = math.random() * total
	for _, entry in list do
		roll -= entry.weight
		if roll <= 0 then
			return entry
		end
	end
	return list[#list]
end

-- One passive of the gear this player has equipped (see Config.Gear), or nil.
function Util.passive(player: Player, key: string): any
	return Config.passive(player:GetAttribute("Gear") :: string?, key)
end

-- The "Survive one pop per round" passive: if this player has it and hasn't used it yet this round,
-- they're saved at half health instead. Returns true if it saved them.
local function secondChance(humanoid: Humanoid): boolean
	local player = Players:GetPlayerFromCharacter(humanoid.Parent)
	if not player or not Util.passive(player, "secondChance") or player:GetAttribute("ChanceUsed") then
		return false
	end
	player:SetAttribute("ChanceUsed", true)
	humanoid.Health = humanoid.MaxHealth / 2
	Remotes.fireAll("Announce", { text = `{player.DisplayName} used their second chance!`, color = Config.RarityColors.Legendary })
	return true
end

local function isGod(humanoid: Humanoid): boolean
	local character = humanoid.Parent
	return character ~= nil and (character:GetAttribute("God") == true or character:FindFirstChildOfClass("ForceField") ~= nil)
end

-- Pops a player instantly, unless they're in admin god mode or their gear gives them a second chance.
-- Returns whether they were popped.
function Util.kill(humanoid: Humanoid): boolean
	if isGod(humanoid) or humanoid.Health <= 0 or secondChance(humanoid) then
		return false
	end
	humanoid.Health = 0
	return true
end

-- Hurts a player. The toughness passive reduces all damage, and a hit that
-- would pop them can be saved by a second chance. God mode takes no damage.
function Util.damage(humanoid: Humanoid, amount: number, _armored: boolean?)
	if isGod(humanoid) or humanoid.Health <= 0 then
		return
	end
	local player = Players:GetPlayerFromCharacter(humanoid.Parent)
	if player then
		amount *= 1 - (Util.passive(player, "toughness") or 0)
	end
	if humanoid.Health - amount <= 0 and secondChance(humanoid) then
		return
	end
	humanoid:TakeDamage(amount)
end

-- Drops the up/down part of a direction (for knockbacks along the ground).
function Util.flatten(direction: Vector3): Vector3
	return Vector3.new(direction.X, 0, direction.Z)
end

-- A random point on a rectangle around `center`, `halfX` by `halfZ` studs each way.
function Util.randomAround(center: Vector3, halfX: number, halfZ: number): Vector3
	return center + Vector3.new((math.random() * 2 - 1) * halfX, 0, (math.random() * 2 - 1) * halfZ)
end

return Util
