-- Building blocks for the handmade scrapbook look. Every stage is assembled from these:
-- cardboard panels with stitched edges, felt bunting, stickers, signs with bulbs, foam blocks.
-- Flat decorations (signs, stickers, stitches) face +Z, the "front" of a wall facing into a stage;
-- rotate the CFrame you pass in to put them on other walls.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(script.Parent.Util)

local Colors = Config.Colors

local Craft = {}

Craft.Material = {
	Cardboard = Util.material("Cardboard", Enum.Material.Wood),
	Foam = Util.material("Plaster", Enum.Material.SmoothPlastic),
	Felt = Enum.Material.Fabric,
	Carpet = Util.material("Carpet", Enum.Material.Fabric),
	Wood = Enum.Material.Wood,
	Plastic = Enum.Material.SmoothPlastic,
	Glass = Enum.Material.Glass,
	Neon = Enum.Material.Neon,
	Metal = Enum.Material.Metal,
}

-- Background decoration shouldn't trip players up or block raycasts.
Craft.DECOR = { CanCollide = false, CanQuery = false, CanTouch = false }

local FACE_CAMERA = CFrame.Angles(0, math.rad(90), 0) -- points a cylinder's round face at the camera
local VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder upright

local function apply(instance: Instance, props)
	if props then
		for key, value in props do
			(instance :: any)[key] = value
		end
	end
end

function Craft.tag(instance: Instance, tag: string)
	CollectionService:AddTag(instance, tag)
end

function Craft.block(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material?, props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Craft.Material.Cardboard
	apply(part, props)
	part.Parent = parent
	return part
end

-- A round flat shape facing the camera (stickers, clouds, the sun, button eyes).
function Craft.disc(parent: Instance, position: Vector3, diameter: number, color: Color3, material: Enum.Material?, props): Part
	local part = Craft.block(parent, CFrame.new(position) * FACE_CAMERA, Vector3.new(0.3, diameter, diameter), color, material or Craft.Material.Felt, props)
	part.Shape = Enum.PartType.Cylinder
	return part
end

function Craft.ball(parent: Instance, position: Vector3, diameter: number, color: Color3, material: Enum.Material?, props): Part
	local part = Craft.block(parent, CFrame.new(position), Vector3.one * diameter, color, material or Craft.Material.Plastic, props)
	part.Shape = Enum.PartType.Ball
	return part
end

-- axis is "X" (left-right), "Y" (up-down) or "Z" (toward the camera).
function Craft.cylinder(parent: Instance, center: Vector3, length: number, diameter: number, axis: string, color: Color3, material: Enum.Material?, props): Part
	local rotation = if axis == "Y" then VERTICAL elseif axis == "Z" then FACE_CAMERA else CFrame.identity
	local part = Craft.block(parent, CFrame.new(center) * rotation, Vector3.new(length, diameter, diameter), color, material, props)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- A square turned 45 degrees: used for bunting flags, fish tails and fins.
function Craft.diamond(parent: Instance, position: Vector3, size: number, color: Color3, material: Enum.Material?, props): Part
	return Craft.block(parent, CFrame.new(position) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(size, size, 0.3), color, material or Craft.Material.Felt, props)
end

-- Dashed "sewn" line around a rectangle. `front` is the center of the surface to sew onto.
function Craft.stitches(parent: Instance, front: Vector3, width: number, height: number, color: Color3?, spacing: number?)
	local gap = spacing or 1.6
	local inset = 0.6
	local stitchColor = color or Colors.Paper
	local dash = gap * 0.55

	local halfW = width / 2 - inset
	local halfH = height / 2 - inset
	local position = front + Vector3.new(0, 0, 0.06)

	local function sew(fromX, fromY, toX, toY, horizontal)
		local length = if horizontal then math.abs(toX - fromX) else math.abs(toY - fromY)
		local count = math.max(1, math.floor(length / gap))
		for i = 0, count do
			local t = i / count
			local x = fromX + (toX - fromX) * t
			local y = fromY + (toY - fromY) * t
			local size = if horizontal then Vector3.new(dash, 0.16, 0.08) else Vector3.new(0.16, dash, 0.08)
			Craft.block(parent, CFrame.new(position + Vector3.new(x, y, 0)), size, stitchColor, Craft.Material.Plastic, Craft.DECOR)
		end
	end

	sew(-halfW, halfH, halfW, halfH, true)
	sew(-halfW, -halfH, halfW, -halfH, true)
	sew(-halfW, -halfH + gap / 2, -halfW, halfH - gap / 2, false)
	sew(halfW, -halfH + gap / 2, halfW, halfH - gap / 2, false)
end

-- A flat cardboard/felt panel facing the camera, optionally with a stitched border.
function Craft.panel(parent: Instance, center: Vector3, width: number, height: number, color: Color3, material: Enum.Material?, opts): Part
	opts = opts or {}
	local thickness = opts.thickness or 0.4
	local part = Craft.block(parent, CFrame.new(center), Vector3.new(width, height, thickness), color, material, if opts.collide then nil else Craft.DECOR)
	if opts.stitch then
		Craft.stitches(parent, center + Vector3.new(0, 0, thickness / 2), width, height, opts.stitchColor, opts.stitchSpacing)
	end
	return part
end

-- Text painted on the front of the stage. Returns the invisible part holding it.
function Craft.label(parent: Instance, center: Vector3, width: number, height: number, text: string, color: Color3?, font: Enum.Font?): Part
	local holder = Craft.block(parent, CFrame.new(center), Vector3.new(width, height, 0.05), Color3.new(), nil, Craft.DECOR)
	holder.Transparency = 1

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- Back is the +Z side, toward the camera
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = holder

	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = font or Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.TextColor3 = color or Colors.Ink
	textLabel.Text = text
	textLabel.Parent = gui

	return holder
end

-- Wooden sign with a paper face, stitched edge, and optional ring of blinking bulbs.
function Craft.sign(parent: Instance, center: Vector3, width: number, height: number, text: string, opts)
	opts = opts or {}
	Craft.block(parent, CFrame.new(center), Vector3.new(width, height, 0.8), opts.boardColor or Colors.WoodDark, Craft.Material.Wood, Craft.DECOR)
	local face = center + Vector3.new(0, 0, 0.45)
	Craft.panel(parent, face, width - 1.6, height - 1.6, opts.faceColor or Colors.Paper, Craft.Material.Felt, {
		thickness = 0.1,
		stitch = true,
		stitchColor = opts.stitchColor or Colors.Felt,
	})
	Craft.label(parent, face + Vector3.new(0, 0, 0.12), width - 3.2, height - 3, text, opts.textColor, opts.font)

	if opts.bulbs then
		local spacing = 2.4
		local index = 0
		local function bulb(x, y)
			index += 1
			local light = Craft.ball(parent, center + Vector3.new(x, y, 0.5), 0.7, Colors.Gold, Craft.Material.Neon, Craft.DECOR)
			light:SetAttribute("Phase", index % 2)
			Craft.tag(light, "Bulb")
		end
		local halfW, halfH = width / 2 - 0.4, height / 2 - 0.4
		for x = -halfW, halfW, spacing do
			bulb(x, halfH)
			bulb(x, -halfH)
		end
		for y = -halfH + spacing, halfH - spacing, spacing do
			bulb(-halfW, y)
			bulb(halfW, y)
		end
	end
end

-- A string of felt flags hanging between two points at the same height.
function Craft.bunting(parent: Instance, left: Vector3, right: Vector3, colors: { Color3 }?)
	local flagColors = colors or { Colors.Felt, Colors.Gold, Color3.fromRGB(90, 160, 220), Color3.fromRGB(110, 190, 100) }
	local length = (right - left).Magnitude
	local middle = (left + right) / 2
	Craft.block(parent, CFrame.new(middle), Vector3.new(length, 0.15, 0.15), Colors.Paper, Craft.Material.Plastic, Craft.DECOR)

	local size = 1.6
	local count = math.floor(length / 3)
	for i = 0, count - 1 do
		local x = left.X + 1.5 + i * 3
		local flag = Craft.diamond(parent, Vector3.new(x, left.Y - size * 0.7, left.Z), size, flagColors[i % #flagColors + 1], Craft.Material.Felt, Craft.DECOR)
		flag:SetAttribute("Phase", i)
		Craft.tag(flag, "Flutter")
	end
end

-- A round sticker with a white rim, like the decorations stuck all over LBP levels.
function Craft.sticker(parent: Instance, position: Vector3, diameter: number, color: Color3, text: string?)
	Craft.disc(parent, position, diameter + 0.8, Color3.new(1, 1, 1), Craft.Material.Plastic, Craft.DECOR)
	Craft.disc(parent, position + Vector3.new(0, 0, 0.1), diameter, color, Craft.Material.Plastic, Craft.DECOR)
	if text then
		Craft.label(parent, position + Vector3.new(0, 0, 0.3), diameter * 0.8, diameter * 0.5, text, Color3.new(1, 1, 1))
	end
end

function Craft.window(parent: Instance, center: Vector3, width: number, height: number, glass: Color3?, curtain: Color3?)
	Craft.block(parent, CFrame.new(center), Vector3.new(width + 1.2, height + 1.2, 0.4), Colors.WoodDark, Craft.Material.Wood, Craft.DECOR)
	Craft.block(parent, CFrame.new(center + Vector3.new(0, 0, 0.2)), Vector3.new(width, height, 0.2), glass or Colors.Sky, Craft.Material.Plastic, Craft.DECOR)
	Craft.block(parent, CFrame.new(center + Vector3.new(0, 0, 0.35)), Vector3.new(0.4, height, 0.2), Colors.WoodDark, Craft.Material.Wood, Craft.DECOR)
	Craft.block(parent, CFrame.new(center + Vector3.new(0, 0, 0.35)), Vector3.new(width, 0.4, 0.2), Colors.WoodDark, Craft.Material.Wood, Craft.DECOR)

	local curtainColor = curtain or Colors.Felt
	local curtainWidth = width * 0.3
	for _, side in { -1, 1 } do
		local x = side * (width / 2 - curtainWidth / 2 + 0.3)
		Craft.block(parent, CFrame.new(center + Vector3.new(x, 0.3, 0.55)), Vector3.new(curtainWidth, height + 0.6, 0.2), curtainColor, Craft.Material.Felt, Craft.DECOR)
	end
	Craft.cylinder(parent, center + Vector3.new(0, height / 2 + 0.9, 0.7), width + 2, 0.3, "X", Colors.Gold, Craft.Material.Metal, Craft.DECOR)
end

function Craft.picture(parent: Instance, center: Vector3, width: number, height: number, color: Color3)
	Craft.block(parent, CFrame.new(center), Vector3.new(width + 0.8, height + 0.8, 0.3), Colors.Gold, Craft.Material.Wood, Craft.DECOR)
	Craft.block(parent, CFrame.new(center + Vector3.new(0, 0, 0.15)), Vector3.new(width, height, 0.1), Colors.Paper, Craft.Material.Felt, Craft.DECOR)
	Craft.disc(parent, center + Vector3.new(width * 0.2, height * 0.15, 0.25), height * 0.35, color, Craft.Material.Felt, Craft.DECOR)
	Craft.diamond(parent, center + Vector3.new(-width * 0.15, -height * 0.25, 0.25), height * 0.5, Colors.Seaweed, Craft.Material.Felt, Craft.DECOR)
end

function Craft.lamp(parent: Instance, position: Vector3)
	Craft.block(parent, CFrame.new(position + Vector3.new(0, -0.6, 0)), Vector3.new(0.3, 1.2, 0.6), Colors.WoodDark, Craft.Material.Metal, Craft.DECOR)
	local bulb = Craft.ball(parent, position + Vector3.new(0, 0.4, 0.4), 0.9, Colors.Gold, Craft.Material.Neon, Craft.DECOR)
	local light = Instance.new("PointLight")
	light.Color = Colors.Gold
	light.Range = 10
	light.Brightness = 0.8
	light.Parent = bulb
	Craft.block(parent, CFrame.new(position + Vector3.new(0, 1.1, 0.4)), Vector3.new(1.6, 0.8, 1.2), Colors.Paper, Craft.Material.Felt, Craft.DECOR)
end

-- Polystyrene foam block that bombs can blow apart.
function Craft.foam(parent: Instance, cframe: CFrame, size: Vector3, shade: boolean?): Part
	local block = Craft.block(parent, cframe, size, if shade then Colors.FoamShade else Colors.Foam, Craft.Material.Foam)
	block.Name = "Foam"
	block:SetAttribute("Breakable", true)
	return block
end

-- Invisible walls so players can't wander out of the stage.
function Craft.boundaries(parent: Instance, origin: Vector3, width: number, height: number, depth: number)
	local tall = height + 60
	local props = { Transparency = 1, CanQuery = false, Name = "Boundary" }
	for _, side in { -1, 1 } do
		Craft.block(parent, CFrame.new(origin + Vector3.new(side * (width / 2 + 1), tall / 2 - 10, 0)), Vector3.new(2, tall, depth + 8), Color3.new(), nil, props)
		Craft.block(parent, CFrame.new(origin + Vector3.new(0, tall / 2 - 10, side * (depth / 2 + 0.5))), Vector3.new(width + 4, tall, 1), Color3.new(), nil, props)
	end
end

return Craft
