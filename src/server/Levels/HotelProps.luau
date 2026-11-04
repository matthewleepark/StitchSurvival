-- Furniture and fittings for the hotel lobby (HotelLobby.luau decides where they go).
-- Every builder makes its prop around the origin, facing +Z with the floor at y = 0, then moves it
-- into place with the CFrame you pass in. Add CFrame.Angles(0, yaw, 0) to turn it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)

local Colors = Config.Colors
local L = Config.LobbyColors
local M = Craft.Material
local DECOR = Craft.DECOR
local MARBLE = Enum.Material.Marble

local Props = {}

local function start(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	return model
end

-- Moves everything built at the origin to `cframe`, then drops it into the world.
local function finish(model: Model, parent: Instance, cframe: CFrame): Model
	model:PivotTo(cframe * model:GetPivot())
	model.Parent = parent
	return model
end

local function box(parent: Instance, x: number, y: number, z: number, w: number, h: number, d: number, color: Color3, material: Enum.Material?, props)
	return Craft.block(parent, CFrame.new(x, y, z), Vector3.new(w, h, d), color, material, props)
end

local function tube(parent: Instance, x: number, y: number, z: number, length: number, diameter: number, axis: string, color: Color3, material: Enum.Material?, props)
	return Craft.cylinder(parent, Vector3.new(x, y, z), length, diameter, axis, color, material, props)
end

local function orb(parent: Instance, x: number, y: number, z: number, diameter: number, color: Color3, material: Enum.Material?, props)
	return Craft.ball(parent, Vector3.new(x, y, z), diameter, color, material, props)
end

local function addLight(part: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	Craft.tag(light, "FlickerLight") -- Mood.luau makes these stutter now and then
	light.Parent = part
end

local WARM = Color3.fromRGB(255, 200, 130) -- a tired, yellowish bulb
local BLACK = Color3.fromRGB(26, 24, 30)
local FLOWERS = {
	Color3.fromRGB(255, 120, 150),
	Color3.fromRGB(255, 214, 90),
	Color3.fromRGB(250, 250, 244),
	Color3.fromRGB(190, 130, 235),
	Color3.fromRGB(255, 150, 90),
}
local BOOKS = {
	Color3.fromRGB(150, 44, 58),
	Color3.fromRGB(40, 58, 100),
	Color3.fromRGB(60, 120, 80),
	Color3.fromRGB(190, 150, 70),
	Color3.fromRGB(110, 70, 120),
	Color3.fromRGB(90, 70, 52),
	Color3.fromRGB(210, 200, 180),
}

-- Seating --------------------------------------------------------------------

-- A tufted sofa (armchairs are just a narrow one). Seats face +Z.
function Props.sofa(parent: Instance, cframe: CFrame, color: Color3, width: number?)
	local w = width or 10
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.22)
	local m = start("Sofa")
	local cushionW = (w - 2.4) / 2 - 0.1

	box(m, 0, 1.2, 0, w, 1.2, 4.2, dark, M.Felt)
	box(m, 0, 3.4, -1.75, w, 3.6, 0.8, dark, M.Felt)
	for _, side in { -1, 1 } do
		local cx = side * (cushionW / 2 + 0.05)
		box(m, cx, 2.1, 0.4, cushionW, 0.9, 3.4, color, M.Felt)
		box(m, cx, 3.7, -1.1, cushionW, 2.4, 0.8, color, M.Felt)
		orb(m, cx, 3.7, -0.65, 0.3, L.Brass, M.Metal, DECOR)
		box(m, side * (w / 2 - 0.55), 2.5, 0, 1.1, 2.6, 4.2, dark, M.Felt)
		tube(m, side * (w / 2 - 0.55), 3.9, 0, 4.2, 1.2, "Z", color, M.Felt)
		for _, z in { -1.7, 1.7 } do
			tube(m, side * (w / 2 - 0.6), 0.3, z, 0.6, 0.5, "Y", L.Brass, M.Metal, DECOR)
		end
	end
	return finish(m, parent, cframe)
end

function Props.coffeeTable(parent: Instance, cframe: CFrame)
	local m = start("CoffeeTable")
	box(m, 0, 1.9, 0, 6, 0.35, 3.2, L.Marble, MARBLE)
	box(m, 0, 1.65, 0, 6.3, 0.2, 3.5, L.Brass, M.Metal, DECOR)
	box(m, 0, 0.7, 0, 5.2, 0.2, 2.4, L.Panel, M.Wood)
	for _, x in { -2.7, 2.7 } do
		for _, z in { -1.3, 1.3 } do
			box(m, x, 0.9, z, 0.3, 1.8, 0.3, L.Brass, M.Metal)
		end
	end
	-- Little vase of flowers.
	tube(m, 0, 2.7, 0, 1.2, 0.8, "Y", L.Teal, M.Glass, DECOR)
	for i, color in FLOWERS do
		local a = i / #FLOWERS * math.pi * 2
		orb(m, math.cos(a) * 0.5, 3.5 + (i % 2) * 0.2, math.sin(a) * 0.5, 0.55, color, M.Felt, DECOR)
	end
	return finish(m, parent, cframe)
end

-- A round side table with a shaded lamp.
function Props.sideTable(parent: Instance, cframe: CFrame)
	local m = start("SideTable")
	tube(m, 0, 0.2, 0, 0.4, 2.2, "Y", L.Brass, M.Metal)
	tube(m, 0, 1.4, 0, 2.4, 0.4, "Y", L.Brass, M.Metal)
	tube(m, 0, 2.7, 0, 0.3, 2.8, "Y", L.Marble, MARBLE)
	tube(m, 0, 3.2, 0, 1, 0.5, "Y", L.Brass, M.Metal, DECOR)
	local bulb = orb(m, 0, 4.2, 0, 0.7, WARM, M.Neon, DECOR)
	tube(m, 0, 4.2, 0, 1.4, 1.9, "Y", L.Cream, M.Felt, DECOR)
	addLight(bulb, WARM, 18, 0.5)
	return finish(m, parent, cframe)
end

function Props.plant(parent: Instance, cframe: CFrame, scale: number?)
	local s = scale or 1
	local m = start("Plant")
	tube(m, 0, 1.4 * s, 0, 2.8 * s, 3 * s, "Y", L.Terracotta, M.Plastic)
	tube(m, 0, 2.9 * s, 0, 0.5 * s, 3.4 * s, "Y", L.Terracotta, M.Plastic)
	tube(m, 0, 3.1 * s, 0, 0.2 * s, 2.8 * s, "Y", L.Soil, M.Plastic, DECOR)
	tube(m, 0, 5.4 * s, 0, 4.6 * s, 0.5 * s, "Y", L.Trunk, M.Wood, DECOR)
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		local frond = CFrame.new(0, 7.6 * s, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, 1.7 * s) * CFrame.Angles(math.rad(28), 0, 0)
		Craft.block(m, frond, Vector3.new(1 * s, 0.15 * s, 3.6 * s), if i % 2 == 0 then L.Leaf else L.LeafDark, M.Felt, DECOR)
	end
	return finish(m, parent, cframe)
end

-- Round marble table with a huge bouquet: the first thing you see walking in.
function Props.centerpiece(parent: Instance, cframe: CFrame)
	local m = start("Centerpiece")
	local rng = Random.new(7)
	tube(m, 0, 0.4, 0, 0.8, 6, "Y", L.Marble, MARBLE)
	tube(m, 0, 2, 0, 3, 2, "Y", L.Marble, MARBLE)
	tube(m, 0, 3.4, 0, 0.25, 9.6, "Y", L.Brass, M.Metal)
	tube(m, 0, 3.65, 0, 0.3, 9, "Y", L.Marble, MARBLE)
	tube(m, 0, 5.4, 0, 3.2, 3, "Y", L.Teal, M.Glass)
	tube(m, 0, 7.2, 0, 0.4, 3.4, "Y", L.Brass, M.Metal, DECOR)
	for i = 1, 10 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber() * 2.6
		local y = 9 + (3 - r) * 0.7 + rng:NextNumber() * 0.8
		tube(m, math.cos(a) * r * 0.5, 7.9, math.sin(a) * r * 0.5, 1.6, 0.12, "Y", L.Leaf, M.Plastic, DECOR)
		orb(m, math.cos(a) * r, y, math.sin(a) * r, 0.9 + rng:NextNumber() * 0.5, FLOWERS[i % #FLOWERS + 1], M.Felt, DECOR)
	end
	return finish(m, parent, cframe)
end

-- Lighting -------------------------------------------------------------------

-- `position` is where it hangs from the ceiling.
function Props.chandelier(parent: Instance, position: Vector3)
	local m = start("Chandelier")
	tube(m, 0, 4.2, 0, 8.4, 0.4, "Y", L.Brass, M.Metal, DECOR)
	tube(m, 0, 0.5, 0, 1.6, 1.6, "Y", L.Brass, M.Metal, DECOR)
	local hub = orb(m, 0, -0.9, 0, 1.4, L.Brass, M.Metal, DECOR)
	addLight(hub, WARM, 45, 0.8)

	for tier = 1, 2 do
		local radius = 3 + tier * 2.2
		local y = 1.2 - tier * 1.6
		local count = 4 + tier * 2
		local hubPoint = Vector3.new(0, -0.5, 0)
		for i = 1, count do
			local a = i / count * math.pi * 2
			local pos = Vector3.new(math.cos(a) * radius, y, math.sin(a) * radius)
			local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
			Craft.block(m, CFrame.lookAt(pos, pos + tangent), Vector3.new(0.45, 0.4, 2 * radius * math.sin(math.pi / count) + 0.15), L.Brass, M.Metal, DECOR)
			tube(m, pos.X, y + 0.9, pos.Z, 1.2, 0.5, "Y", L.Cream, M.Plastic, DECOR)
			orb(m, pos.X, y + 1.8, pos.Z, 0.55, Colors.Gold, M.Neon, DECOR)
		end
		for k = 1, 4 do
			local a = k / 4 * math.pi * 2 + tier
			local ringPoint = Vector3.new(math.cos(a) * radius, y, math.sin(a) * radius)
			local middle = (hubPoint + ringPoint) / 2
			Craft.block(m, CFrame.lookAt(middle, ringPoint), Vector3.new(0.3, 0.3, (ringPoint - hubPoint).Magnitude), L.Brass, M.Metal, DECOR)
		end
	end
	return finish(m, parent, CFrame.new(position) * CFrame.new(0, -8.4, 0))
end

-- A small globe lamp on a short chain, for the low ceilings under the balconies.
function Props.pendant(parent: Instance, position: Vector3)
	local m = start("Pendant")
	tube(m, 0, 0.75, 0, 1.5, 0.2, "Y", L.Brass, M.Metal, DECOR)
	local globe = orb(m, 0, -0.5, 0, 2.2, WARM, M.Neon, DECOR)
	globe.Transparency = 0.25
	tube(m, 0, 0.4, 0, 0.4, 1.2, "Y", L.Brass, M.Metal, DECOR)
	addLight(globe, WARM, 22, 0.6)
	return finish(m, parent, CFrame.new(position) * CFrame.new(0, -1.5, 0))
end

-- Wall lamp (flat on the wall, so place it with the wall's CFrame).
function Props.sconce(parent: Instance, cframe: CFrame)
	local m = start("Sconce")
	Craft.lamp(m, Vector3.zero)
	for _, descendant in m:GetDescendants() do
		if descendant:IsA("PointLight") then
			descendant.Brightness = 0.5
			descendant.Shadows = false
			Craft.tag(descendant, "FlickerLight")
		end
	end
	return finish(m, parent, cframe)
end

-- Architecture -----------------------------------------------------------------

function Props.pillar(parent: Instance, position: Vector3, height: number)
	local m = start("Pillar")
	local shaft = height - 4.4
	box(m, 0, 0.6, 0, 4.8, 1.2, 4.8, L.Marble, MARBLE)
	box(m, 0, 1.4, 0, 4, 0.4, 4, L.Brass, M.Metal, DECOR)
	tube(m, 0, 1.6 + shaft / 2, 0, shaft, 3, "Y", L.Marble, MARBLE)
	tube(m, 0, 1.8, 0, 0.4, 3.5, "Y", L.Brass, M.Metal, DECOR)
	tube(m, 0, height - 3, 0, 0.4, 3.5, "Y", L.Brass, M.Metal, DECOR)
	box(m, 0, height - 2.2, 0, 4, 1.2, 4, L.Marble, MARBLE)
	box(m, 0, height - 1.35, 0, 5.4, 0.3, 5.4, L.Brass, M.Metal, DECOR)
	box(m, 0, height - 0.6, 0, 4.8, 1.2, 4.8, L.Marble, MARBLE)
	return finish(m, parent, CFrame.new(position))
end

-- A wall-to-wall rug: gold fringe, solid velvet field (so footsteps go soft), stitched lines, medallion.
function Props.rug(parent: Instance, center: Vector3, width: number, depth: number, color: Color3, accent: Color3)
	local m = start("Rug")
	box(m, 0, 0.08, 0, width, 0.16, depth, L.Brass, M.Felt, DECOR)
	box(m, 0, 0.1, 0, width - 0.8, 0.2, depth - 0.8, color, M.Carpet)
	local inset = 1.6
	for _, side in { -1, 1 } do
		box(m, 0, 0.22, side * (depth / 2 - inset), width - inset * 2, 0.04, 0.3, accent, M.Felt, DECOR)
		box(m, side * (width / 2 - inset), 0.22, 0, 0.3, 0.04, depth - inset * 2, accent, M.Felt, DECOR)
	end
	if math.min(width, depth) >= 10 then
		tube(m, 0, 0.24, 0, 0.04, math.min(width, depth) * 0.4, "Y", accent, M.Felt, DECOR)
	end
	return finish(m, parent, CFrame.new(center))
end

-- Big double glass doors in a brass frame. Place with the front wall's CFrame.
function Props.entranceDoor(parent: Instance, cframe: CFrame)
	-- Tall mahogany double doors in a brass frame, with a glowing transom window above (light from
	-- the street outside), so the entrance reads as a real way in even in the dark lobby.
	local m = start("EntranceDoor")
	box(m, 0, 9, 0.15, 13, 18, 0.3, L.PanelDark, M.Wood, DECOR) -- dark recess behind the doors
	for _, side in { -1, 1 } do
		box(m, side * 6.2, 9, 0.5, 0.8, 18, 1, L.Brass, M.Metal, DECOR) -- frame posts
		local leaf = side * 2.8
		box(m, leaf, 7.5, 0.45, 5.4, 15, 0.4, L.Panel, M.Wood, DECOR) -- door leaf
		for _, y in { 4, 11 } do -- two raised panels per leaf
			box(m, leaf, y, 0.7, 3.8, 5.2, 0.15, L.PanelDark, M.Wood, DECOR)
			box(m, leaf, y, 0.8, 3.2, 4.6, 0.1, L.Panel, M.Wood, DECOR)
		end
		tube(m, side * 0.7, 7.5, 0.9, 3.4, 0.3, "Y", L.Brass, M.Metal, DECOR) -- long brass pull handle
		box(m, leaf, 0.4, 0.7, 5.4, 0.8, 0.2, L.Brass, M.Metal, DECOR) -- kick plate
	end
	box(m, 0, 15.4, 0.6, 13.2, 0.8, 1, L.Brass, M.Metal, DECOR) -- lintel
	local transom = box(m, 0, 17, 0.4, 11.4, 2.2, 0.15, Color3.fromRGB(255, 200, 130), M.Neon, DECOR)
	transom.Transparency = 0.45
	for x = -3.8, 3.8, 3.8 do
		box(m, x, 17, 0.55, 0.2, 2.2, 0.1, L.Brass, M.Metal, DECOR) -- transom bars
	end
	box(m, 0, 18.4, 0.6, 13.2, 0.6, 1, L.Brass, M.Metal, DECOR)
	box(m, 0, 0.15, 1.2, 12.6, 0.3, 2.4, L.Brass, M.Metal, DECOR) -- threshold
	return finish(m, parent, cframe)
end

-- Elevator with a floor-indicator arc and call buttons. Place with a wall's CFrame.
function Props.elevator(parent: Instance, cframe: CFrame)
	local m = start("Elevator")
	box(m, 0, 6.6, 0.3, 9, 13.2, 0.6, L.Brass, M.Metal, DECOR)
	box(m, 0, 6.2, 0.62, 7.6, 12.4, 0.12, L.PanelDark, M.Wood, DECOR)
	for _, side in { -1, 1 } do
		box(m, side * 1.85, 5.9, 0.78, 3.6, 11.8, 0.25, Color3.fromRGB(218, 214, 204), M.Metal, DECOR)
		box(m, side * 1.85, 5.9, 0.93, 2.8, 10.2, 0.08, Color3.fromRGB(190, 186, 176), M.Metal, DECOR)
	end
	box(m, 0, 5.9, 0.95, 0.12, 11.8, 0.1, BLACK, M.Plastic, DECOR)
	-- Floor lamps in an arc above the doors.
	for i = 0, 4 do
		local a = math.rad(30 + i * 30)
		local on = i == 1
		orb(m, math.cos(a) * 2.8, 12.6 + math.sin(a) * 1.5 - 1.2, 1, 0.5, if on then Colors.Gold else Color3.fromRGB(110, 90, 60), M.Neon, DECOR)
	end
	-- Call buttons.
	box(m, 5.6, 5.5, 0.4, 1, 2.2, 0.3, L.Brass, M.Metal, DECOR)
	orb(m, 5.6, 6.1, 0.65, 0.5, Colors.Gold, M.Neon, DECOR)
	orb(m, 5.6, 4.9, 0.65, 0.5, Colors.Gold, M.Neon, DECOR)
	return finish(m, parent, cframe)
end

-- A numbered guest room door. Place with a wall's CFrame; the floor is y = 0.
function Props.roomDoor(parent: Instance, cframe: CFrame, number: number)
	local m = start(`Room{number}`)
	box(m, 0, 4.7, 0.3, 6.4, 9.4, 0.6, L.PanelDark, M.Wood, DECOR)
	box(m, 0, 4.2, 0.65, 4.8, 8.4, 0.3, L.Panel, M.Wood, DECOR)
	box(m, 0, 4.2, 0.82, 3.4, 6.6, 0.1, L.PanelLight, M.Wood, DECOR)
	orb(m, 1.8, 4.2, 1.0, 0.55, L.Brass, M.Metal, DECOR)
	box(m, 0, 7.5, 0.85, 2.4, 1, 0.1, L.Brass, M.Metal, DECOR)
	Craft.label(m, Vector3.new(0, 7.5, 0.93), 2, 0.8, tostring(number), L.PanelDark, Enum.Font.GothamBold)
	return finish(m, parent, cframe)
end

-- Reception ------------------------------------------------------------------

-- The front desk: mahogany with a marble top, brass rail, service bell and guest book.
function Props.reception(parent: Instance, cframe: CFrame)
	local m = start("ReceptionDesk")
	box(m, 0, 2.2, 0, 24, 4.4, 4.4, L.Panel, M.Wood)
	for i = -5, 5 do
		box(m, i * 2.1, 2.2, 2.25, 1.8, 3, 0.15, L.PanelLight, M.Wood, DECOR)
	end
	box(m, 0, 4.65, 0.4, 25.2, 0.5, 6, L.Marble, MARBLE)
	box(m, 0, 4.35, 0.4, 25.4, 0.3, 6.2, L.Brass, M.Metal, DECOR)
	box(m, 0, 0.3, 0, 24.6, 0.6, 4.8, L.PanelDark, M.Wood, DECOR)
	tube(m, 0, 0.9, 3.2, 22, 0.35, "X", L.Brass, M.Metal, DECOR)
	for _, x in { -10, 0, 10 } do
		tube(m, x, 0.55, 3.2, 0.9, 0.3, "Y", L.Brass, M.Metal, DECOR)
	end
	-- Service bell, guest book, pen and a lamp.
	tube(m, -6, 5, 1.6, 0.2, 1.4, "Y", L.Brass, M.Metal, DECOR)
	orb(m, -6, 5.3, 1.6, 1.1, L.Brass, M.Metal, DECOR)
	box(m, 3, 5, 1.8, 2.6, 0.3, 1.9, L.Velvet, M.Felt, DECOR)
	box(m, 3, 5.2, 1.8, 2.3, 0.15, 1.6, L.Cream, M.Foam, DECOR)
	tube(m, 7, 5.3, 1.6, 0.6, 0.5, "Y", L.Brass, M.Metal, DECOR)
	tube(m, 7.1, 6, 1.5, 1.6, 0.08, "Y", BLACK, M.Plastic, DECOR)
	tube(m, 10, 5.1, 0.4, 0.2, 1.4, "Y", L.Brass, M.Metal, DECOR)
	tube(m, 10, 6.1, 0.4, 2, 0.2, "Y", L.Brass, M.Metal, DECOR)
	local bulb = orb(m, 10, 7.4, 0.4, 0.7, WARM, M.Neon, DECOR)
	tube(m, 10, 7.2, 0.4, 1.3, 1.8, "Y", Color3.fromRGB(40, 110, 80), M.Felt, DECOR)
	addLight(bulb, WARM, 14, 0.5)
	return finish(m, parent, cframe)
end

-- Room-key board for behind the desk (flat on the wall; origin is the board's center).
function Props.keyBoard(parent: Instance, cframe: CFrame)
	local m = start("KeyBoard")
	box(m, 0, 0, 0.3, 18, 8, 0.6, L.PanelDark, M.Wood, DECOR)
	for _, side in { -1, 1 } do
		box(m, 0, side * 3.9, 0.65, 18.2, 0.25, 0.2, L.Brass, M.Metal, DECOR)
		box(m, side * 8.9, 0, 0.65, 0.25, 8, 0.2, L.Brass, M.Metal, DECOR)
	end
	for col = 0, 7 do
		if col ~= 3 and col ~= 6 then -- two keys are missing
			local x = -7.5 + col * 2.14
			box(m, x, 0.4, 0.72, 0.5, 1.4, 0.1, L.Brass, M.Metal, DECOR)
			orb(m, x, -0.5, 0.72, 0.5, L.Velvet, M.Plastic, DECOR)
		end
	end
	return finish(m, parent, cframe)
end

-- Pigeonholes for letters (flat on the wall; origin is the center).
function Props.mailboxes(parent: Instance, cframe: CFrame)
	local m = start("Mailboxes")
	local rng = Random.new(3)
	local cols, rows, cell = 6, 4, 2.4
	local w, h = cols * cell, rows * cell
	box(m, 0, 0, 0.2, w, h, 0.4, L.PanelDark, M.Wood, DECOR)
	for c = 0, cols do
		box(m, -w / 2 + c * cell, 0, 0.9, 0.2, h + 0.2, 1.4, L.Panel, M.Wood, DECOR)
	end
	for r = 0, rows do
		box(m, 0, -h / 2 + r * cell, 0.9, w + 0.2, 0.2, 1.4, L.Panel, M.Wood, DECOR)
	end
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			if rng:NextNumber() > 0.45 then
				local x = -w / 2 + c * cell + cell / 2
				local y = -h / 2 + r * cell + cell / 2 - 0.2
				box(m, x, y, 0.8, 1.5, 1.2, 0.2, L.Cream, M.Foam, DECOR)
			end
		end
	end
	return finish(m, parent, cframe)
end

-- Fireplace with a marble surround, crackling neon flames and a portrait above the mantel.
function Props.fireplace(parent: Instance, cframe: CFrame)
	local m = start("Fireplace")
	for _, side in { -1, 1 } do
		box(m, side * 3.6, 4.6, 0.9, 1.8, 9.2, 1.8, L.Marble, MARBLE)
		box(m, side * 3.6, 0.5, 1, 2.2, 1, 2.2, L.MarbleShade, MARBLE, DECOR)
		tube(m, side * 3.6, 9.3, 1.9, 0.3, 2.2, "Y", L.Brass, M.Metal, DECOR)
	end
	box(m, 0, 4.3, 0.2, 5.4, 8.6, 0.4, BLACK, M.Plastic)
	box(m, 0, 9.9, 0.9, 9.4, 1.4, 1.8, L.Marble, MARBLE)
	box(m, 0, 10.8, 1.2, 10.8, 0.6, 2.6, L.Panel, M.Wood)
	-- Chimney breast to the ceiling, with a picture over the mantel.
	box(m, 0, 24, 0.5, 9, 26, 1, L.Marble, MARBLE)
	Craft.picture(m, Vector3.new(0, 16, 1.1), 5.2, 6.4, Colors.Gold)
	-- Logs and flames.
	tube(m, -0.8, 0.9, 1.1, 4, 0.9, "X", L.Panel, M.Wood, DECOR)
	tube(m, 0.8, 1.7, 1.3, 3.4, 0.9, "X", L.PanelLight, M.Wood, DECOR)
	local flames = {
		{ -1.2, 3.2, 2.6, L.Fire },
		{ 0, 4, 3.4, Colors.Gold },
		{ 1.2, 3, 2.4, L.Fire },
	}
	local firstFlame
	for _, f in flames do
		local flame = Craft.diamond(m, Vector3.new(f[1], f[2], 0.9), f[3], f[4], M.Neon, DECOR)
		firstFlame = firstFlame or flame
	end
	addLight(firstFlame, L.Fire, 34, 1.1)
	-- Candlesticks on the mantel.
	for _, x in { -4, 4 } do
		tube(m, x, 11.9, 1.4, 1.6, 0.4, "Y", L.Brass, M.Metal, DECOR)
		orb(m, x, 12.9, 1.4, 0.45, Colors.Gold, M.Neon, DECOR)
	end
	-- Hearth rug.
	tube(m, 0, 0.06, 5, 0.12, 8, "Y", L.Cream, M.Felt, DECOR)
	return finish(m, parent, cframe)
end

-- Library and music -------------------------------------------------------------

-- Bookcase full of books, flat against a wall (faces +Z).
function Props.bookshelf(parent: Instance, cframe: CFrame, width: number, height: number, seed: number?)
	local m = start("Bookshelf")
	local rng = Random.new(seed or 1)
	local depth = 2
	local bays = math.floor(height / 2.8)
	local gap = height / bays

	box(m, 0, height / 2, -0.9, width, height, 0.2, L.PanelDark, M.Wood)
	for _, side in { -1, 1 } do
		box(m, side * (width / 2 - 0.2), height / 2, 0, 0.4, height, depth, L.Panel, M.Wood)
	end
	box(m, 0, height + 0.3, 0, width + 0.8, 0.6, depth + 0.6, L.PanelDark, M.Wood)
	for s = 0, bays - 1 do
		box(m, 0, 0.15 + s * gap, 0, width - 0.4, 0.3, depth, L.Panel, M.Wood)
		local x = -width / 2 + 0.6
		while x < width / 2 - 1.2 do
			local bw = 0.5 + rng:NextNumber() * 0.5
			local bh = (gap - 0.7) * (0.65 + rng:NextNumber() * 0.35)
			if rng:NextNumber() > 0.25 then -- plenty of gaps: the shelves have been picked over
				box(m, x + bw / 2, 0.3 + s * gap + bh / 2, 0.1, bw, bh, 1.3, BOOKS[rng:NextInteger(1, #BOOKS)], M.Cardboard, DECOR)
			end
			x += bw + 0.03
		end
	end
	box(m, 0, height - 0.15, 0, width - 0.4, 0.3, depth, L.Panel, M.Wood)
	return finish(m, parent, cframe)
end

-- Grand piano and bench. The keyboard faces +Z; the body extends toward -Z.
function Props.piano(parent: Instance, cframe: CFrame)
	local m = start("GrandPiano")
	box(m, 0, 3.4, -3.6, 7.6, 1.6, 9.8, BLACK, M.Plastic)
	box(m, 0, 3, 2.0, 7, 0.3, 2.4, BLACK, M.Plastic)
	box(m, 0, 3.25, 2.1, 6.6, 0.2, 2, L.Cream, M.Plastic, DECOR)
	for i = 0, 12 do
		if i % 7 ~= 2 and i % 7 ~= 6 then
			box(m, -3 + i * 0.5, 3.42, 1.7, 0.28, 0.15, 1.1, BLACK, M.Plastic, DECOR)
		end
	end
	box(m, 0, 4.7, 0.7, 3.4, 2.2, 0.15, L.Cream, M.Foam, DECOR)
	-- Open lid propped up on one side.
	Craft.block(m, CFrame.new(3.4, 5.3, -3.6) * CFrame.Angles(0, 0, math.rad(38)), Vector3.new(6.4, 0.2, 9.4), BLACK, M.Plastic, DECOR)
	for _, x in { -3.2, 3.2 } do
		tube(m, x, 1.3, 2.4, 2.6, 0.6, "Y", BLACK, M.Plastic)
	end
	tube(m, 0, 1.3, -7.5, 2.6, 0.7, "Y", BLACK, M.Plastic)
	for _, x in { -0.8, 0, 0.8 } do
		box(m, x, 0.4, 2.8, 0.5, 0.15, 0.9, L.Brass, M.Metal, DECOR)
	end
	-- Bench.
	box(m, 0, 1.9, 5.8, 4.2, 0.8, 1.9, L.Velvet, M.Felt)
	for _, x in { -1.8, 1.8 } do
		for _, z in { 5.1, 6.5 } do
			box(m, x, 0.75, z, 0.3, 1.5, 0.3, L.Brass, M.Metal, DECOR)
		end
	end
	return finish(m, parent, cframe)
end

-- Bellhop's brass luggage cart piled with suitcases.
function Props.luggageCart(parent: Instance, cframe: CFrame)
	local m = start("LuggageCart")
	box(m, 0, 1.2, 0, 5, 0.3, 3.4, L.Brass, M.Metal)
	for _, side in { -1, 1 } do
		tube(m, side * 2.3, 4.2, -1.5, 6.2, 0.3, "Y", L.Brass, M.Metal, DECOR)
		tube(m, side * 2.3, 4.2, 1.5, 2.2, 0.25, "Y", L.Brass, M.Metal, DECOR)
		for _, z in { -1.3, 1.3 } do
			tube(m, side * 2.5, 0.6, z, 0.4, 1.2, "X", BLACK, M.Plastic, DECOR)
		end
	end
	box(m, 0, 7.2, -1.5, 4.9, 0.3, 0.3, L.Brass, M.Metal, DECOR)
	box(m, 0, 4.4, -1.5, 4.6, 0.2, 0.2, L.Brass, M.Metal, DECOR)
	-- Suitcases, a hat box and a trunk-sticker or two.
	box(m, -0.9, 2.8, 0.1, 2.8, 3, 1.4, L.Velvet, M.Felt)
	box(m, 1.2, 2.5, 0.1, 2.2, 2.4, 1.4, L.Navy, M.Felt)
	box(m, 0, 4.6, 0.1, 3, 1.6, 1.3, L.Panel, M.Wood)
	tube(m, 1.2, 4.3, 0.1, 1.4, 1.6, "Y", L.Cream, M.Cardboard)
	for _, x in { -0.9, 1.2 } do
		box(m, x, 4.35, 0.85, 1.2, 0.2, 0.1, L.Brass, M.Metal, DECOR)
	end
	box(m, -0.9, 3.2, 0.82, 0.9, 0.9, 0.06, Colors.Gold, M.Plastic, DECOR)
	box(m, 1.2, 2.7, 0.82, 0.8, 0.8, 0.06, Colors.Sea, M.Plastic, DECOR)
	return finish(m, parent, cframe)
end

-- Tall pendulum clock with a face, hands and a brass pendulum.
function Props.grandfatherClock(parent: Instance, cframe: CFrame)
	local m = start("GrandfatherClock")
	box(m, 0, 0.6, 0, 4, 1.2, 2.6, L.PanelDark, M.Wood)
	box(m, 0, 6, 0, 3.4, 9.6, 2.2, L.Panel, M.Wood)
	box(m, 0, 11.3, 0, 4, 1.2, 2.8, L.PanelDark, M.Wood)
	box(m, 0, 12.2, 0, 3, 0.8, 2.2, L.Panel, M.Wood)
	orb(m, 0, 13, 0, 0.8, L.Brass, M.Metal, DECOR)
	Craft.disc(m, Vector3.new(0, 9.4, 1.15), 2.8, L.Cream, M.Foam, DECOR)
	box(m, 0, 9.7, 1.35, 0.14, 1.1, 0.06, BLACK, M.Plastic, DECOR)
	box(m, 0.45, 9.4, 1.35, 0.9, 0.12, 0.06, BLACK, M.Plastic, DECOR)
	local window = box(m, 0, 4.6, 1.15, 2, 5.4, 0.12, Color3.fromRGB(210, 235, 245), M.Glass, DECOR)
	window.Transparency = 0.6
	Craft.disc(m, Vector3.new(0, 3.4, 1.0), 1.4, L.Brass, M.Metal, DECOR)
	box(m, 0, 5, 1.0, 0.1, 3.4, 0.06, L.Brass, M.Metal, DECOR)
	return finish(m, parent, cframe)
end

return Props
