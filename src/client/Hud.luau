-- Scrapbook-style HUD: paper tags with ink outlines, felt badges, and stamped big text.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Audio = require(script.Parent.Audio)

local Colors = Config.Colors
local FONT = Enum.Font.FredokaOne
local player = Players.LocalPlayer

local Hud = {}

local gui: ScreenGui

-- Helpers ---------------------------------------------------------------------------

local function tween(instance: Instance, seconds: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function round(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function outline(parent: Instance, thickness: number?, color: Color3?)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 3
	stroke.Color = color or Colors.Ink
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

local function new(className: string, props, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent or gui
	return instance
end

-- A paper tag with a thick ink outline.
local function paper(props, parent: Instance?): Frame
	local frame = new("Frame", props, parent)
	frame.BackgroundColor3 = props.BackgroundColor3 or Colors.Paper
	round(frame, 12)
	outline(frame)
	return frame
end

local function text(props, parent: Instance): TextLabel
	local label = new("TextLabel", props, parent)
	label.BackgroundTransparency = 1
	label.Font = props.Font or FONT
	label.TextColor3 = props.TextColor3 or Colors.Ink
	return label
end

local function bump(target: GuiObject)
	local scale = target:FindFirstChildOfClass("UIScale") or new("UIScale", {}, target)
	scale.Scale = 1.35
	tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Status + timer ----------------------------------------------------------------------

local statusLabel: TextLabel
local timerBadge: Frame
local timerLabel: TextLabel

local function buildStatus()
	local frame = paper({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(380, 50),
	})
	statusLabel = text({ Size = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(14, 0), TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left }, frame)

	timerBadge = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 8, 0.5, 0),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = Colors.Felt,
	}, frame)
	round(timerBadge, 32)
	outline(timerBadge)
	timerLabel = text({ Size = UDim2.fromScale(1, 1), TextSize = 26, TextColor3 = Colors.Paper }, timerBadge)

	local function update()
		statusLabel.Text = ReplicatedStorage:GetAttribute("Status") or ""
		local timeLeft = ReplicatedStorage:GetAttribute("TimeLeft") or 0
		timerBadge.Visible = timeLeft > 0
		timerLabel.Text = tostring(timeLeft)
		timerBadge.BackgroundColor3 = if timeLeft <= 10 then Colors.Warning else Colors.Felt
	end
	ReplicatedStorage:GetAttributeChangedSignal("Status"):Connect(update)
	ReplicatedStorage:GetAttributeChangedSignal("TimeLeft"):Connect(update)
	update()
end

-- Score card with combo multiplier ------------------------------------------------------

local function buildScore()
	local card = paper({ Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(200, 72) })
	local stripe = new("Frame", { Size = UDim2.new(0, 16, 1, 0), BorderSizePixel = 0 }, card)
	round(stripe, 12)
	text({ Position = UDim2.fromOffset(26, 4), Size = UDim2.fromOffset(120, 20), TextSize = 16, Text = "SCORE", TextXAlignment = Enum.TextXAlignment.Left }, card)
	-- Score written in messy crayon.
	local scoreLabel = text({ Position = UDim2.fromOffset(26, 22), Size = UDim2.fromOffset(120, 44), TextSize = 38, Text = "0", Font = Enum.Font.PermanentMarker, TextXAlignment = Enum.TextXAlignment.Left }, card)

	local badge = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -2, 0.5, 0),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = Colors.Gold,
		Visible = false,
	}, card)
	round(badge, 28)
	outline(badge)
	local multiplierLabel = text({ Size = UDim2.fromScale(1, 1), TextSize = 26 }, badge)

	local function updateColor()
		stripe.BackgroundColor3 = player:GetAttribute("Color") or Colors.Felt
	end
	-- Big jumps (bubbles) roll the counter up like a mechanical tally; small ones just update.
	local shown = 0
	local rollToken = 0
	local function updateScore()
		local target = (player:GetAttribute("Score") :: number?) or 0
		rollToken += 1
		local token = rollToken
		if target - shown <= 5 then
			shown = target
			scoreLabel.Text = tostring(target)
			return
		end
		local from = shown
		task.spawn(function()
			for step = 1, 6 do
				if rollToken ~= token then
					return
				end
				shown = math.floor(from + (target - from) * step / 6)
				scoreLabel.Text = tostring(shown)
				task.wait(0.04)
			end
			bump(scoreLabel)
		end)
	end
	local lastMultiplier = 1
	local function updateMultiplier()
		local multiplier = player:GetAttribute("Multiplier") or 1
		badge.Visible = multiplier > 1
		multiplierLabel.Text = `x{multiplier}`
		if multiplier > lastMultiplier then
			bump(badge)
		end
		lastMultiplier = multiplier
	end

	player:GetAttributeChangedSignal("Color"):Connect(updateColor)
	player:GetAttributeChangedSignal("Score"):Connect(updateScore)
	player:GetAttributeChangedSignal("Multiplier"):Connect(updateMultiplier)
	updateColor()
	updateScore()
	updateMultiplier()
end

-- Oxygen bar ------------------------------------------------------------------------------

-- Health: a stitched red ribbon with a zipper. As you take damage the zipper slides back and
-- the ribbon "unzips", showing the dark lining underneath.
local function buildHealth()
	local frame = paper({ Position = UDim2.fromOffset(16, 96), Size = UDim2.fromOffset(200, 34) })
	local lining = new("Frame", { Position = UDim2.fromOffset(8, 7), Size = UDim2.new(1, -16, 1, -14), BackgroundColor3 = Color3.fromRGB(70, 40, 40), BorderSizePixel = 0 }, frame)
	round(lining, 6)
	local ribbon = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Felt, BorderSizePixel = 0, ClipsDescendants = true }, lining)
	round(ribbon, 6)
	-- Zipper teeth down the middle and white stitches along the edges.
	for i = 0, 29 do
		new("Frame", { Position = UDim2.new(i / 30, 2, 0.5, if i % 2 == 0 then -3 else 0), Size = UDim2.fromOffset(3, 3), BackgroundColor3 = Colors.Gold, BorderSizePixel = 0 }, ribbon)
		if i % 2 == 0 then
			new("Frame", { Position = UDim2.new(i / 30, 2, 0, 2), Size = UDim2.fromOffset(4, 1), BackgroundColor3 = Colors.Paper, BorderSizePixel = 0 }, ribbon)
			new("Frame", { Position = UDim2.new(i / 30, 2, 1, -3), Size = UDim2.fromOffset(4, 1), BackgroundColor3 = Colors.Paper, BorderSizePixel = 0 }, ribbon)
		end
	end
	local pull = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(10, 22), BackgroundColor3 = Colors.Gold }, lining)
	round(pull, 3)
	outline(pull, 1.5)

	local connection: RBXScriptConnection? = nil
	local function watch(character: Model)
		if connection then
			connection:Disconnect()
		end
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		local function update()
			local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
			tween(ribbon, 0.25, { Size = UDim2.fromScale(ratio, 1) })
			tween(pull, 0.25, { Position = UDim2.fromScale(ratio, 0.5) })
		end
		connection = humanoid.HealthChanged:Connect(update)
		update()
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end

	-- Our ribbon replaces Roblox's own health bar.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
end

local function buildOxygen()
	local frame = paper({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 72),
		Size = UDim2.fromOffset(260, 30),
		Visible = false,
	})
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Sea, BorderSizePixel = 0 }, frame)
	round(fill, 12)
	local label = text({ Size = UDim2.fromScale(1, 1), TextSize = 18, ZIndex = 2 }, frame)

	player:GetAttributeChangedSignal("Oxygen"):Connect(function()
		local oxygen = player:GetAttribute("Oxygen")
		frame.Visible = oxygen ~= nil
		if oxygen then
			local maxOxygen = player:GetAttribute("MaxOxygen") or Config.DefaultOxygen
			local ratio = math.clamp(oxygen / maxOxygen, 0, 1)
			fill.Size = UDim2.fromScale(ratio, 1)
			fill.BackgroundColor3 = if ratio < 0.3 then Colors.Felt else Colors.Sea
			label.Text = `AIR  {math.ceil(oxygen)}s`
		end
	end)
end

-- Gear card: what you have equipped and its passives -------------------------------------------

local function buildGear()
	local card = paper({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(250, 120),
	})
	local nameLabel = text({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 30), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, card)
	local passiveLabel = text({ Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 48), TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(100, 80, 64) }, card)
	text({ Position = UDim2.fromOffset(10, 90), Size = UDim2.new(1, -20, 0, 22), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Text = "Roll for more at the gear machine!", TextColor3 = Colors.Felt }, card)

	local function updateGear()
		local gear = Config.getGear(player:GetAttribute("Gear"))
		if gear then
			nameLabel.Text = `{gear.icon} {gear.name}`
			nameLabel.TextColor3 = Config.RarityColors[gear.rarity]
			passiveLabel.Text = table.concat(Config.describePassives(gear), "\n")
		else
			nameLabel.Text = "No gear yet"
			nameLabel.TextColor3 = Colors.Ink
			passiveLabel.Text = `{Config.DefaultOxygen}s of air underwater`
		end
	end
	player:GetAttributeChangedSignal("Gear"):Connect(updateGear)
	updateGear()
end

-- Countdown stamp + level banner ------------------------------------------------------------

local stamp: TextLabel
local banner: Frame
local bannerLabel: TextLabel

local function buildBigText()
	stamp = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(400, 160),
		TextSize = 120,
		TextColor3 = Colors.Paper,
		Visible = false,
		ZIndex = 10,
	}, gui)
	new("UIStroke", { Thickness = 6, Color = Colors.Ink }, stamp)
	new("UIScale", {}, stamp)

	banner = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.5, 0.25),
		Size = UDim2.new(1, 0, 0, 90),
		BackgroundColor3 = Colors.Felt,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 8,
	})
	outline(banner, 4)
	bannerLabel = text({ Size = UDim2.fromScale(1, 1), TextSize = 56, TextColor3 = Colors.Paper, ZIndex = 9 }, banner)
	new("UIStroke", { Thickness = 3, Color = Colors.Ink }, bannerLabel)
end

local stampToken = 0

local function showCountdown(value: string)
	local isGo = value == "GO!"
	Audio.play(if isGo then "Go" else "Countdown", nil, "Interface")
	stamp.Text = value
	stamp.TextColor3 = if isGo then Color3.fromRGB(120, 220, 110) else Colors.Paper
	stamp.TextTransparency = 0
	stamp.Visible = true
	stamp.Rotation = math.random(-8, 8)
	local scale = stamp:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 2.2
	tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	-- Fade out, then hide it completely (the outline doesn't fade with the text, which used to leave a
	-- dark "GO!" stuck on screen). A newer stamp cancels this one.
	stampToken += 1
	local token = stampToken
	task.delay(0.75, function()
		if stampToken == token then
			tween(stamp, 0.2, { TextTransparency = 1 })
			task.wait(0.25)
			if stampToken == token then
				stamp.Visible = false
			end
		end
	end)
end

local bannerToken = 0
local function showLevelIntro(title: string, color: Color3?)
	bannerToken += 1
	local token = bannerToken
	bannerLabel.Text = string.upper(title)
	banner.BackgroundColor3 = color or Colors.Felt
	banner.Visible = true
	banner.Position = UDim2.fromScale(-0.5, 0.25)
	tween(banner, 0.45, { Position = UDim2.fromScale(0.5, 0.25) }, Enum.EasingStyle.Back)
	task.delay(2.2, function()
		if bannerToken ~= token then
			return -- a newer banner took over
		end
		tween(banner, 0.35, { Position = UDim2.fromScale(1.5, 0.25) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.4)
		if bannerToken == token then
			banner.Visible = false
		end
	end)
end

-- Announcements (top right) ----------------------------------------------------------------

local feed: Frame

local function buildFeed()
	feed = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(300, 300),
		BackgroundTransparency = 1,
	})
	new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right }, feed)
end

local function announce(message: string, color: Color3?)
	local note = paper({ Size = UDim2.fromOffset(300, 36) }, feed)
	local dot = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = color or Colors.Felt }, note)
	round(dot, 8)
	text({ Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -40, 1, 0), TextSize = 16, Text = message, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, note)
	task.delay(4, function()
		note:Destroy()
	end)
end

-- Results scoreboard ----------------------------------------------------------------------

local results: Frame

local function showResults(data)
	if results then
		results:Destroy()
	end
	local rowHeight = 40
	results = paper({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 80 + math.max(1, #data.entries) * (rowHeight + 6)),
		ZIndex = 7,
	})
	new("UIScale", {}, results)
	text({ Size = UDim2.new(1, 0, 0, 56), TextSize = 32, Text = `{string.upper(data.title)} RESULTS`, ZIndex = 8 }, results)

	for i, entry in data.entries do
		local row = new("Frame", {
			Position = UDim2.fromOffset(16, 56 + (i - 1) * (rowHeight + 6)),
			Size = UDim2.new(1, -32, 0, rowHeight),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 8,
		}, results)
		round(row, 8)
		local stripe = new("Frame", { Size = UDim2.new(0, 10, 1, 0), BackgroundColor3 = entry.color or Colors.Felt, BorderSizePixel = 0, ZIndex = 9 }, row)
		round(stripe, 8)
		text({ Position = UDim2.fromOffset(18, 0), Size = UDim2.new(0.4, 0, 1, 0), TextSize = 20, Text = `{i}. {entry.name}`, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 9 }, row)
		text({ Position = UDim2.fromScale(0.45, 0), Size = UDim2.new(0.2, 0, 1, 0), TextSize = 22, Text = tostring(entry.score), ZIndex = 9 }, row)
		text({
			Position = UDim2.fromScale(0.65, 0),
			Size = UDim2.new(0.35, -8, 1, 0),
			TextSize = 16,
			Text = (if entry.survived then "SURVIVED" else "POPPED") .. `  +{entry.stickers}`,
			TextColor3 = if entry.survived then Color3.fromRGB(70, 160, 70) else Colors.Felt,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 9,
		}, row)
	end

	local scale = results:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0
	tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	-- (Survivors hear the fanfare from the Victory effect; this card is silent.)

	local shown = results
	task.delay(Config.ResultsTime - 0.5, function()
		if results == shown then
			shown:Destroy()
		end
	end)
end

-- Wiring ------------------------------------------------------------------------------------

function Hud.handle(kind: string, data)
	if kind == "Countdown" then
		showCountdown(data.text)
	elseif kind == "LevelIntro" then
		showLevelIntro(data.title)
	elseif kind == "Announce" then
		announce(data.text, data.color)
	elseif kind == "Results" then
		showResults(data)
	elseif kind == "Chaos" then
		showLevelIntro(`CHAOS MODE!  x{data.multiplier} POINTS`, Color3.fromRGB(150, 20, 30))
		announce("Sharks are coming through the walls!", Color3.fromRGB(220, 40, 40))
	elseif kind == "Pop" and data.userId == player.UserId then
		-- You grabbed a bubble: the tally counter clicks over.
		Audio.play("TallyClick", nil, "Interface")
		task.delay(0.08, Audio.play, "TallyClick", nil, "Interface")
	end
end

function Hud.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	buildStatus()
	buildScore()
	buildHealth()
	buildOxygen()
	buildGear()
	buildBigText()
	buildFeed()
end

return Hud
