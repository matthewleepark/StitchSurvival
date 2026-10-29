-- Screen shake for explosions, splashes and big landings. The camera itself is the normal
-- Roblox third-person camera; this just nudges it by wobbling the character's camera offset.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraShake = {}

local shakeAmount = 0

function CameraShake.shake(amount: number)
	shakeAmount = math.max(shakeAmount, amount)
end

function CameraShake.start()
	local player = Players.LocalPlayer
	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		if shakeAmount > 0.01 then
			humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * shakeAmount
			shakeAmount = math.max(0, shakeAmount - dt * 4)
		elseif humanoid.CameraOffset ~= Vector3.zero then
			humanoid.CameraOffset = Vector3.zero
		end
	end)
end

return CameraShake
