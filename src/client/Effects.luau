-- Client-side visual effects. The server just says "a bomb went off here", and this makes it
-- look good: cellophane flames, tissue-paper splashes, felt confetti, floating points, coin rain.
-- Also animates decorations the server tagged (bobbing bubbles, waves, seaweed, bunting, bulbs,
-- flickering fire, the clock pendulum and the egg timer).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Audio = require(script.Parent.Audio)
local StageCamera = require(script.Parent.StageCamera)

local Colors = Config.Colors
local player = Players.LocalPlayer

local Effects = {}

local function tween(instance: Instance, seconds: number, goal, style: Enum.EasingStyle?)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
end

local function effectPart(props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = workspace
	return part
end

-- Small flat pieces that fly out and tumble down (paper, felt, foam).
local function confetti(position: Vector3, colors: { Color3 }, count: number, speed: number, material: Enum.Material?)
	for i = 1, count do
		local piece = effectPart({
			Size = Vector3.new(0.6 + math.random() * 0.5, 0.6 + math.random() * 0.5, 0.08),
			CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			Color = colors[(i % #colors) + 1],
			Material = material or Enum.Material.Fabric,
		})
		piece.Anchored = false
		local angle = math.random() * math.pi * 2
		piece.AssemblyLinearVelocity = Vector3.new(math.cos(angle) * speed, speed * (0.8 + math.random()), math.sin(angle) * speed * 0.3)
		piece.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		Debris:AddItem(piece, 1.6)
	end
end

local handlers = {}

function handlers.Popup(data)
	local holder = effectPart({ Transparency = 1, Size = Vector3.one * 0.2, Position = data.position })
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 50)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = holder

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 30
	label.Text = data.text
	label.TextColor3 = data.color or Colors.Gold
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(1, 1, 1)
	label.Parent = billboard

	tween(billboard, 1, { StudsOffset = Vector3.new(0, 5, 0) })
	tween(label, 1, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(holder, 1.1)
end

function handlers.Pop(data)
	Audio.play("BubblePop", data.position)
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		local spark = effectPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Position = data.position, Material = Enum.Material.Neon, Color = Colors.Bubble })
		tween(spark, 0.35, { Position = data.position + Vector3.new(math.cos(angle) * 2.5, math.sin(angle) * 2.5, 0), Size = Vector3.one * 0.05 })
		Debris:AddItem(spark, 0.4)
	end
end

function handlers.Boom(data)
	-- (The bang itself is played by the server so everyone hears it from the same spot.)
	local position, radius = data.position, data.radius

	-- Bright flash that swells and fades.
	local flash = effectPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Position = position, Material = Enum.Material.Neon, Color = Colors.Gold })
	tween(flash, 0.25, { Size = Vector3.one * radius * 1.6, Transparency = 1 })
	Debris:AddItem(flash, 0.3)
	local ring = effectPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Position = position, Material = Enum.Material.ForceField, Color = Colors.Warning })
	tween(ring, 0.4, { Size = Vector3.one * radius * 2.2, Transparency = 1 })
	Debris:AddItem(ring, 0.45)

	-- Orange cellophane flames that flicker for a moment.
	local flameColors = { Colors.Warning, Colors.Gold, Color3.fromRGB(255, 90, 50) }
	for i = 1, 7 do
		local offset = Vector3.new((math.random() - 0.5) * radius, (math.random() - 0.3) * radius * 0.5, (math.random() - 0.5) * 4)
		local size = 1.5 + math.random() * 2
		local flame = effectPart({
			Size = Vector3.new(size, size, 0.1),
			CFrame = CFrame.new(position + offset) * CFrame.Angles(0, 0, math.rad(45)),
			Material = Enum.Material.Glass,
			Color = flameColors[i % #flameColors + 1],
			Transparency = 0.25,
		})
		task.spawn(function()
			for _ = 1, 8 do
				if not flame.Parent then
					return
				end
				flame.Size = Vector3.new(size, size, 0.1) * (0.7 + math.random() * 0.6)
				task.wait(0.08)
			end
			tween(flame, 0.3, { Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1 })
		end)
		Debris:AddItem(flame, 1.2)
	end

	confetti(position, { Colors.Foam, Colors.FoamShade }, 8, 25, Enum.Material.SmoothPlastic)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local distance = if root then (root.Position - position).Magnitude else 999
	StageCamera.shake(math.clamp(3 - distance / 15, 0.3, 3))
end

function handlers.Knock(data)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and not root.Anchored then
		root.AssemblyLinearVelocity = data.velocity
	end
	StageCamera.shake(1.5)
end

function handlers.Splash(data)
	-- Torn tissue paper flying up out of the water.
	confetti(data.position, { Colors.Sea, Color3.fromRGB(150, 210, 245), Color3.new(1, 1, 1) }, 18, 30, Enum.Material.SmoothPlastic)
	StageCamera.shake(0.8)
end

function handlers.Poof(data)
	confetti(data.position, { data.color or Colors.Felt, Colors.Burlap, Colors.Paper }, 20, 22)
end

function handlers.Teleport(data)
	Audio.play("TeleportPop", data.position)
	confetti(data.position, { data.color or Colors.Gold, Colors.Paper }, 10, 14)
end

function handlers.Squish(data)
	confetti(data.position, { Colors.Burlap, Colors.Foam, Colors.FoamShade }, 16, 18)
	StageCamera.shake(2)
end

-- You survived: silence, a toy-trumpet fanfare right above you, then a rain of plastic tokens.
function handlers.Victory(_data)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	task.delay(0.25, function()
		Audio.play("Fanfare", root.Position + Vector3.new(0, 4, 0), "Interface")
	end)

	local tokenColors = { Colors.Gold, Colors.Felt, Color3.fromRGB(90, 160, 220), Color3.fromRGB(110, 190, 100) }
	task.delay(0.6, function()
		for i = 1, 45 do
			local spot = root.Position + Vector3.new((math.random() - 0.5) * 14, 14 + math.random() * 6, (math.random() - 0.5) * 6)
			local token = effectPart({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.25, 1.2, 1.2),
				CFrame = CFrame.new(spot) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
				Color = tokenColors[i % #tokenColors + 1],
				Material = Enum.Material.SmoothPlastic,
			})
			token.Anchored = false
			token.CanCollide = true
			token.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-12, 12), 0)
			Debris:AddItem(token, 3)
			if i % 3 == 0 then
				Audio.play("CoinClink", nil, "Interface", 0.85 + math.random() * 0.4)
			end
			task.wait(0.05)
		end
	end)
end

-- Tagged decorations -------------------------------------------------------------

local animated: { [string]: { [BasePart]: CFrame } } = {
	Bob = {},
	Wave = {},
	Sway = {},
	Flutter = {},
}
local bulbs: { [BasePart]: boolean } = {}
local lastBlink = -1

-- Parts that rotate around an "Pivot" attribute point (clock pendulum, egg timer hand).
local pendulums: { [BasePart]: CFrame } = {}
local spinners: { [BasePart]: CFrame } = {}
local spinAngles: { [BasePart]: number } = {}
-- Fire flames: remember their starting size so they can flicker around it.
local flames: { [BasePart]: Vector3 } = {}

local function track(tag: string, set)
	local function add(instance: Instance)
		if instance:IsA("BasePart") then
			set[instance] = if tag == "Bulb" then true else instance.CFrame
		end
	end
	for _, instance in CollectionService:GetTagged(tag) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		set[instance :: BasePart] = nil
	end)
end

local function aroundPivot(part: BasePart, base: CFrame, angle: number): CFrame
	local pivot = part:GetAttribute("Pivot")
	if typeof(pivot) ~= "Vector3" then
		return base
	end
	local pivotFrame = CFrame.new(pivot)
	return pivotFrame * CFrame.Angles(0, 0, angle) * pivotFrame:Inverse() * base
end

local function animate(dt: number)
	local t = os.clock()

	for part, base in pendulums do
		part.CFrame = aroundPivot(part, base, math.sin(t * 2.2) * 0.35)
	end
	for part, base in spinners do
		local speed = part:GetAttribute("Speed") or 0
		if speed ~= 0 then
			spinAngles[part] = (spinAngles[part] or 0) - speed * dt
			part.CFrame = aroundPivot(part, base, spinAngles[part])
		end
	end
	for part, size in flames do
		part.Size = size * (0.75 + math.noise(t * 6, part.Position.X) * 0.5 + 0.1)
	end

	for part, base in animated.Bob do
		part.CFrame = base * CFrame.new(0, math.sin(t * 2.5 + base.Position.X) * 0.4, 0)
	end
	for part, base in animated.Wave do
		local phase = part:GetAttribute("Phase") or 0
		part.CFrame = base + Vector3.new(0, math.sin(t * 1.8 + phase) * 0.35, 0)
	end
	for part, base in animated.Sway do
		local phase = part:GetAttribute("Phase") or 0
		local bottom = base * CFrame.new(0, -part.Size.Y / 2, 0)
		part.CFrame = bottom * CFrame.Angles(0, 0, math.sin(t * 1.2 + phase) * 0.15) * CFrame.new(0, part.Size.Y / 2, 0)
	end
	for part, base in animated.Flutter do
		local phase = part:GetAttribute("Phase") or 0
		part.CFrame = base * CFrame.Angles(0, 0, math.sin(t * 3 + phase) * 0.12)
	end

	local blink = math.floor(t * 2) % 2
	if blink == lastBlink then
		return
	end
	lastBlink = blink
	for bulb in bulbs do
		local on = ((bulb:GetAttribute("Phase") or 0) + blink) % 2 == 0
		bulb.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		bulb.Color = if on then Colors.Gold else Color3.fromRGB(150, 120, 60)
	end
end

function Effects.handle(kind: string, data)
	local handler = handlers[kind]
	if handler then
		handler(data)
	end
end

function Effects.start()
	for tag, set in animated do
		track(tag, set)
	end
	track("Bulb", bulbs)
	track("Pendulum", pendulums)
	track("Spin", spinners)

	local function addFlame(instance: Instance)
		if instance:IsA("BasePart") then
			flames[instance] = instance.Size
		end
	end
	for _, instance in CollectionService:GetTagged("Flicker") do
		addFlame(instance)
	end
	CollectionService:GetInstanceAddedSignal("Flicker"):Connect(addFlame)
	CollectionService:GetInstanceRemovedSignal("Flicker"):Connect(function(instance)
		flames[instance :: BasePart] = nil
	end)

	RunService.RenderStepped:Connect(animate)
end

return Effects
