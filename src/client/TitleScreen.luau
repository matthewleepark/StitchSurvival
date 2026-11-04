-- Main menu shown when you join: a cardboard card with a stitched border, a stamped title,
-- and PLAY / HOW TO PLAY buttons. Menu music and tape hiss play underneath. Buttons pop when
-- you hover them and clack like a View-Master when you click.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Audio = require(script.Parent.Audio)

local Colors = Config.Colors
local FONT = Enum.Font.FredokaOne
local player = Players.LocalPlayer

local TitleScreen = {}

local function new(className: string, props, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function round(parent: Instance, radius: number)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

-- Hover pop + click clack + a little squash, used for every menu button.
function TitleScreen.wireButton(button: GuiButton)
	local scale = button:FindFirstChildOfClass("UIScale") or new("UIScale", {}, button)
	button.MouseEnter:Connect(function()
		Audio.play("ButtonHover", nil, "Interface")
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		Audio.play("ButtonClick", nil, "Interface")
		scale.Scale = 0.92
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
end

local function button(parent: Instance, text: string, color: Color3, position: UDim2): TextButton
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(260, 64),
		BackgroundColor3 = color,
		Font = FONT,
		TextSize = 32,
		TextColor3 = Colors.Paper,
		Text = text,
		AutoButtonColor = false,
	}, parent)
	round(b, 14)
	new("UIStroke", { Thickness = 3, Color = Colors.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	TitleScreen.wireButton(b)
	return b
end

-- Dashed "stitches" around the inside edge of a frame.
local function stitchBorder(parent: Frame, count: number)
	for i = 0, count - 1 do
		local t = (i + 0.5) / count
		for _, y in { 0.035, 0.965 } do
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(t, y), Size = UDim2.new(0.5 / count, 0, 0, 4), BackgroundColor3 = Colors.Paper, BorderSizePixel = 0 }, parent)
		end
	end
	local sideCount = math.floor(count * 0.6)
	for i = 0, sideCount - 1 do
		local t = 0.06 + (i + 0.5) / sideCount * 0.88
		for _, x in { 0.02, 0.98 } do
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, t), Size = UDim2.new(0, 4, 0.4 / sideCount, 0), BackgroundColor3 = Colors.Paper, BorderSizePixel = 0 }, parent)
		end
	end
end

local HOW_TO_PLAY = table.concat({
	"W A S D  -  walk around",
	"Right mouse (hold and drag)  -  turn the camera.  Mouse wheel  -  zoom",
	"Space  -  jump (and swim up)",
	"E (hold)  -  grab walls, rafts and blocks. Jump to let go and launch off.",
	"",
	"BOMB HOTEL: every 15 seconds a bomb drops somewhere in the hotel. Follow the",
	"ticking to find it, and get clear before it blows the floors apart!",
	"",
	"SHARK SURVIVAL: hop between foam rafts on the paper ocean. The clockwork shark",
	"smashes rafts and pops anyone it catches. Underwater, watch your air.",
	"",
	"Grab score bubbles for points. Survive to earn Stickers,",
	"then roll for passives at the passive machine in the lobby.",
}, "\n")

function TitleScreen.show(onPlay: () -> ())
	local gui = new("ScreenGui", { Name = "TitleScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 50 }, player:WaitForChild("PlayerGui"))
	local backdrop = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(70, 50, 40), BackgroundTransparency = 0.15, BorderSizePixel = 0 }, gui)

	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.75),
		BackgroundColor3 = Colors.Cardboard,
	}, backdrop)
	round(card, 24)
	new("UIStroke", { Thickness = 5, Color = Colors.Ink }, card)
	new("UISizeConstraint", { MaxSize = Vector2.new(900, 620) }, card)
	stitchBorder(card, 28)

	local title = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.28),
		Size = UDim2.fromScale(0.9, 0.24),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		Text = "STITCH SURVIVAL",
		TextColor3 = Colors.Felt,
		Rotation = -3,
	}, card)
	new("UIStroke", { Thickness = 5, Color = Colors.Paper }, title)

	new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.8, 0.07),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		Text = "a handmade survival game",
		TextColor3 = Colors.Ink,
	}, card)

	local play = button(card, "PLAY", Colors.Felt, UDim2.fromScale(0.5, 0.65))
	local how = button(card, "HOW TO PLAY", Color3.fromRGB(80, 140, 200), UDim2.fromScale(0.5, 0.82))

	local helpPanel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.86),
		BackgroundColor3 = Colors.Paper,
		Visible = false,
		ZIndex = 5,
	}, card)
	round(helpPanel, 18)
	new("UIStroke", { Thickness = 3, Color = Colors.Ink }, helpPanel)
	new("TextLabel", {
		Position = UDim2.fromScale(0.05, 0.04),
		Size = UDim2.fromScale(0.9, 0.78),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Colors.Ink,
		Text = HOW_TO_PLAY,
		ZIndex = 6,
	}, helpPanel)
	local back = button(helpPanel, "BACK", Colors.Felt, UDim2.fromScale(0.5, 0.9))
	back.ZIndex = 6

	how.Activated:Connect(function()
		helpPanel.Visible = true
	end)
	back.Activated:Connect(function()
		helpPanel.Visible = false
	end)

	Audio.startMenu()

	play.Activated:Connect(function()
		play.Active = false
		-- Slide the card away and fade the backdrop.
		TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, -0.6) }):Play()
		local fade = TweenService:Create(backdrop, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		fade.Completed:Connect(function()
			gui:Destroy()
		end)
		fade:Play()
		onPlay()
	end)
end

return TitleScreen
