-- The map vote. Where the reception desk used to be there's a marble voting stage with three brass-rimmed slots
-- (built by Levels/HotelLobby.luau). Between rounds a map pad rises out of each slot, with a sign in the lobby's
-- style (mahogany board, cream face, brass trim): the map's icon and name and how many votes it has. Stand on a
-- pad to vote for that map; your vote stays with the last pad you stood on. A map that needs more players than
-- are here is shown locked ("Needs 2 players") and can't be voted for. When the vote closes the map with the
-- most votes wins (a tie, or nobody voting, is picked at random from the open maps), the winning pad flashes,
-- and the pads sink back into the stage.
-- Numbers and the stage layout are in Config.Vote; each map's icon and color are on its Config.Levels entry.
--
--   Vote.choices(playerCount)  which maps to offer: { { def, locked } }
--   Vote.open(choices)         raise the pads and start counting
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
local STAGE = Config.Vote.stage
local PAD = STAGE.pad
local RISE = 4 -- how far down inside the stage the pads start before rising

local Vote = {}

export type Choice = { def: any, locked: boolean }
type Pad = { def: any, locked: boolean, model: Model, glow: BasePart, center: Vector3, votesLabel: TextLabel }

local pads: { Pad } = {}
local votes: { [Player]: number } = {} -- player -> index into pads
local warned: { [Player]: number } = {} -- last "needs more players" popup, so it isn't spammed
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

-- Config.Vote.choices maps at random. Maps that need more players than are here come out locked, but at least
-- one is always open.
function Vote.choices(playerCount: number): { Choice }
	local open, locked = {}, {}
	for _, def in Config.Levels do
		table.insert(if playerCount >= minimumFor(def) then open else locked, def)
	end
	local picked: { Choice } = {}
	if #open > 0 then
		table.insert(picked, { def = table.remove(open, math.random(1, #open)), locked = false })
	end
	local rest: { Choice } = {}
	for _, def in open do
		table.insert(rest, { def = def, locked = false })
	end
	for _, def in locked do
		table.insert(rest, { def = def, locked = true })
	end
	while #picked < Config.Vote.choices and #rest > 0 do
		local choice = table.remove(rest, math.random(1, #rest))
		if choice then
			table.insert(picked, choice)
		end
	end
	-- Shuffle so the open map isn't always on the left.
	for i = #picked, 2, -1 do
		local j = math.random(1, i)
		picked[i], picked[j] = picked[j], picked[i]
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

-- A map's color, softened toward the lobby's dark wood so it glows warmly instead of shouting.
local function tone(color: Color3, amount: number): Color3
	return color:Lerp(L.PanelDark, amount)
end

-- One pad: a dark marble slab with a softly glowing inlay in the map's color and a brass rim, and a sign on
-- brass legs behind it facing the lobby.
local function buildPad(choice: Choice, center: Vector3): Pad
	local def, locked = choice.def, choice.locked
	local color = if locked then L.Plaster else (def.color or Colors.Gold)
	local model = new("Model", { Name = `VotePad_{def.name}` })

	Craft.block(model, CFrame.new(center + Vector3.new(0, 0.15, 0)), Vector3.new(PAD - 0.3, 0.3, PAD - 0.3), L.MarbleDark, Enum.Material.Marble, { CanCollide = false })
	local glow = Craft.block(model, CFrame.new(center + Vector3.new(0, 0.31, 0)), Vector3.new(PAD - 1.6, 0.04, PAD - 1.6), tone(color, 0.35), M.Neon, Craft.DECOR)
	glow.Transparency = if locked then 0.85 else 0.55
	Craft.block(model, CFrame.new(center + Vector3.new(0, 0.33, 0)), Vector3.new(PAD - 2.6, 0.04, PAD - 2.6), L.MarbleDark, Enum.Material.Marble, Craft.DECOR)
	for _, side in { -1, 1 } do -- brass rim
		Craft.block(model, CFrame.new(center + Vector3.new(side * (PAD / 2 - 0.25), 0.35, 0)), Vector3.new(0.3, 0.1, PAD - 0.2), L.Brass, M.Metal, Craft.DECOR)
		Craft.block(model, CFrame.new(center + Vector3.new(0, 0.35, side * (PAD / 2 - 0.25))), Vector3.new(PAD - 0.2, 0.1, 0.3), L.Brass, M.Metal, Craft.DECOR)
	end
	if not locked then
		new("PointLight", { Color = color, Range = 12, Brightness = 0.9, Shadows = false }, glow)
	end

	-- The sign, styled like the lobby's own: mahogany board, cream face, brass trim and legs.
	local signCenter = center + Vector3.new(0, 5.6, -PAD / 2 - 0.3)
	for _, side in { -1, 1 } do
		Craft.cylinder(model, center + Vector3.new(side * 3.3, 1.8, -PAD / 2 - 0.3), 3.6, 0.3, "Y", L.Brass, M.Metal)
	end
	Craft.block(model, CFrame.new(signCenter), Vector3.new(PAD + 0.4, 4.4, 0.4), L.PanelDark, M.Wood)
	Craft.block(model, CFrame.new(signCenter + Vector3.new(0, 2.3, 0.05)), Vector3.new(PAD + 0.6, 0.25, 0.5), L.Brass, M.Metal, Craft.DECOR)
	Craft.block(model, CFrame.new(signCenter + Vector3.new(0, 1.55, 0.25)), Vector3.new(PAD - 0.6, 0.08, 0.05), tone(color, 0.2), M.Neon, Craft.DECOR) -- a thin glowing line in the map's color
	local face = Craft.block(model, CFrame.new(signCenter + Vector3.new(0, -0.1, 0.22)), Vector3.new(PAD - 0.4, 3.6, 0.06), if locked then L.Plaster else L.Cream, Enum.Material.SmoothPlastic, Craft.DECOR)
	local gui = new("SurfaceGui", {
		Face = Enum.NormalId.Back, -- +Z, toward the players
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50,
		LightInfluence = 0.25, -- a little of the lobby's warm light, so it sits in the room
	}, face)
	local function line(text: string, y: number, height: number, textColor: Color3): TextLabel
		return new("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.05, y),
			Size = UDim2.fromScale(0.9, height),
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = textColor,
			Text = text,
		}, gui)
	end
	line(`{def.icon or ""} {string.upper(def.title)}`, 0.06, 0.32, if locked then L.PanelDark else tone(color, 0.45))
	local votesLabel = line(if locked then `\u{1F512} Needs {minimumFor(def)} players` else "0 votes", 0.44, 0.28, L.PanelDark)
	line(if locked then "Invite a friend to play this one!" else "Stand here to vote!", 0.76, 0.17, L.Panel)

	model.Parent = workspace
	return { def = def, locked = locked, model = model, glow = glow, center = center, votesLabel = votesLabel }
end

-- Slides models up out of the stage (or back down into it) with a little bounce.
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
		if not pads[i].locked then
			pads[i].votesLabel.Text = if n == 1 then "1 vote" else `{n} votes`
		end
	end
end

-- Who's standing on which pad.
local function track()
	while counting do
		local changed = false
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local root = Util.rootPart(player)
			if root and Util.aliveHumanoid(player) then
				for i, pad in pads do
					local offset = root.Position - pad.center
					if math.abs(offset.X) <= PAD / 2 and math.abs(offset.Z) <= PAD / 2 and offset.Y > -1 and offset.Y < 7 then
						if pad.locked then
							if now - (warned[player] or 0) > 3 then
								warned[player] = now
								Remotes.fire(player, "Announce", { text = `{pad.def.title} needs {minimumFor(pad.def)} players. Pick another map!`, color = Colors.Paper })
							end
						elseif votes[player] ~= i then
							votes[player] = i
							changed = true
							Util.playSound("TallyClick", pad.glow)
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

function Vote.open(choices: { Choice })
	Vote.cancel()
	local O = Config.Pod.origin
	local models = {}
	for i, choice in choices do
		local x = (i - (#choices + 1) / 2) * STAGE.spacing
		local pad = buildPad(choice, O + Vector3.new(x, STAGE.height, STAGE.z))
		pad.model:PivotTo(pad.model:GetPivot() - Vector3.new(0, RISE, 0)) -- start down inside the stage
		table.insert(pads, pad)
		table.insert(models, pad.model)
	end
	Util.soundAt("Rumble", O + Vector3.new(0, 1, STAGE.z))
	Remotes.fireAll("Announce", { text = "Vote for the next map! Stand on one at the MAP VOTE stage.", color = Colors.Gold })
	slide(models, true)
	counting = true
	task.spawn(track)
end

-- Ends the vote: returns the winning map (its Config.Levels entry), or nil if nothing was open.
function Vote.close(): any?
	counting = false
	local list = counts()
	local best = -1
	local tied = {}
	for i, n in list do
		if not pads[i].locked then
			if n > best then
				best = n
				tied = { i }
			elseif n == best then
				table.insert(tied, i)
			end
		end
	end
	if #tied == 0 then
		Vote.cancel()
		return nil
	end
	local winnerIndex = tied[math.random(1, #tied)]
	local winner = pads[winnerIndex]
	Remotes.fireAll("Announce", { text = `Next map: {winner.def.title}!`, color = winner.def.color })

	-- The others sink back into the stage; the winner flashes.
	local losers = {}
	for i, pad in pads do
		if i ~= winnerIndex then
			table.insert(losers, pad.model)
		end
	end
	task.spawn(slide, losers, false)
	for _ = 1, 4 do
		winner.glow.Transparency = 0.1
		task.wait(0.15)
		winner.glow.Transparency = 0.6
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
	warned[player] = nil
	if counting and #pads > 0 then
		refreshLabels()
	end
end)

return Vote
