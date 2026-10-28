-- The lobby: a cozy cardboard room where players wait between levels and roll for scuba gear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)

local Colors = Config.Colors
local M = Craft.Material

local Pod = {}

local function buildGearMachine(parent: Instance, base: Vector3): Part
	local machine = Instance.new("Model")
	machine.Name = "GearMachine"
	machine.Parent = parent

	-- Red felt body with a gold coin plate, like a gumball machine.
	local body = Craft.block(machine, CFrame.new(base + Vector3.new(0, 3, 0)), Vector3.new(6, 6, 5), Colors.Felt, M.Felt)
	Craft.stitches(machine, base + Vector3.new(0, 3, 2.5), 6, 6, Colors.Paper)
	Craft.block(machine, CFrame.new(base + Vector3.new(0, 3.6, 2.6)), Vector3.new(2.4, 1.6, 0.3), Colors.Gold, M.Metal, Craft.DECOR)
	Craft.label(machine, base + Vector3.new(0, 1.4, 2.6), 5, 1.4, `{Config.RollCost} STICKERS`, Colors.Paper)

	-- Glass globe full of colorful gear capsules.
	local globeCenter = base + Vector3.new(0, 9.5, 0)
	Craft.ball(machine, globeCenter, 7, Color3.new(1, 1, 1), M.Glass, { Transparency = 0.6, CanQuery = false })
	local rarities = { "Common", "Common", "Uncommon", "Uncommon", "Rare", "Rare", "Epic", "Legendary" }
	for i, rarity in rarities do
		local angle = i / #rarities * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * 1.8, math.sin(angle * 2) * 1.2 - 0.8, math.sin(angle) * 1.8)
		Craft.ball(machine, globeCenter + offset, 1.4, Config.RarityColors[rarity], M.Plastic, Craft.DECOR)
	end
	Craft.cylinder(machine, globeCenter + Vector3.new(0, 3.8, 0), 1, 3, "Y", Colors.Felt, M.Felt, Craft.DECOR)

	Craft.sign(machine, base + Vector3.new(0, 16, -1), 12, 3.5, "SCUBA GEAR", { faceColor = Color3.fromRGB(200, 235, 250) })

	return body
end

function Pod.build()
	local def = Config.Pod
	local O = def.origin
	local W = def.width
	local depth = Config.StageDepth

	local model = Instance.new("Model")
	model.Name = "Pod"
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model

	local function at(x: number, y: number, z: number?): Vector3
		return O + Vector3.new(x, y, z or 0)
	end
	local wallZ = -depth / 2

	-- Wooden plank floor with a felt rug.
	Craft.block(model, CFrame.new(at(0, -2)), Vector3.new(W + 8, 4, depth + 8), Colors.Wood, M.Wood)
	for z = -6, 6, 4 do
		Craft.block(decor, CFrame.new(at(0, 0.02, z)), Vector3.new(W + 8, 0.05, 0.2), Colors.WoodDark, M.Wood, Craft.DECOR)
	end
	Craft.block(decor, CFrame.new(at(-6, 0.1, 0)), Vector3.new(26, 0.2, 10), Colors.Felt, M.Carpet, Craft.DECOR)

	-- Cardboard back wall with stitched panels.
	Craft.block(model, CFrame.new(at(0, def.height / 2, wallZ - 1)), Vector3.new(W + 8, def.height + 8, 2), Colors.CardboardDark)
	local panelWidth = W / 4
	for i = 0, 3 do
		local x = -W / 2 + panelWidth / 2 + i * panelWidth
		local color = if i % 2 == 0 then Colors.Cardboard else Color3.fromRGB(205, 168, 120)
		Craft.panel(decor, at(x, def.height / 2, wallZ + 0.2), panelWidth - 0.6, def.height - 1, color, M.Cardboard, { stitch = true })
	end

	-- Chunky side pillars frame the room.
	for _, side in { -1, 1 } do
		Craft.block(model, CFrame.new(at(side * (W / 2 + 2), def.height / 2, 0)), Vector3.new(4, def.height + 8, depth + 8), Colors.CardboardDark)
	end

	Craft.sign(decor, at(0, def.height - 4, wallZ + 1), 24, 6, "THE POD", { bulbs = true })
	Craft.bunting(decor, at(-W / 2 + 2, def.height - 10, wallZ + 1.2), at(W / 2 - 2, def.height - 10, wallZ + 1.2))

	Craft.window(decor, at(-20, 13, wallZ + 0.6), 10, 8, Colors.Sky, Color3.fromRGB(90, 140, 200))
	Craft.picture(decor, at(-2, 14, wallZ + 0.6), 6, 4.5, Colors.Gold)
	Craft.lamp(decor, at(7, 15, wallZ + 0.5))
	Craft.lamp(decor, at(-11, 15, wallZ + 0.5))

	Craft.sticker(decor, at(-27, 22, wallZ + 0.6), 3, Colors.Felt, "HI!")
	Craft.sticker(decor, at(9, 7, wallZ + 0.6), 2.4, Color3.fromRGB(90, 160, 220), "?")
	Craft.sticker(decor, at(-8, 22, wallZ + 0.6), 2, Colors.Seaweed, "!")
	Craft.label(decor, at(-4, 7, wallZ + 0.7), 14, 2.4, "W / S to change layers", Colors.Ink)

	-- Felt couch in the back layer (players can bounce on it).
	local couchX, couchZ = -20, -4.5
	Craft.block(model, CFrame.new(at(couchX, 1.5, couchZ)), Vector3.new(10, 3, 5), Color3.fromRGB(90, 140, 200), M.Felt)
	Craft.block(model, CFrame.new(at(couchX, 4, couchZ - 2)), Vector3.new(10, 5, 1), Color3.fromRGB(74, 118, 168), M.Felt)
	for _, side in { -1, 1 } do
		Craft.block(model, CFrame.new(at(couchX + side * 5.5, 2.5, couchZ)), Vector3.new(1.2, 5, 5), Color3.fromRGB(74, 118, 168), M.Felt)
	end

	local machine = buildGearMachine(model, at(20, 0, -3))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PodSpawn"
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(at(2, 0.2, 0))
	spawn.Anchored = true
	spawn.Material = M.Felt
	spawn.Color = Colors.Gold
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = model

	Craft.boundaries(model, O, W, def.height)

	model.Parent = workspace

	return {
		model = model,
		machine = machine,
		spawn = spawn,
	}
end

return Pod
