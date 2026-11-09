-- Daily challenges (Config.Daily). Each day (midnight UTC to midnight UTC) every player gets their own
-- Config.Daily.count challenges, picked from the list with a seed made of the day and their account, so they
-- get the same three if they rejoin, and a friend gets different ones.
--
-- Other server code reports what happened with Daily.track(player, stat, amount): "roundsPlayed",
-- "bubbles", "stuns"... Progress, the picks and what's been claimed are saved in the player's profile
-- (server/Data.luau). The client is told through the "Daily" attribute (JSON) and asks to claim a finished
-- challenge with the ClaimDaily remote; the server checks it's really finished before paying.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.Data)
local Remotes = require(script.Parent.Remotes)

local Daily = {}

local DAY = 86400
local byId = {}
for _, challenge in Config.Daily.challenges do
	byId[challenge.id] = challenge
end

local lastClaim: { [Player]: number } = {}

local function today(): number
	return os.time() // DAY
end

-- Today's picks for this player (a fresh set when the day has turned over).
local function ensureToday(player: Player, profile: Data.Profile)
	local day = today()
	local daily = profile.daily
	if daily.day == day and #daily.picks > 0 then
		return
	end
	local pool = table.clone(Config.Daily.challenges)
	local rng = Random.new(day * 1000003 + player.UserId)
	local picks = {}
	for _ = 1, math.min(Config.Daily.count, #pool) do
		local index = rng:NextInteger(1, #pool)
		table.insert(picks, pool[index].id)
		table.remove(pool, index)
	end
	profile.daily = { day = day, picks = picks, progress = {}, claimed = {} }
end

-- Tells the player's client their challenges.
local function publish(player: Player)
	local profile = Data.get(player)
	if not profile then
		return
	end
	ensureToday(player, profile)
	local items = {}
	for _, id in profile.daily.picks do
		local challenge = byId[id]
		if challenge then
			table.insert(items, {
				id = id,
				text = challenge.text,
				goal = challenge.goal,
				reward = challenge.reward,
				progress = math.min(challenge.goal, profile.daily.progress[id] or 0),
				claimed = profile.daily.claimed[id] == true,
			})
		end
	end
	player:SetAttribute("Daily", HttpService:JSONEncode({ day = profile.daily.day, items = items }))
end

-- Something happened that challenges might count: `stat` went up by `amount` for this player.
function Daily.track(player: Player, stat: string, amount: number?)
	local profile = Data.get(player)
	if not profile then
		return
	end
	ensureToday(player, profile)
	local changed = false
	for _, id in profile.daily.picks do
		local challenge = byId[id]
		if challenge and challenge.stat == stat and not profile.daily.claimed[id] then
			local before = profile.daily.progress[id] or 0
			if before < challenge.goal then
				local after = math.min(challenge.goal, before + (amount or 1))
				profile.daily.progress[id] = after
				changed = true
				if after >= challenge.goal then
					Remotes.fire(player, "Announce", {
						text = `Daily challenge done: {challenge.text}! Open DAILY to claim +{challenge.reward}`,
						color = Config.Colors.Gold,
					})
					Remotes.fire(player, "DailyReady", { id = id })
				end
			end
		end
	end
	if changed then
		publish(player)
	end
end

local function claim(player: Player, id: any)
	if type(id) ~= "string" then
		return
	end
	local now = os.clock()
	if lastClaim[player] and now - lastClaim[player] < 0.5 then
		return
	end
	lastClaim[player] = now
	local profile = Data.get(player)
	local challenge = byId[id]
	if not profile or not challenge then
		return
	end
	ensureToday(player, profile)
	if not table.find(profile.daily.picks, id) or profile.daily.claimed[id] then
		return
	end
	if (profile.daily.progress[id] or 0) < challenge.goal then
		return
	end
	profile.daily.claimed[id] = true
	Data.giveStickers(player, challenge.reward, true)
	Remotes.fire(player, "DailyClaimed", { id = id, reward = challenge.reward })
	publish(player)
end

-- Call once the player's profile has loaded.
function Daily.playerReady(player: Player)
	publish(player)
end

function Daily.start()
	Remotes.ClaimDaily.OnServerEvent:Connect(claim)
	Players.PlayerRemoving:Connect(function(player)
		lastClaim[player] = nil
	end)
	-- A new day starts while people are playing: hand out the new challenges.
	task.spawn(function()
		local day = today()
		while true do
			task.wait(30)
			if today() ~= day then
				day = today()
				for _, player in Players:GetPlayers() do
					publish(player)
				end
			end
		end
	end)
end

return Daily
