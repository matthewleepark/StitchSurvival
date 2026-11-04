-- The gear machine's panel. Walk up to the machine in the lobby to open it.
--   * Top: a reel of items that spins and slows down to land on what you rolled.
--   * Middle: the result and its passives, the ROLL button and your Stickers.
--   * Bottom: every item with its picture, rarity, chance and passives, and an EQUIP button for the
--     ones you own. The secret item shows as ??? until you get it.
-- The server picks the item; this only animates the result it sends back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Audio = require(script.Parent.Audio)
local TitleScreen = require(script.Parent.TitleScreen)

local Colors = Config.Colors
local FONT = Enum.Font.FredokaOne
local player = Players.LocalPlayer

local GearPanel = {}

local TILE = 110 -- width of one item on the reel
local REEL_LENGTH = 40
local LANDING = 34 -- the result lands on this tile

local gui: ScreenGui
local strip: Frame
local resultLabel: TextLabel
local passivesLabel: TextLabel
local rollButton: TextButton
local stickersLabel: TextLabel
local list: ScrollingFrame
local spinning = false

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

local function outline(parent: Instance, thickness: number, color: Color3?)
	new("UIStroke", { Thickness = thickness, Color = color or Colors.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local function label(parent: Instance, props): TextLabel
	local textLabel = new("TextLabel", props, parent)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = props.Font or FONT
	textLabel.TextColor3 = props.TextColor3 or Colors.Ink
	return textLabel
end

local function owns(name: string): boolean
	local list = player:GetAttribute("OwnedGear") :: string?
	if not list then
		return false
	end
	for owned in string.gmatch(list, "[^,]+") do
		if owned == name then
			return true
		end
	end
	return false
end

-- One square on the reel: the item's picture and name on its rarity color.
local function tile(parent: Instance, gear, index: number)
	local hidden = gear.secret and not owns(gear.name)
	local frame = new("Frame", {
		Position = UDim2.fromOffset((index - 1) * TILE + 5, 5),
		Size = UDim2.fromOffset(TILE - 10, TILE - 10),
		BackgroundColor3 = Config.RarityColors[gear.rarity],
	}, parent)
	round(frame, 12)
	outline(frame, 2)
	label(frame, { Size = UDim2.new(1, 0, 0.62, 0), TextScaled = true, Text = if hidden then "\u{2753}" else gear.icon })
	label(frame, { Position = UDim2.fromScale(0.05, 0.62), Size = UDim2.fromScale(0.9, 0.34), TextScaled = true, Text = if hidden then "???" else gear.name, TextColor3 = Color3.new(1, 1, 1) })
	return frame
end

-- The list of every item, rebuilt whenever what you own or wear changes.
local function refreshList()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local equipped = player:GetAttribute("Gear")
	for i, gear in Config.Gear do
		local have = owns(gear.name)
		local hidden = gear.secret and not have
		local row = new("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, -12, 0, 62),
			BackgroundColor3 = if gear.name == equipped then Color3.fromRGB(255, 244, 200) else Color3.new(1, 1, 1),
		}, list)
		round(row, 10)
		outline(row, 2, Config.RarityColors[gear.rarity])
		label(row, { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(50, 50), TextScaled = true, Text = if hidden then "\u{2753}" else gear.icon })
		label(row, {
			Position = UDim2.fromOffset(66, 4),
			Size = UDim2.new(0.45, -66, 0, 26),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if hidden then "???" else gear.name,
			TextColor3 = Config.RarityColors[gear.rarity],
		})
		label(row, {
			Position = UDim2.fromOffset(66, 32),
			Size = UDim2.new(0.45, -66, 0, 22),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("%s  %s%%", string.upper(gear.rarity), if Config.gearChance(gear) < 1 then string.format("%.1f", Config.gearChance(gear)) else tostring(math.floor(Config.gearChance(gear) + 0.5))),
			TextColor3 = Color3.fromRGB(110, 90, 70),
		})
		label(row, {
			Position = UDim2.fromScale(0.45, 0),
			Size = UDim2.new(0.37, 0, 1, 0),
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if hidden then "A secret... nobody knows what it does." else table.concat(Config.describePassives(gear), "  \u{2022}  "),
			TextColor3 = Colors.Ink,
		})
		if have then
			local isOn = gear.name == equipped
			local equip = new("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.new(0.16, 0, 0, 38),
				BackgroundColor3 = if isOn then Colors.Gold else Color3.fromRGB(80, 150, 90),
				Font = FONT,
				TextScaled = true,
				TextColor3 = Color3.new(1, 1, 1),
				Text = if isOn then "EQUIPPED" else "EQUIP",
				AutoButtonColor = false,
			}, row)
			round(equip, 8)
			outline(equip, 2)
			TitleScreen.wireButton(equip)
			equip.Activated:Connect(function()
				ReplicatedStorage.Remotes.EquipGear:FireServer(gear.name)
			end)
		else
			label(row, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.new(0.16, 0, 0, 30),
				TextScaled = true,
				Text = "Not yet",
				TextColor3 = Color3.fromRGB(150, 140, 130),
			})
		end
	end
end

local function refreshStickers()
	local leaderstats = player:FindFirstChild("leaderstats")
	local stickers = leaderstats and leaderstats:FindFirstChild("Stickers") :: IntValue?
	stickersLabel.Text = `You have {if stickers then stickers.Value else 0} Stickers`
end

local function build()
	gui = new("ScreenGui", { Name = "GearPanel", ResetOnSpawn = false, DisplayOrder = 30, Enabled = false, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))
	local dim = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0 }, gui)

	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(780, 560),
		BackgroundColor3 = Colors.Paper,
	}, dim)
	round(card, 18)
	outline(card, 4)
	local scale = new("UIScale", {}, card)
	local function fit()
		local view = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (view.X - 20) / 780, (view.Y - 20) / 560)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()

	label(card, { Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -120, 0, 40), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "\u{1F3B0} GEAR MACHINE", TextColor3 = Colors.Felt })
	local close = new("TextButton", {
		Position = UDim2.new(1, -56, 0, 10),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Colors.Felt,
		Font = FONT,
		TextSize = 26,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "X",
		AutoButtonColor = false,
	}, card)
	round(close, 22)
	outline(close, 2)
	TitleScreen.wireButton(close)
	close.Activated:Connect(function()
		if not spinning then
			gui.Enabled = false
		end
	end)

	-- The reel, with a gold marker down the middle.
	local reel = new("Frame", {
		Position = UDim2.fromOffset(20, 58),
		Size = UDim2.new(1, -40, 0, TILE),
		BackgroundColor3 = Color3.fromRGB(60, 42, 30),
		ClipsDescendants = true,
	}, card)
	round(reel, 12)
	strip = new("Frame", { Size = UDim2.fromOffset(TILE * REEL_LENGTH, TILE), BackgroundTransparency = 1 }, reel)
	for i = 1, 8 do
		tile(strip, Config.Gear[(i - 1) % #Config.Gear + 1], i)
	end
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Colors.Gold, BorderSizePixel = 0, ZIndex = 3 }, reel)

	resultLabel = label(card, { Position = UDim2.fromOffset(20, 174), Size = UDim2.new(1, -40, 0, 34), TextScaled = true, Text = "Roll to see what you get!" })
	passivesLabel = label(card, { Position = UDim2.fromOffset(20, 208), Size = UDim2.new(1, -40, 0, 22), TextScaled = true, Text = "", TextColor3 = Color3.fromRGB(110, 90, 70) })

	rollButton = new("TextButton", {
		Position = UDim2.fromOffset(20, 238),
		Size = UDim2.fromOffset(300, 52),
		BackgroundColor3 = Colors.Felt,
		Font = FONT,
		TextSize = 26,
		TextColor3 = Color3.new(1, 1, 1),
		Text = `ROLL  ({Config.RollCost} Stickers)`,
		AutoButtonColor = false,
	}, card)
	round(rollButton, 12)
	outline(rollButton, 3)
	TitleScreen.wireButton(rollButton)
	rollButton.Activated:Connect(function()
		if spinning then
			return
		end
		spinning = true
		rollButton.Text = "Rolling..."
		Audio.play("GearRoll", nil, "Interface")
		ReplicatedStorage.Remotes.RequestRoll:FireServer()
	end)
	stickersLabel = label(card, { Position = UDim2.fromOffset(340, 246), Size = UDim2.new(1, -360, 0, 36), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left })

	list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 302),
		Size = UDim2.new(1, -40, 1, -316),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, card)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	player:GetAttributeChangedSignal("OwnedGear"):Connect(refreshList)
	player:GetAttributeChangedSignal("Gear"):Connect(refreshList)
	local leaderstats = player:WaitForChild("leaderstats", 10)
	local stickers = leaderstats and leaderstats:WaitForChild("Stickers", 10)
	if stickers then
		(stickers :: IntValue).Changed:Connect(refreshStickers)
	end
	refreshList()
	refreshStickers()
end

local function finishRoll()
	spinning = false
	rollButton.Text = `ROLL  ({Config.RollCost} Stickers)`
end

-- Spin the reel and land on the item the server picked.
local function spin(result)
	if not result then
		resultLabel.Text = "Not enough Stickers!"
		resultLabel.TextColor3 = Colors.Felt
		passivesLabel.Text = "Survive levels to earn more."
		finishRoll()
		return
	end
	local won = Config.getGear(result.name)
	if not won then
		finishRoll()
		return
	end

	-- Fill the reel with random items, with the winner on the landing tile.
	for _, child in strip:GetChildren() do
		child:Destroy()
	end
	for i = 1, REEL_LENGTH do
		local gear = if i == LANDING then won else Config.Gear[math.random(1, #Config.Gear - 1)]
		tile(strip, gear, i)
	end
	strip.Position = UDim2.fromOffset(0, 0)
	resultLabel.Text = "Rolling..."
	resultLabel.TextColor3 = Colors.Ink
	passivesLabel.Text = ""

	local reelWidth = (strip.Parent :: Frame).AbsoluteSize.X
	local finalX = -((LANDING - 1) * TILE + TILE / 2 - reelWidth / 2)
	local spinTween = TweenService:Create(strip, TweenInfo.new(4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(finalX, 0) })

	-- A click every time a new item passes the marker.
	local lastTile = 0
	local ticking = RunService.RenderStepped:Connect(function()
		local under = math.floor((reelWidth / 2 - strip.Position.X.Offset) / TILE)
		if under ~= lastTile then
			lastTile = under
			Audio.play("ReelTick", nil, "Interface")
		end
	end)
	spinTween:Play()
	spinTween.Completed:Wait()
	ticking:Disconnect()

	Audio.play("ReelWin", nil, "Interface")
	if Config.RarityOrder[won.rarity] >= Config.RarityOrder.Epic then
		Audio.play("Fanfare", nil, "Interface")
	end
	resultLabel.Text = `{won.icon} {won.name}  -  {string.upper(won.rarity)}{if result.isNew then "  (NEW!)" else ""}`
	resultLabel.TextColor3 = Config.RarityColors[won.rarity]
	passivesLabel.Text = table.concat(Config.describePassives(won), "  \u{2022}  ")
	refreshList()
	finishRoll()
end

function GearPanel.handle(kind: string, data)
	if not gui then
		return
	end
	if kind == "OpenGearPanel" then
		refreshList()
		refreshStickers()
		gui.Enabled = true
	elseif kind == "GearResult" then
		task.spawn(spin, data)
	end
end

function GearPanel.start()
	task.spawn(build)
end

return GearPanel
