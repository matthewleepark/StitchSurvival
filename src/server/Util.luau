local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Util = {}

-- Newer materials like Cardboard may not exist in every engine version, so fall back safely.
function Util.material(name: string, fallback: Enum.Material): Enum.Material
	local ok, result = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and result then result else fallback
end

function Util.playSound(name: string, parent: Instance, volume: number?)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 10)
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
