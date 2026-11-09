-- The CODES button (in the menu stack, client/Menu.luau) and the box where you type a promo code. The server checks the
-- code and sends back a message, shown in green if it worked and red if not.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Audio = require(script.Parent.Audio)
local Menu = require(script.Parent.Menu)
local TitleScreen = require(script.Parent.TitleScreen)

local Colors = Config.Colors
local FONT = Enum.Font.FredokaOne
local player = Players.LocalPlayer

local CodesPanel = {}

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

function CodesPanel.start()
	local gui = new("ScreenGui", { Name = "Codes", ResetOnSpawn = false, DisplayOrder = 25 }, player:WaitForChild("PlayerGui"))

	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 230),
		BackgroundColor3 = Colors.Paper,
		Visible = false,
	}, gui)
	style(card, 16, 4)

	new("TextLabel", {
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -80, 0, 36),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Felt,
		Text = "ENTER A CODE",
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

	local box = new("TextBox", {
		Position = UDim2.fromOffset(20, 62),
		Size = UDim2.new(1, -40, 0, 48),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = FONT,
		TextSize = 24,
		TextColor3 = Colors.Ink,
		PlaceholderText = "Type your code here",
		PlaceholderColor3 = Color3.fromRGB(170, 160, 150),
		Text = "",
		ClearTextOnFocus = false,
	}, card)
	style(box, 10, 2)

	local redeem = new("TextButton", {
		Position = UDim2.fromOffset(20, 122),
		Size = UDim2.new(1, -40, 0, 46),
		BackgroundColor3 = Color3.fromRGB(80, 160, 90),
		Font = FONT,
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "REDEEM",
		AutoButtonColor = false,
	}, card)
	style(redeem, 10, 2)
	TitleScreen.wireButton(redeem)

	local message = new("TextLabel", {
		Position = UDim2.fromOffset(20, 176),
		Size = UDim2.new(1, -40, 0, 36),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = Colors.Ink,
		Text = "",
	}, card)

	Menu.add(1, "\u{1F39F}\u{FE0F} CODES", Color3.fromRGB(80, 140, 200), function()
		card.Visible = not card.Visible
		message.Text = ""
	end)
	close.Activated:Connect(function()
		card.Visible = false
	end)

	local busy = false
	local function submit()
		if busy then
			return
		end
		busy = true
		redeem.Text = "Checking..."
		local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RedeemCode") :: RemoteFunction
		local ok, result = pcall(function()
			return remote:InvokeServer(box.Text)
		end)
		if ok and type(result) == "table" then
			message.Text = result.message
			message.TextColor3 = if result.ok then Color3.fromRGB(60, 150, 70) else Colors.Felt
			if result.ok then
				Audio.play("Fanfare", nil, "Interface")
				box.Text = ""
			end
		else
			message.Text = "Something went wrong, try again."
			message.TextColor3 = Colors.Felt
		end
		redeem.Text = "REDEEM"
		busy = false
	end
	redeem.Activated:Connect(submit)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
end

return CodesPanel
