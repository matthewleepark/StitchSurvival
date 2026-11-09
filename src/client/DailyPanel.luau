-- The DAILY button and panel: today's challenges (server/Daily.luau), how far along you are, and a CLAIM
-- button on each one you've finished. The server sends the list in the "Daily" attribute (JSON) and checks
-- every claim. A red dot on the button means there's something to claim.
--
-- Effects handled here: DailyReady {id} (a challenge was just finished), DailyClaimed {id, reward}.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Audio = require(script.Parent.Audio)
local Menu = require(script.Parent.Menu)
local TitleScreen = require(script.Parent.TitleScreen)

local Colors = Config.Colors
local FONT = Enum.Font.FredokaOne
local GREEN = Color3.fromRGB(80, 160, 90)
local DAY = 86400
local player = Players.LocalPlayer

local DailyPanel = {}

local openButton: TextButton
local card: Frame
local list: Frame
local resetLabel: TextLabel
local claimRemote: RemoteEvent

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

local function read(): { any }
	local raw = player:GetAttribute("Daily")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and type(data) == "table" and type(data.items) == "table" then data.items else {}
end

-- "New challenges in 5h 12m", counted to midnight UTC.
local function updateReset()
	local left = DAY - os.time() % DAY
	resetLabel.Text = `New challenges in {left // 3600}h {(left % 3600) // 60}m`
end

local function render()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local items = read()
	local claimable = false
	for i, item in items do
		local done = item.progress >= item.goal
		claimable = claimable or (done and not item.claimed)
		local row = new("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 78),
			BackgroundColor3 = if item.claimed then Color3.fromRGB(226, 236, 214) else Color3.new(1, 1, 1),
		}, list)
		style(row, 10, 2)
		new("TextLabel", {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -146, 0, 28), -- stops short of the button on the right
			BackgroundTransparency = 1,
			Font = FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Colors.Ink,
			Text = item.text,
		}, row)
		-- Progress bar with "3 / 5" on it.
		local bar = new("Frame", {
			Position = UDim2.fromOffset(12, 42),
			Size = UDim2.new(1, -136, 0, 24),
			BackgroundColor3 = Color3.fromRGB(230, 222, 204),
		}, row)
		style(bar, 8, 2)
		local fill = new("Frame", {
			Size = UDim2.fromScale(math.clamp(item.progress / item.goal, 0, 1), 1),
			BackgroundColor3 = if done then GREEN else Colors.Gold,
			BorderSizePixel = 0,
		}, bar)
		new("UICorner", { CornerRadius = UDim.new(0, 8) }, fill)
		new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = FONT,
			TextSize = 16,
			TextColor3 = Colors.Ink,
			Text = `{item.progress} / {item.goal}`,
			ZIndex = 2,
		}, bar)
		-- Reward / claim button.
		local button = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(110, 54),
			BackgroundColor3 = if item.claimed then Color3.fromRGB(170, 170, 160) elseif done then GREEN else Colors.Cardboard,
			Font = FONT,
			TextSize = 18,
			TextWrapped = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = if item.claimed then "CLAIMED \u{2714}" elseif done then `CLAIM\n+{item.reward}` else `+{item.reward}\nStickers`,
			AutoButtonColor = false,
			Active = done and not item.claimed,
		}, row)
		style(button, 10, 2)
		if done and not item.claimed then
			TitleScreen.wireButton(button)
			button.Activated:Connect(function()
				button.Text = "..."
				claimRemote:FireServer(item.id)
			end)
		end
	end
	if #items == 0 then
		new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 }, list)
		resetLabel.Text = "Loading your challenges..."
	else
		updateReset()
	end
	Menu.setBadge(openButton, claimable)
end

function DailyPanel.handle(kind: string, data)
	if kind == "DailyReady" then
		-- A wiggle on the button so you notice.
		local scale = openButton:FindFirstChildOfClass("UIScale") or new("UIScale", {}, openButton)
		scale.Scale = 1.25
		TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
	elseif kind == "DailyClaimed" then
		Audio.play("Fanfare", nil, "Interface")
	end
end

function DailyPanel.start()
	claimRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClaimDaily")
	local gui = new("ScreenGui", { Name = "Daily", ResetOnSpawn = false, DisplayOrder = 26 }, player:WaitForChild("PlayerGui"))

	card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 370),
		BackgroundColor3 = Colors.Paper,
		Visible = false,
	}, gui)
	style(card, 16, 4)
	new("UISizeConstraint", { MaxSize = Vector2.new(460, 370) }, card)
	card.Size = UDim2.new(0.94, 0, 0.9, 0)
	new("TextLabel", {
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -80, 0, 36),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Felt,
		Text = "\u{1F4C5} DAILY CHALLENGES",
	}, card)
	resetLabel = new("TextLabel", {
		Position = UDim2.fromOffset(20, 46),
		Size = UDim2.new(1, -40, 0, 20),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(120, 100, 84),
		Text = "",
	}, card)
	local close = new("TextButton", {
		Position = UDim2.new(1, -52, 0, 10),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Colors.Felt,
		Font = FONT,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "X",
		AutoButtonColor = false,
	}, card)
	style(close, 20, 2)
	TitleScreen.wireButton(close)
	close.Activated:Connect(function()
		card.Visible = false
	end)
	list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 74),
		Size = UDim2.new(1, -32, 1, -88),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, card)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8) }, list)

	openButton = Menu.add(2, "\u{1F4C5} DAILY", Color3.fromRGB(220, 140, 40), function()
		card.Visible = not card.Visible
		if card.Visible then
			updateReset()
			render()
		end
	end)

	player:GetAttributeChangedSignal("Daily"):Connect(render)
	render()
	task.spawn(function()
		while true do
			if card.Visible then
				updateReset()
			end
			task.wait(20)
		end
	end)
end

return DailyPanel
