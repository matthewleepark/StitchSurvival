-- Leaderboards: two big lit boards on the lobby's back wall, one above the elevators and one beside the
-- fireplace chimney. Each board takes turns showing its categories (Config.Leaderboards), the top 10 from
-- every server (OrderedDataStores, see server/Data.luau). The lists are fetched every refreshSeconds.
-- When saving is off (Studio without API access) the boards rank the players on this server instead.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Craft)
local Data = require(script.Parent.Data)

local Colors = Config.Colors
local L = Config.LobbyColors
local FONT = Enum.Font.FredokaOne
local ROWS = 10
local MEDALS = { Color3.fromRGB(250, 200, 60), Color3.fromRGB(200, 205, 215), Color3.fromRGB(205, 130, 70) }

local Leaderboards = {}

type Row = { name: string, value: number }

local cached: { [string]: { Row } } = {} -- stat -> top rows
local names: { [number]: string } = {} -- userId -> username, so each name is looked up once

local function nameOf(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.DisplayName
	end
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and name then name else "???"
	return names[userId]
end

-- Ranks the players on this server (used when the DataStores can't be reached).
local function localTop(stat: string): { Row }
	local rows = {}
	for _, player in Players:GetPlayers() do
		local profile = Data.get(player)
		if profile then
			local value = Data.statOf(profile, stat)
			if stat == "wins" then
				local leaderstats = player:FindFirstChild("leaderstats")
				local wins = leaderstats and leaderstats:FindFirstChild("Wins") :: IntValue?
				value = if wins then wins.Value else value
			end
			if value > 0 then
				table.insert(rows, { name = player.DisplayName, value = value })
			end
		end
	end
	table.sort(rows, function(a, b)
		return a.value > b.value
	end)
	while #rows > ROWS do
		table.remove(rows)
	end
	return rows
end

local function refresh(stat: string)
	local top = Data.top(stat, ROWS)
	if top then
		local rows = {}
		for _, entry in top do
			table.insert(rows, { name = nameOf(entry.userId), value = entry.value })
		end
		cached[stat] = rows
	else
		cached[stat] = localTop(stat)
	end
end

local function new(className: string, props, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

-- One board: a wooden frame with a dark velvet face, a title and ten rows. Returns a function that shows
-- a category on it.
local function buildBoard(parent: Instance, center: Vector3, width: number, height: number): (category: any) -> ()
	Craft.block(parent, CFrame.new(center), Vector3.new(width + 0.8, height + 0.8, 0.5), L.PanelDark, Craft.Material.Wood)
	local face = Craft.block(parent, CFrame.new(center + Vector3.new(0, 0, 0.3)), Vector3.new(width, height, 0.1), L.Velvet, Craft.Material.Felt, Craft.DECOR)
	face.Name = "LeaderboardFace"
	-- Brass trim along the top and a little lamp to light it.
	Craft.block(parent, CFrame.new(center + Vector3.new(0, height / 2 + 0.55, 0.4)), Vector3.new(width + 1.2, 0.3, 0.6), L.Brass, Craft.Material.Metal, Craft.DECOR)
	local lampHolder = Craft.block(parent, CFrame.new(center + Vector3.new(0, height / 2 + 1, 2.5)), Vector3.one * 0.2, Color3.new(), nil, Craft.DECOR)
	lampHolder.Transparency = 1
	new("SpotLight", { Face = Enum.NormalId.Bottom, Angle = 70, Range = 16, Brightness = 1.6, Color = Color3.fromRGB(255, 225, 175) }, lampHolder)

	local gui = new("SurfaceGui", {
		Face = Enum.NormalId.Back, -- +Z, into the room
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50,
		LightInfluence = 0, -- readable even in the dark lobby
		MaxDistance = 160,
	}, face)
	local root = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }, root)
	local title = new("TextLabel", {
		Size = UDim2.new(1, 0, 0.13, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = L.Cream,
		Text = "",
	}, root)
	new("UIStroke", { Thickness = 2, Color = Colors.Ink }, title)
	local list = new("Frame", { Position = UDim2.fromScale(0, 0.15), Size = UDim2.fromScale(1, 0.85), BackgroundTransparency = 1 }, root)
	new("UIListLayout", { Padding = UDim.new(0.006, 0), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local rows = {}
	for i = 1, ROWS do
		local row = new("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 1 / ROWS, -3),
			BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(104, 38, 54) else Color3.fromRGB(118, 44, 62),
			BorderSizePixel = 0,
		}, list)
		new("UICorner", { CornerRadius = UDim.new(0.25, 0) }, row)
		local rank = new("TextLabel", {
			Size = UDim2.fromScale(0.14, 1),
			BackgroundTransparency = 1,
			Font = FONT,
			TextScaled = true,
			TextColor3 = MEDALS[i] or L.Cream,
			Text = `{i}.`,
		}, row)
		new("UIPadding", { PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0) }, rank)
		local name = new("TextLabel", {
			Position = UDim2.fromScale(0.15, 0),
			Size = UDim2.fromScale(0.58, 1),
			BackgroundTransparency = 1,
			Font = FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = MEDALS[i] or Color3.new(1, 1, 1),
			Text = "",
		}, row)
		new("UIPadding", { PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0) }, name)
		local value = new("TextLabel", {
			Position = UDim2.fromScale(0.74, 0),
			Size = UDim2.fromScale(0.24, 1),
			BackgroundTransparency = 1,
			Font = FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Colors.Gold,
			Text = "",
		}, row)
		new("UIPadding", { PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0) }, value)
		rows[i] = { name = name, value = value }
	end

	return function(category)
		title.Text = category.title
		local top = cached[category.stat] or {}
		for i, row in rows do
			local entry = top[i]
			row.name.Text = if entry then entry.name else (if i == 1 then "Play to get on the board!" else "")
			row.value.Text = if entry then tostring(entry.value) else ""
		end
		root.Position = UDim2.fromOffset(0, 12)
		TweenService:Create(root, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.fromOffset(0, 0) }):Play()
	end
end

function Leaderboards.start()
	local pod = Config.Pod
	local O = pod.origin
	local model = new("Model", { Name = "Leaderboards" }, workspace)
	-- On the back wall, clear of the elevators' sign, the fireplace chimney (x 19.5 to 28.5), the windows
	-- (x 44 to 52) and the balconies (from x 40 out): 9.5 studs wide, centered 34.25 either side.
	local spots = { -34.25, 34.25 }
	local shows = {}
	for i, board in Config.Leaderboards.boards do
		local x = spots[i]
		if x then
			local show = buildBoard(model, O + Vector3.new(x, 24.5, -pod.depth / 2 + 0.6), 9.5, 10.5)
			table.insert(shows, { show = show, categories = board, index = 1 })
		end
	end

	local stats = {}
	for _, board in Config.Leaderboards.boards do
		for _, category in board do
			table.insert(stats, category.stat)
		end
	end

	-- Fetch the lists now and then; flip the boards between their categories.
	task.spawn(function()
		while true do
			for _, stat in stats do
				refresh(stat)
			end
			for _, entry in shows do
				entry.show(entry.categories[entry.index])
			end
			task.wait(Config.Leaderboards.refreshSeconds)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Leaderboards.flipSeconds)
			for _, entry in shows do
				entry.index = entry.index % #entry.categories + 1
				entry.show(entry.categories[entry.index])
			end
		end
	end)
end

return Leaderboards
