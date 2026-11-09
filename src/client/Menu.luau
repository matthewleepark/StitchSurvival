-- The menu buttons (CODES, DAILY, LOOK...) in one stack, so they never overlap each other or the
-- on-screen controls:
--   * Computer / console: bottom left, growing upward.
--   * Phone / tablet: on the left under the score card (the thumbstick lives at the bottom left and the
--     jump button at the bottom right), and hidden while you're in a round so it doesn't cover the role tag.
-- Other modules add their button with Menu.add(...).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local TitleScreen = require(script.Parent.TitleScreen)

local Colors = Config.Colors
local FONT = Enum.Font.FredokaOne
local player = Players.LocalPlayer

local Menu = {}

local stack: Frame

-- True on phones and tablets (a touch screen and no keyboard).
function Menu.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function new(className: string, props, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

-- Adds a button to the stack. `order`: lower sits nearer the bottom (computer) / top (touch).
function Menu.add(order: number, text: string, color: Color3, onClick: () -> ()): TextButton
	local touch = Menu.isTouch()
	local button = new("TextButton", {
		LayoutOrder = if touch then order else -order,
		Size = if touch then UDim2.fromOffset(118, 38) else UDim2.fromOffset(130, 44),
		BackgroundColor3 = color,
		Font = FONT,
		TextSize = if touch then 18 else 22,
		TextColor3 = Color3.new(1, 1, 1),
		Text = text,
		AutoButtonColor = false,
	}, stack)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, button)
	new("UIStroke", { Thickness = 3, Color = Colors.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
	TitleScreen.wireButton(button)
	button.Activated:Connect(onClick)
	return button
end

-- A little red dot on a button ("something to claim here").
function Menu.setBadge(button: GuiObject, on: boolean)
	local dot = button:FindFirstChild("Badge") :: Frame?
	if on and not dot then
		dot = new("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = Color3.fromRGB(230, 50, 50),
			ZIndex = 3,
		}, button)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
		new("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }, dot)
	elseif not on and dot then
		dot:Destroy()
	end
end

function Menu.start()
	local gui = new("ScreenGui", { Name = "Menu", ResetOnSpawn = false, DisplayOrder = 25 }, player:WaitForChild("PlayerGui"))
	local touch = Menu.isTouch()
	stack = new("Frame", {
		AnchorPoint = if touch then Vector2.new(0, 0) else Vector2.new(0, 1),
		Position = if touch then UDim2.fromOffset(16, 186) else UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(140, 260),
		BackgroundTransparency = 1,
	}, gui)
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = if touch then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom,
	}, stack)

	if touch then
		local function update()
			stack.Visible = not player:GetAttribute("InRound")
		end
		player:GetAttributeChangedSignal("InRound"):Connect(update)
		update()
	end
end

return Menu
