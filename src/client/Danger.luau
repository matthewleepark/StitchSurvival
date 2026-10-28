-- Low-health warning. Under 50% health a heavy heartbeat (thump-thump) pounds in both ears,
-- getting faster and more distorted the lower you go, and the music is pushed way down.
-- The screen edges pulse red in time with it. Taking any hit also flashes the edges.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Audio = require(script.Parent.Audio)

local player = Players.LocalPlayer

local Danger = {}

local edges: { Frame } = {}

local function buildVignette()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Danger"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Four red edges that fade toward the middle of the screen.
	local layout = {
		{ position = UDim2.fromScale(0, 0), size = UDim2.fromScale(1, 0.22), rotation = 90 },
		{ position = UDim2.fromScale(0, 0.78), size = UDim2.fromScale(1, 0.22), rotation = -90 },
		{ position = UDim2.fromScale(0, 0), size = UDim2.fromScale(0.16, 1), rotation = 0 },
		{ position = UDim2.fromScale(0.84, 0), size = UDim2.fromScale(0.16, 1), rotation = 180 },
	}
	for _, info in layout do
		local edge = Instance.new("Frame")
		edge.Position = info.position
		edge.Size = info.size
		edge.BorderSizePixel = 0
		edge.BackgroundColor3 = Color3.fromRGB(200, 20, 30)
		edge.BackgroundTransparency = 1
		edge.Parent = gui

		local gradient = Instance.new("UIGradient")
		gradient.Rotation = info.rotation
		gradient.Transparency = NumberSequence.new(0, 1)
		gradient.Parent = edge
		table.insert(edges, edge)
	end
end

local function setEdges(transparency: number, seconds: number)
	for _, edge in edges do
		TweenService:Create(edge, TweenInfo.new(seconds), { BackgroundTransparency = transparency }):Play()
	end
end

function Danger.flash()
	setEdges(0.35, 0.05)
	task.delay(0.1, setEdges, 1, 0.4)
end

local function thump(level: number)
	local sound = Audio.play("Heartbeat", nil, "Interface", 1 + level * 0.3)
	if sound then
		local distortion = Instance.new("DistortionSoundEffect")
		distortion.Level = 0.15 + level * 0.6
		distortion.Parent = sound
	end
end

function Danger.start()
	buildVignette()

	local function watch(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		local last = humanoid.Health
		humanoid.HealthChanged:Connect(function(health)
			if health < last - 0.5 and health > 0 then
				Danger.flash()
			end
			last = health
		end)
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end

	-- Heartbeat loop.
	task.spawn(function()
		while true do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local ratio = if humanoid and humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
			if humanoid and humanoid.Health > 0 and ratio < 0.5 then
				local level = (0.5 - ratio) / 0.5 -- 0 at half health, 1 at almost dead
				Audio.setFactor("Music", "danger", 0.15, 0.3)

				-- thump-thump, with the screen edges pulsing along.
				thump(level)
				setEdges(0.45 - level * 0.25, 0.05)
				task.wait(0.18)
				thump(level)
				setEdges(1, 0.35)
				task.wait(math.max(0.25, 0.85 - level * 0.55))
			else
				Audio.setFactor("Music", "danger", 1, 0.8)
				task.wait(0.25)
			end
		end
	end)
end

return Danger
