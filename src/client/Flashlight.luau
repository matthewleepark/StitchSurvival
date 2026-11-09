-- A flashlight for the dark. It points wherever the camera points, so you can sweep corridors while
-- you walk. It is purely visual (a light only you see), so there is nothing for the server to check.
-- Toggle with L, D-pad up on a gamepad, or the "Light" button on mobile (keys in Config.Flashlight).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local Flashlight = {}

local holder: Part? = nil
local spot: SpotLight? = nil
local enabled = true

local function build()
	local def = Config.Flashlight

	local part = Instance.new("Part")
	part.Name = "Flashlight"
	part.Size = Vector3.one * 0.2
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front -- a part's front is -Z, the way the camera looks
	light.Range = def.range
	light.Angle = def.angle
	light.Brightness = def.brightness
	light.Color = def.color
	light.Shadows = def.shadows
	light.Parent = part

	part.Parent = workspace
	holder, spot = part, light
end

-- Follows the camera's direction, shining out of the little flashlight on the doll's right shoulder
-- (or from beside the head if that isn't there yet). The lens glows while the light is on.
local function follow()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not holder or not spot or not camera then
		return
	end

	local alive = head ~= nil and humanoid ~= nil and humanoid.Health > 0
	spot.Enabled = enabled and alive
	if not alive or not head then
		return
	end

	local look = camera.CFrame.Rotation
	local lens = character and character:FindFirstChild("ShoulderLampLens", true) :: BasePart?
	if lens then
		lens.Material = if enabled then Enum.Material.Neon else Enum.Material.SmoothPlastic
		holder.CFrame = look + lens.Position + look.LookVector * 0.3
	else
		holder.CFrame = look + head.Position + look.RightVector * 0.5 + look.UpVector * 0.1
	end
end

local function toggle(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		enabled = not enabled
	end
end

function Flashlight.start()
	build()
	RunService.RenderStepped:Connect(follow)

	-- L / D-pad up (Config.Flashlight): F and L1 belong to the Killer Hotel doors.
	ContextActionService:BindAction("Flashlight", toggle, true, Config.Flashlight.key, Config.Flashlight.gamepadKey)
	ContextActionService:SetTitle("Flashlight", "Light")
	ContextActionService:SetPosition("Flashlight", UDim2.new(0.62, 0, 0.78, 0))
end

return Flashlight
