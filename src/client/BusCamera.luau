-- While you're sitting in a bus seat (a room queue), the camera locks into first person so you look
-- down the aisle at the windshield. Jumping off the bus puts the normal third-person camera back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local BusCamera = {}

local function onBus(on: boolean)
	if on then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		-- Pull the camera back out behind the doll, then let you zoom freely again.
		player.CameraMinZoomDistance = 10
		task.wait()
		player.CameraMinZoomDistance = Config.Camera.minZoom
	end
end

local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local wasOnBus = false
	humanoid.Seated:Connect(function(active, seat)
		local isBus = active and seat ~= nil and seat.Name == "WaitSeat"
		if isBus ~= wasOnBus then
			wasOnBus = isBus
			task.spawn(onBus, isBus)
		end
	end)
end

function BusCamera.start()
	player.CharacterAdded:Connect(function(character)
		player.CameraMode = Enum.CameraMode.Classic
		watch(character)
	end)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

return BusCamera
