-- LBP-style depth layers: A/D walks left and right, tapping W/S hops one layer back or forward.
-- Works by taking over the default control script's move step, so jumping, mobile thumbsticks
-- and gamepads all keep working.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stages = require(script.Parent.Stages)

local Layers = {}

local function nearestIndex(localZ: number): number
	local best, bestDistance = 1, math.huge
	for i, z in Config.Layers do
		local distance = math.abs(z - localZ)
		if distance < bestDistance then
			best, bestDistance = i, distance
		end
	end
	return best
end

function Layers.start()
	local player = Players.LocalPlayer
	local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: any)
	local controls = playerModule:GetControls()

	local targetIndex = math.ceil(#Config.Layers / 2)
	local lastStage: Stages.Stage? = nil
	local wasPressing = false

	controls.moveFunction = function(_, moveVector: Vector3, cameraRelative: boolean)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not root then
			return
		end

		local stage = Stages.find(root.Position)
		if not stage then
			player:Move(moveVector, cameraRelative)
			return
		end

		-- Re-pick the layer after teleporting into a new stage.
		local localZ = root.Position.Z - stage.origin.Z
		if stage ~= lastStage or math.abs(Config.Layers[targetIndex] - localZ) > 8 then
			targetIndex = nearestIndex(localZ)
			lastStage = stage
		end

		-- A fresh press of forward/back hops one layer (forward = into the screen).
		local pressing = math.abs(moveVector.Z) > 0.5
		if pressing and not wasPressing then
			local step = if moveVector.Z < 0 then -1 else 1
			targetIndex = math.clamp(targetIndex + step, 1, #Config.Layers)
		end
		wasPressing = pressing

		-- Walk sideways with the input, and glide toward the target layer's depth.
		local offset = Config.Layers[targetIndex] - localZ
		local zMove = if math.abs(offset) > 0.15 then math.clamp(offset * 0.6, -1, 1) else 0
		humanoid:Move(Vector3.new(moveVector.X, 0, zMove), false)
	end
end

return Layers
