-- The jumpscare when a shark eats YOU. The server sends it to the victim only (Remotes "Jumpscare"); everyone
-- else just sees the shark leap, so the scare is not spoiled and not repeated at other people.
--
-- It is built in code, no uploaded art: a clockwork shark's face in a ViewportFrame that rushes at the
-- camera with its jaws opening, one red flash (never a strobe), the screen shaking, then the jaws SNAP shut
-- and the screen cuts to black. It lasts Config.Jumpscare.seconds, over the top of your death (the server kills you the moment you are eaten).
-- The sting is Config.Sounds.JumpscareSting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Audio = require(script.Parent.Audio)

local FELT = Color3.fromRGB(128, 128, 136)
local PLYWOOD = Color3.fromRGB(200, 166, 116)
local TEETH = Color3.fromRGB(250, 248, 240)

local MAX_OPEN = math.rad(58) -- how far the lower jaw swings down
local START_DISTANCE = 60 -- the camera starts this far from the face and rushes in
local END_DISTANCE = 6

local Jumpscare = {}

local function block(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	if shape then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

-- The face looks down +Z, toward the camera. Returns a function that opens the jaw (0 shut, 1 wide).
local function buildFace(parent: Instance): (number) -> ()
	block(parent, CFrame.new(0, 0, 0), Vector3.new(12, 8.5, 9), FELT, Enum.Material.Fabric)
	block(parent, CFrame.new(0, 1.4, 5.2), Vector3.new(9.4, 2.2, 7), PLYWOOD, Enum.Material.Wood) -- upper jaw
	block(parent, CFrame.new(0, -0.6, 3.2), Vector3.new(8.4, 4.4, 6), Color3.fromRGB(12, 6, 8), Enum.Material.SmoothPlastic) -- the dark mouth
	for _, side in { -1, 1 } do
		block(parent, CFrame.new(side * 5.2, 2.8, 3.4), Vector3.one * 2.6, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, Enum.PartType.Ball) -- eye
		block(parent, CFrame.new(side * 5.7, 2.8, 4.5), Vector3.one * 1.3, Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, Enum.PartType.Ball) -- button pupil
		block(parent, CFrame.new(side * 6.1, -0.5, 0.4), Vector3.new(0.5, 2.6, 2.6), Color3.fromRGB(250, 200, 60), Enum.Material.Neon, Enum.PartType.Cylinder) -- a glowing gear
	end
	for i = 0, 6 do
		block(parent, CFrame.new(-3.6 + i * 1.2, 0.2, 7.6), Vector3.new(0.8, 1.7, 0.8), TEETH, Enum.Material.Fabric) -- upper teeth
	end

	local hinge = CFrame.new(0, -2.2, 0.6)
	local lower = block(parent, hinge, Vector3.new(9.4, 1.6, 7), PLYWOOD, Enum.Material.Wood)
	local lowerTeeth = {}
	for i = 0, 6 do
		table.insert(lowerTeeth, block(parent, hinge, Vector3.new(0.8, 1.7, 0.8), TEETH, Enum.Material.Fabric))
	end
	return function(open: number)
		local turned = hinge * CFrame.Angles(open * MAX_OPEN, 0, 0)
		lower.CFrame = turned * CFrame.new(0, -0.4, 3.4)
		for i, tooth in lowerTeeth do
			tooth.CFrame = turned * CFrame.new(-3.6 + (i - 1) * 1.2, 0.9, 6.6)
		end
	end
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

function Jumpscare.play(seconds: number?)
	local duration = seconds or Config.Jumpscare.seconds
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	if playerGui:FindFirstChild("Jumpscare") then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "Jumpscare"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = playerGui

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(8, 22, 34) -- dark, like looking up from under the water
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	-- A little bigger than the screen, so shaking it never shows an edge.
	local viewport = Instance.new("ViewportFrame")
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.fromScale(0.5, 0.5)
	viewport.Size = UDim2.fromScale(1.08, 1.08)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(150, 150, 160)
	viewport.LightColor = Color3.fromRGB(255, 232, 214)
	viewport.LightDirection = Vector3.new(-0.3, -0.6, -1)
	viewport.Parent = backdrop

	local camera = Instance.new("Camera")
	camera.FieldOfView = 70
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local setJaw = buildFace(viewport)

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(190, 10, 10)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = gui

	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.BorderSizePixel = 0
	black.ZIndex = 6
	black.Parent = gui

	local rushEnd = duration * 0.28 -- when the face arrives
	local snapAt = duration * 0.72 -- when the jaws shut
	local cutAt = duration * 0.78 -- when it goes black
	local started = os.clock()
	local stung = false
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= duration or not gui.Parent then
			connection:Disconnect()
			gui:Destroy()
			return
		end

		-- The sting hits the instant the face arrives (it peaks in its first tenth of a second).
		if not stung and t >= rushEnd * 0.9 then
			stung = true
			Audio.play("JumpscareSting", nil, "Interface")
		end

		-- Rush in, jaws opening; then hold, shaking; then SNAP.
		local distance, open
		if t < rushEnd then
			local u = t / rushEnd
			distance = START_DISTANCE + (END_DISTANCE - START_DISTANCE) * u ^ 2.2
			open = 0.25 + 0.75 * smooth(u)
		elseif t < snapAt then
			distance = END_DISTANCE - 1.2 * (t - rushEnd) / (snapAt - rushEnd)
			open = 1
		else
			distance = END_DISTANCE - 1.2
			open = math.max(0, 1 - (t - snapAt) / 0.07) -- CLACK
		end
		setJaw(open)
		camera.FieldOfView = 70 + 18 * math.clamp(t / rushEnd, 0, 1)
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.6, 3 + distance), Vector3.new(0, -0.4, 3))

		-- Shake: strong the moment it arrives, dying away.
		local shake = if t >= rushEnd * 0.9 then 14 * math.exp(-(t - rushEnd) * 3.2) else 2
		viewport.Position = UDim2.new(0.5, math.random(-100, 100) / 100 * shake, 0.5, math.random(-100, 100) / 100 * shake)

		-- One red flash as it arrives (not a strobe), then a cut to black after the bite.
		if t >= rushEnd * 0.9 then
			flash.BackgroundTransparency = math.clamp(0.35 + (t - rushEnd * 0.9) / 0.4, 0.35, 1)
		end
		if t >= cutAt then
			black.BackgroundTransparency = math.clamp(1 - (t - cutAt) / 0.1, 0, 1)
		end
	end)
end

return Jumpscare
