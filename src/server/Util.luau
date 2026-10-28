local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundBank = require(ReplicatedStorage.Shared.SoundBank)

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

function Util.randomLayer(): number
	return Config.Layers[math.random(1, #Config.Layers)]
end

return Util
