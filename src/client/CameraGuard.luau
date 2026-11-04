-- Keeps the normal Roblox camera honest:
--   * limits how far you can zoom out (Config.Camera.maxZoom), and
--   * stops the camera from slipping through walls. Every frame, right after Roblox moves the camera,
--     it sweeps a small ball from your head to the camera; if it hits a wall, the camera is pulled in
--     to just in front of it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local CameraGuard = {}

local PROBE_RADIUS = 0.6

function CameraGuard.start()
	local settings = Config.Camera
	player.CameraMinZoomDistance = settings.minZoom
	player.CameraMaxZoomDistance = settings.maxZoom

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	RunService:BindToRenderStep("CameraGuard", Enum.RenderPriority.Camera.Value + 2, function()
		local camera = workspace.CurrentCamera
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		if not head or camera.CameraType ~= Enum.CameraType.Custom then
			return
		end

		local focus = head.Position
		local toCamera = camera.CFrame.Position - focus
		local distance = toCamera.Magnitude
		if distance < 0.5 then
			return -- first person or right up close
		end

		params.FilterDescendantsInstances = { character }
		local hit = workspace:Spherecast(focus, PROBE_RADIUS, toCamera, params)
		if hit and hit.Instance.CanCollide then
			local safe = math.max(0.5, hit.Distance - settings.wallGap)
			if safe < distance then
				local direction = toCamera.Unit
				camera.CFrame = camera.CFrame.Rotation + focus + direction * safe
			end
		end
	end)
end

return CameraGuard
