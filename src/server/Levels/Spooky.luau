-- Creepy touches for the hotel lobby, added on top of HotelLobby's build:
--   * cobwebs strung across the high corners,
--   * dust specks drifting slowly through the air,
--   * two old portraits beside the entrance whose eyes glow red for a moment now and then,
--   * loose papers scattered across the floor,
--   * creaks and faint whispers from random spots (sound slots LobbyCreak / LobbyWhisper).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)
local Util = require(script.Parent.Parent.Util)

local L = Config.LobbyColors
local M = Craft.Material
local DECOR = Craft.DECOR

local Spooky = {}

local WEB = Color3.fromRGB(225, 225, 230)

-- A cobweb in a ceiling corner: a see-through sheet across the corner plus a few strands.
local function cobweb(parent: Instance, corner: Vector3, inward: Vector3)
	local size = 7
	local center = corner + inward * (size * 0.35) + Vector3.new(0, -size * 0.3, 0)
	local sheet = Craft.block(parent, CFrame.lookAt(center, center + inward), Vector3.new(size, size * 0.7, 0.05), WEB, M.Plastic, DECOR)
	sheet.Transparency = 0.8
	sheet.CastShadow = false
	for i = 1, 4 do
		local spread = Vector3.new(inward.X * (i / 4), -(i / 4) * 0.8, inward.Z * (1 - i / 4))
		local tip = corner + spread.Unit * size * 0.8
		local strand = Craft.block(parent, CFrame.lookAt((corner + tip) / 2, tip), Vector3.new(0.06, 0.06, (tip - corner).Magnitude), WEB, M.Plastic, DECOR)
		strand.Transparency = 0.35
		strand.CastShadow = false
	end
end

-- An old portrait: dark oval face in a gilt frame. Returns its two eyes (hidden until they glow).
local function portrait(parent: Instance, cframe: CFrame): { BasePart }
	local model = Instance.new("Model")
	Craft.block(model, CFrame.identity, Vector3.new(5.2, 6.6, 0.3), L.Brass, M.Wood, DECOR)
	Craft.block(model, CFrame.new(0, 0, 0.16), Vector3.new(4.4, 5.8, 0.05), Color3.fromRGB(34, 30, 34), M.Felt, DECOR)
	local face = Craft.disc(model, Vector3.new(0, 0.6, 0.22), 2.6, Color3.fromRGB(90, 80, 74), M.Felt, DECOR)
	face.Size = Vector3.new(0.05, 3.2, 2.4) -- taller than wide: an oval
	Craft.block(model, CFrame.new(0, -1.9, 0.22), Vector3.new(3.4, 1.8, 0.05), Color3.fromRGB(50, 40, 44), M.Felt, DECOR) -- shoulders
	local eyes = {}
	for _, x in { -0.45, 0.45 } do
		local eye = Craft.ball(model, Vector3.new(x, 0.9, 0.3), 0.28, Color3.fromRGB(255, 40, 40), M.Neon, DECOR)
		eye.Transparency = 1
		table.insert(eyes, eye)
	end
	model.Parent = parent
	model:PivotTo(cframe)
	return eyes
end

function Spooky.decorate(model: Model, origin: Vector3, width: number, depth: number, height: number)
	local decor = Instance.new("Folder")
	decor.Name = "Spooky"
	decor.Parent = model
	local halfW, halfD = width / 2, depth / 2

	-- Cobwebs in all four top corners, and in the corners above the entrance.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local corner = origin + Vector3.new(sx * halfW, height, sz * halfD)
			cobweb(decor, corner, Vector3.new(-sx, 0, -sz).Unit)
		end
		cobweb(decor, origin + Vector3.new(sx * 7.5, 19, halfD), Vector3.new(-sx, 0, -1).Unit)
	end

	-- Dust specks drifting through the whole room.
	if Config.Spooky.dust > 0 then
		local volume = Craft.block(decor, CFrame.new(origin + Vector3.new(0, height / 2, 0)), Vector3.new(width - 4, height - 4, depth - 4), Color3.new(), nil, DECOR)
		volume.Transparency = 1
		local dust = Instance.new("ParticleEmitter")
		dust.Shape = Enum.ParticleEmitterShape.Box
		dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		dust.Rate = Config.Spooky.dust
		dust.Lifetime = NumberRange.new(8, 14)
		dust.Speed = NumberRange.new(0.1, 0.4)
		dust.SpreadAngle = Vector2.new(180, 180)
		dust.Size = NumberSequence.new(0.08)
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.5), NumberSequenceKeypoint.new(1, 1) })
		dust.Color = ColorSequence.new(Color3.fromRGB(220, 210, 190))
		dust.LightEmission = 0.2
		dust.Parent = volume
	end

	-- Portraits on the front wall, either side of the entrance, facing into the room.
	local allEyes = {}
	for _, sx in { -1, 1 } do
		local spot = origin + Vector3.new(sx * 16, 13, halfD - 0.4)
		for _, eye in portrait(decor, CFrame.new(spot) * CFrame.Angles(0, math.pi, 0)) do
			table.insert(allEyes, eye)
		end
	end

	-- Loose papers on the floor.
	for _ = 1, 14 do
		local spot = Util.randomAround(origin, halfW - 14, halfD - 6) + Vector3.new(0, 0.12, 0)
		local paper = Craft.block(decor, CFrame.new(spot) * CFrame.Angles(0, math.random() * math.pi * 2, 0), Vector3.new(1.1, 0.03, 1.4), Color3.fromRGB(214, 206, 186), M.Plastic, DECOR)
		paper.CastShadow = false
	end

	-- Now and then a portrait's eyes glow for a moment, and the building creaks or whispers.
	task.spawn(function()
		while decor.Parent do
			local wait = Config.Spooky.eyesEvery
			task.wait(math.random(wait[1], wait[2]))
			local pair = math.random(0, #allEyes / 2 - 1) * 2
			for i = 1, 2 do
				allEyes[pair + i].Transparency = 0
			end
			Util.soundAt(if math.random() < 0.5 then "LobbyCreak" else "LobbyWhisper", allEyes[pair + 1].Position)
			task.wait(1.2)
			for i = 1, 2 do
				allEyes[pair + i].Transparency = 1
			end
		end
	end)
end

return Spooky
