-- The map vote. Between rounds a few map pads pop up out of the floor in front of the reception desk, each
-- with a sign: the map's icon and name and how many votes it has. Stand on a pad to vote for that map; your
-- vote stays with the last pad you stood on. When the vote closes the map with the most votes wins (a tie,
-- or nobody voting, is picked at random), the winning pad flashes, and the pads sink away again.
-- Numbers are in Config.Vote; each map's icon and color are on its Config.Levels entry.
--
--   Vote.choices(playerCount)  which maps to offer (only ones with enough players to work)
--   Vote.open(choices)         pop the pads up and start counting
--   Vote.close()               the winning map's Config.Levels entry; the pads go away
--   Vote.cancel()              take the pads away without a result (an admin started a round)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Craft)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local Colors = Config.Colors
local L = Config.LobbyColors
local M = Craft.Material
local PAD = 8 -- studs across
local SPACING = 11 -- between pad centers
local PAD_Z = -17 -- in front of the reception desk (its front is at about z = -23.5 in lobby coordinates)
local RISE = 5 -- how far below the floor the pads start before popping up

local Vote = {}

type Pad = { def: any, model: Model, base: BasePart, center: Vector3, votesLabel: TextLabel }

local pads: { Pad } = {}
local votes: { [Player]: number } = {} -- player -> index into pads
local counting = false

-- How many players a map needs (Killer Hotel and Hide & Seek need someone to hunt, unless testing solo).
local function minimumFor(def): number
	if def.name == "KillerHotel" and Config.KillerHotel.soloTest then
		return 1
	elseif def.name == "HideAndSeek" and Config.HideAndSeek.soloTest then
		return 1
	end
	return def.minPlayers or Config.MinPlayers
end

-- Up to Config.Vote.choices maps, picked at random from the ones that work with this many players.
function Vote.choices(playerCount: number): { any }
	local pool = {}
	for _, def in Config.Levels do
		if playerCount >= minimumFor(def) then
			table.insert(pool, def)
		end
	end
	local picked = {}
	while #picked < Config.Vote.choices and #pool > 0 do
		table.insert(picked, table.remove(pool, math.random(1, #pool)))
	end
	return picked
end

local function new(className: string, props, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

-- One pad: a glowing square with a brass rim, and a sign standing behind it facing the lobby.
local function buildPad(def, center: Vector3): Pad
	local color = def.color or Colors.Gold
	local model = new("Model", { Name = `VotePad_{def.name}` })
	local base = Craft.block(model, CFrame.new(center + Vector3.new(0, 0.15, 0)), Vector3.new(PAD, 0.3, PAD), color, M.Neon, { CanCollide = false, CanQuery = false })
	base.Transparency = 0.3
	new("PointLight", { Color = color, Range = 14, Brightness = 1.2 }, base)
	for _, side in { -1, 1 } do
		Craft.block(model, CFrame.new(center + Vector3.new(side * PAD / 2, 0.25, 0)), Vector3.new(0.4, 0.5, PAD + 0.4), L.Brass, M.Metal, Craft.DECOR)
		Craft.block(model, CFrame.new(center + Vector3.new(0, 0.25, side * PAD / 2)), Vector3.new(PAD + 0.4, 0.5, 0.4), L.Brass, M.Metal, Craft.DECOR)
	end

	-- The sign: on two brass legs at the back edge of the pad, facing toward the entrance (+Z).
	local signCenter = center + Vector3.new(0, 6.2, -PAD / 2 - 0.4)
	for _, side in { -1, 1 } do
		Craft.cylinder(model, center + Vector3.new(side * 3.4, 2.1, -PAD / 2 - 0.4), 4.2, 0.35, "Y", L.Brass, M.Metal)
	end
	Craft.block(model, CFrame.new(signCenter), Vector3.new(PAD + 0.6, 4.6, 0.4), L.PanelDark, M.Wood)
	Craft.block(model, CFrame.new(signCenter + Vector3.new(0, 2.45, 0.1)), Vector3.new(PAD + 0.6, 0.3, 0.5), color, M.Neon, Craft.DECOR)
	local face = Craft.block(model, CFrame.new(signCenter + Vector3.new(0, 0, 0.25)), Vector3.new(PAD, 4, 0.1), Colors.Paper, Enum.Material.SmoothPlastic, Craft.DECOR)
	local gui = new("SurfaceGui", {
		Face = Enum.NormalId.Back, -- +Z, toward the players
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50,
		LightInfluence = 0,
	}, face)
	local function line(text: string, y: number, height: number, textColor: Color3): TextLabel
		return new("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.04, y),
			Size = UDim2.fromScale(0.92, height),
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = textColor,
			Text = text,
		}, gui)
	end
	line(`{def.icon or ""} {string.upper(def.title)}`, 0.05, 0.36, color:Lerp(Colors.Ink, 0.25))
	local votesLabel = line("0 votes", 0.43, 0.3, Colors.Ink)
	line("Stand here to vote!", 0.76, 0.18, Color3.fromRGB(110, 90, 70))

	model.Parent = workspace
	return { def = def, model = model, base = base, center = center, votesLabel = votesLabel }
end

-- Slides models up from under the floor (or back down) with a little bounce.
local function slide(models: { Model }, up: boolean)
	local starts = {}
	for i, model in models do
		starts[i] = model:GetPivot()
	end
	local steps = 18
	for step = 1, steps do
		local t = step / steps
		local offset = if up
			then -RISE * (1 - TweenService:GetValue(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
			else -RISE * TweenService:GetValue(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for i, model in models do
			if model.Parent then
				local base = if up then starts[i] + Vector3.new(0, RISE, 0) else starts[i]
				model:PivotTo(base + Vector3.new(0, offset, 0))
			end
		end
		task.wait(1 / 30)
	end
end

local function counts(): { number }
	local list = {}
	for i = 1, #pads do
		list[i] = 0
	end
	for player, index in votes do
		if player.Parent and list[index] then
			list[index] += 1
		end
	end
	return list
end

local function refreshLabels()
	for i, n in counts() do
		pads[i].votesLabel.Text = if n == 1 then "1 vote" else `{n} votes`
	end
end

-- Who's standing on which pad.
local function track()
	while counting do
		local changed = false
		for _, player in Players:GetPlayers() do
			local root = Util.rootPart(player)
			if root and Util.aliveHumanoid(player) then
				for i, pad in pads do
					local offset = root.Position - pad.center
					if math.abs(offset.X) <= PAD / 2 and math.abs(offset.Z) <= PAD / 2 and offset.Y > -1 and offset.Y < 7 then
						if votes[player] ~= i then
							votes[player] = i
							changed = true
							Util.playSound("TallyClick", pad.base)
							Remotes.fireAll("Popup", { text = "+1", position = pad.center + Vector3.new(0, 4, 0), color = pad.def.color })
						end
						break
					end
				end
			end
		end
		if changed then
			refreshLabels()
		end
		task.wait(0.15)
	end
end

function Vote.open(choices: { any })
	Vote.cancel()
	table.clear(votes)
	local O = Config.Pod.origin
	local models = {}
	for i, def in choices do
		local x = (i - (#choices + 1) / 2) * SPACING
		local pad = buildPad(def, O + Vector3.new(x, 0, PAD_Z))
		pad.model:PivotTo(pad.model:GetPivot() - Vector3.new(0, RISE, 0)) -- start under the floor
		table.insert(pads, pad)
		table.insert(models, pad.model)
	end
	Util.soundAt("Rumble", O + Vector3.new(0, 1, PAD_Z))
	Remotes.fireAll("Announce", { text = "Vote for the next map! Stand on one at the reception desk.", color = Colors.Gold })
	slide(models, true)
	counting = true
	task.spawn(track)
end

-- Ends the vote: returns the winning map (its Config.Levels entry), or nil if there were no pads.
function Vote.close(): any?
	counting = false
	if #pads == 0 then
		return nil
	end
	local list = counts()
	local best = -1
	local tied = {}
	for i, n in list do
		if n > best then
			best = n
			tied = { i }
		elseif n == best then
			table.insert(tied, i)
		end
	end
	local winnerIndex = tied[math.random(1, #tied)]
	local winner = pads[winnerIndex]
	Remotes.fireAll("Announce", { text = `Next map: {winner.def.title}!`, color = winner.def.color })

	-- The others sink; the winner flashes.
	local losers = {}
	for i, pad in pads do
		if i ~= winnerIndex then
			table.insert(losers, pad.model)
		end
	end
	task.spawn(slide, losers, false)
	for _ = 1, 4 do
		winner.base.Transparency = 0
		task.wait(0.15)
		winner.base.Transparency = 0.5
		task.wait(0.15)
	end
	slide({ winner.model }, false)
	Vote.cancel()
	return winner.def
end

-- Takes the pads away with no result.
function Vote.cancel()
	counting = false
	for _, pad in pads do
		pad.model:Destroy()
	end
	table.clear(pads)
	table.clear(votes)
end

Players.PlayerRemoving:Connect(function(player)
	votes[player] = nil
	if counting and #pads > 0 then
		refreshLabels()
	end
end)

return Vote
