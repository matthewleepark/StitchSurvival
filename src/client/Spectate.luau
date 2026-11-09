-- Spectator mode. When a round is on and you're not in it (you got popped, or you were in the lobby), a
-- SPECTATE button appears at the bottom of the screen. Press it to watch the players still in the round:
-- the arrows (or Left / Right, or the gamepad shoulder buttons) switch who you watch, EXIT goes back to your
-- own doll. If the person you're watching gets popped, it moves on to someone else, and it stops by
-- itself when the round ends or you're pulled into a new one.
--
-- Who's in the round is the "InRound" attribute the server puts on each player. Watching is just the camera
-- following them; the server also streams the world around them to you (server/Spectate.luau).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TitleScreen = require(script.Parent.TitleScreen)

local Colors = Config.Colors
local FONT = Enum.Font.FredokaOne
local player = Players.LocalPlayer

local Spectate = {}

local remote: RemoteEvent
local openButton: TextButton
local bar: Frame
local nameLabel: TextLabel
local watching: Player? = nil

local function new(className: string, props, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function style(instance: GuiObject, radius: number, stroke: number)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, instance)
	new("UIStroke", { Thickness = stroke, Color = Colors.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, instance)
end

-- Everyone who can be watched right now, in a steady order.
local function targets(): { Player }
	local list = {}
	for _, other in Players:GetPlayers() do
		local humanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
		if other ~= player and other:GetAttribute("InRound") and humanoid and humanoid.Health > 0 then
			table.insert(list, other)
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

local function roundOn(): boolean
	local phase = ReplicatedStorage:GetAttribute("Phase")
	return phase == "Countdown" or phase == "Playing"
end

local function ownSubject()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		workspace.CurrentCamera.CameraSubject = humanoid
	end
end

local function stop()
	if watching then
		watching = nil
		remote:FireServer(nil)
		ContextActionService:UnbindAction("SpectateNext")
		ContextActionService:UnbindAction("SpectatePrevious")
	end
	bar.Visible = false
	ownSubject()
end

local function watch(target: Player)
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	watching = target
	workspace.CurrentCamera.CameraSubject = humanoid
	nameLabel.Text = `\u{1F441} {target.DisplayName}`
	nameLabel.TextColor3 = target:GetAttribute("Color") or Colors.Ink
	remote:FireServer(target)
	bar.Visible = true
	openButton.Visible = false
end

-- Moves to the next (step = 1) or previous (-1) player in the round.
local function cycle(step: number)
	local list = targets()
	if #list == 0 then
		stop()
		return
	end
	local index = watching and table.find(list, watching) or 0
	local nextIndex = (index - 1 + step) % #list + 1
	if index == 0 then
		nextIndex = 1
	end
	watch(list[nextIndex])
end

local function start()
	cycle(1)
	if watching then
		local function bind(name: string, step: number, ...)
			ContextActionService:BindAction(name, function(_, state)
				if state == Enum.UserInputState.Begin then
					cycle(step)
				end
				return Enum.ContextActionResult.Sink
			end, false, ...)
		end
		bind("SpectateNext", 1, Enum.KeyCode.Right, Enum.KeyCode.ButtonR1)
		bind("SpectatePrevious", -1, Enum.KeyCode.Left, Enum.KeyCode.ButtonL1)
	end
end

local function arrowButton(text: string, position: UDim2, onClick: () -> ()): TextButton
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = position,
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = Colors.Cardboard,
		Font = FONT,
		TextSize = 26,
		TextColor3 = Colors.Ink,
		Text = text,
		AutoButtonColor = false,
	}, bar)
	style(button, 12, 2)
	TitleScreen.wireButton(button)
	button.Activated:Connect(onClick)
	return button
end

function Spectate.start()
	remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Spectate")
	local gui = new("ScreenGui", { Name = "Spectate", ResetOnSpawn = false, DisplayOrder = 24 }, player:WaitForChild("PlayerGui"))

	openButton = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(200, 50),
		BackgroundColor3 = Color3.fromRGB(70, 120, 200),
		Font = FONT,
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "\u{1F441} SPECTATE",
		AutoButtonColor = false,
		Visible = false,
	}, gui)
	style(openButton, 14, 3)
	TitleScreen.wireButton(openButton)
	openButton.Activated:Connect(start)

	bar = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(400, 64),
		BackgroundColor3 = Colors.Paper,
		Visible = false,
	}, gui)
	style(bar, 14, 3)
	arrowButton("\u{25C0}", UDim2.new(0, 8, 0.5, 0), function()
		cycle(-1)
	end)
	nameLabel = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, -30, 0.5, 0),
		Size = UDim2.new(1, -200, 0, 40),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = Colors.Ink,
		Text = "",
	}, bar)
	arrowButton("\u{25B6}", UDim2.new(1, -140, 0.5, 0), function()
		cycle(1)
	end)
	local exit = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(76, 48),
		BackgroundColor3 = Colors.Felt,
		Font = FONT,
		TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "EXIT",
		AutoButtonColor = false,
	}, bar)
	style(exit, 12, 2)
	TitleScreen.wireButton(exit)
	exit.Activated:Connect(stop)

	-- Your own doll respawned while you were watching: keep watching (Roblox points the camera back at you).
	player.CharacterAdded:Connect(function(character)
		if watching then
			local humanoid = character:WaitForChild("Humanoid", 5)
			task.wait()
			if watching and humanoid then
				local target = watching
				watch(target)
			end
		end
	end)

	-- Keep everything in step a few times a second: show the button when there's someone to watch, move on
	-- when the person you're watching is out, stop when the round is over or you're in it yourself.
	task.spawn(function()
		while true do
			local can = roundOn() and not player:GetAttribute("InRound") and #targets() > 0
			if watching then
				if not can then
					stop()
				elseif not table.find(targets(), watching) then
					cycle(1)
				end
			end
			openButton.Visible = can and watching == nil
			task.wait(0.25)
		end
	end)
end

return Spectate
