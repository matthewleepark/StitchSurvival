-- Saving progress between visits (DataStoreService). One saved profile per player:
--   stickers, wins, ownedGear, gear (equipped), look ("doll" / "avatar"),
--   codes   { CODE = true }          promo codes already used (each works once, ever)
--   stats   { name = number }        lifetime counts for the leaderboards (stickersEarned, roundsPlayed, ...)
--   daily   { day, picks, progress, claimed }   today's challenges (server/Daily.luau)
--
-- While you play, the live values are the usual ones: leaderstats.Stickers / Wins and the OwnedGear, Gear and
-- Look attributes. They're copied into the profile when it's saved: when you leave, every
-- Config.Save.autosaveSeconds, and when the server shuts down.
--
-- If the DataStore can't be reached:
--   * In Studio without "Enable Studio Access to API Services", or in a place that was never published, the
--     game runs "offline": nothing is loaded or saved and the leaderboards show only this server.
--   * If loading a real save fails (Roblox is having trouble), that player's profile is NOT saved this visit,
--     so a temporary failure can never overwrite their real progress with a blank one. They're told so.
--
-- Bans are kept in their own store, so a banned player stays banned on every server (server/Admin.luau).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)

local Data = {}

export type Profile = {
	stickers: number,
	wins: number,
	ownedGear: string,
	gear: string?,
	look: string,
	codes: { [string]: boolean },
	stats: { [string]: number },
	daily: { day: number, picks: { string }, progress: { [string]: number }, claimed: { [string]: boolean } },
	-- Not saved:
	canSave: boolean,
	pushed: { [string]: number }, -- leaderboard values last sent, so unchanged ones aren't sent again
}

local profiles: { [Player]: Profile } = {}
local offline = false
local warned = false
local store: DataStore? = nil
local banStore: DataStore? = nil
local ordered: { [string]: OrderedDataStore } = {}
local memoryBans: { [number]: string } = {} -- offline bans, for this server only

-- The stats the leaderboards rank by.
local function leaderboardStats(): { string }
	local list = {}
	for _, board in Config.Leaderboards.boards do
		for _, category in board do
			table.insert(list, category.stat)
		end
	end
	return list
end

local function goOffline(reason: string)
	offline = true
	if not warned then
		warned = true
		warn(`[Data] Saving is OFF ({reason}). In Studio turn on Home > Game Settings > Security > "Enable Studio Access to API Services" to test saving.`)
	end
end

-- Errors that mean "DataStores can't work here at all" (rather than "try again").
local function isOfflineError(message: string): boolean
	local lower = string.lower(message)
	return string.find(lower, "studio", 1, true) ~= nil
		or string.find(lower, "publish", 1, true) ~= nil
		or string.find(lower, "not allowed", 1, true) ~= nil
		or string.find(lower, "403", 1, true) ~= nil
end

-- Runs a DataStore call, retrying a couple of times. Returns ok, result.
local function call<T>(what: string, attempts: number, fn: () -> T): (boolean, T?)
	if offline then
		return false, nil
	end
	local lastError = ""
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = tostring(result)
		if isOfflineError(lastError) then
			goOffline(lastError)
			return false, nil
		end
		if attempt < attempts then
			task.wait(attempt)
		end
	end
	warn(`[Data] {what} failed: {lastError}`)
	return false, nil
end

local function blankProfile(): Profile
	return {
		stickers = Config.StartingStickers,
		wins = 0,
		ownedGear = "",
		gear = nil,
		look = Config.Look.default,
		codes = {},
		stats = {},
		daily = { day = -1, picks = {}, progress = {}, claimed = {} },
		canSave = true,
		pushed = {},
	}
end

-- Fills a profile from saved data, keeping defaults for anything missing (older saves, new fields).
local function fromSaved(saved: any): Profile
	local profile = blankProfile()
	if type(saved) ~= "table" then
		return profile
	end
	if type(saved.stickers) == "number" then
		profile.stickers = math.max(0, math.floor(saved.stickers))
	end
	if type(saved.wins) == "number" then
		profile.wins = math.max(0, math.floor(saved.wins))
	end
	if type(saved.ownedGear) == "string" then
		profile.ownedGear = saved.ownedGear
	end
	if type(saved.gear) == "string" and Config.getGear(saved.gear) then
		profile.gear = saved.gear
	end
	if saved.look == "doll" or saved.look == "avatar" then
		profile.look = saved.look
	end
	if type(saved.codes) == "table" then
		for code, used in saved.codes do
			if type(code) == "string" and used == true then
				profile.codes[code] = true
			end
		end
	end
	if type(saved.stats) == "table" then
		for name, value in saved.stats do
			if type(name) == "string" and type(value) == "number" then
				profile.stats[name] = value
			end
		end
	end
	local daily = saved.daily
	if type(daily) == "table" and type(daily.day) == "number" then
		profile.daily.day = daily.day
		profile.daily.picks = if type(daily.picks) == "table" then daily.picks else {}
		profile.daily.progress = if type(daily.progress) == "table" then daily.progress else {}
		profile.daily.claimed = if type(daily.claimed) == "table" then daily.claimed else {}
	end
	-- Leaderboard numbers already sent for this player don't need sending again.
	for _, stat in leaderboardStats() do
		profile.pushed[stat] = Data.statOf(profile, stat)
	end
	return profile
end

-- Copies the live values (leaderstats, attributes) into the profile.
local function capture(player: Player, profile: Profile)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stickers = leaderstats and leaderstats:FindFirstChild("Stickers") :: IntValue?
	local wins = leaderstats and leaderstats:FindFirstChild("Wins") :: IntValue?
	if stickers then
		profile.stickers = stickers.Value
	end
	if wins then
		profile.wins = wins.Value
	end
	profile.ownedGear = (player:GetAttribute("OwnedGear") :: string?) or ""
	profile.gear = player:GetAttribute("Gear") :: string?
	local look = player:GetAttribute("Look")
	if look == "doll" or look == "avatar" then
		profile.look = look
	end
end

local function key(userId: number): string
	return `player_{userId}`
end

-- A leaderboard stat's value for a profile ("wins" is the Wins leaderstat; the rest live in stats).
function Data.statOf(profile: Profile, stat: string): number
	if stat == "wins" then
		return profile.wins
	end
	return profile.stats[stat] or 0
end

function Data.isOffline(): boolean
	return offline
end

-- Loads a player's profile (yields). Returns nil if they left while it loaded.
function Data.load(player: Player): Profile?
	local profile
	if store and not offline then
		local ok, saved = call(`loading {player.Name}`, 3, function()
			return (store :: DataStore):GetAsync(key(player.UserId))
		end)
		if ok then
			profile = fromSaved(saved)
		else
			profile = blankProfile()
			if not offline then
				-- A real failure, not "saving is off": never save over their real progress this visit.
				profile.canSave = false
				task.delay(5, function()
					if player.Parent then
						Remotes.fire(player, "Announce", { text = "Couldn't load your save. Progress this visit won't be saved, sorry!", color = Config.Colors.Felt })
					end
				end)
			end
		end
	else
		profile = blankProfile()
	end
	if not player.Parent then
		return nil
	end
	profiles[player] = profile
	return profile
end

-- The loaded profile, or nil if it isn't loaded yet.
function Data.get(player: Player): Profile?
	return profiles[player]
end

-- Adds to a lifetime stat (leaderboards, daily challenges read these).
function Data.addStat(player: Player, stat: string, amount: number)
	local profile = profiles[player]
	if profile then
		profile.stats[stat] = (profile.stats[stat] or 0) + amount
	end
end

-- Gives Stickers. `earned` = counts toward the "most stickers earned" leaderboard (admin gifts don't).
function Data.giveStickers(player: Player, amount: number, earned: boolean)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stickers = leaderstats and leaderstats:FindFirstChild("Stickers") :: IntValue?
	if stickers and amount > 0 then
		stickers.Value += amount
		if earned then
			Data.addStat(player, "stickersEarned", amount)
		end
	end
end

-- Sends any changed leaderboard numbers to the ordered stores.
local function pushLeaderboards(player: Player, profile: Profile)
	for _, stat in leaderboardStats() do
		local value = math.floor(Data.statOf(profile, stat))
		local orderedStore = ordered[stat]
		if orderedStore and value > 0 and profile.pushed[stat] ~= value then
			local ok = call(`leaderboard {stat}`, 2, function()
				orderedStore:SetAsync(tostring(player.UserId), value)
				return true
			end)
			if ok then
				profile.pushed[stat] = value
			end
		end
	end
end

function Data.save(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	capture(player, profile)
	if offline or not store or not profile.canSave then
		return
	end
	local saved = {
		stickers = profile.stickers,
		wins = profile.wins,
		ownedGear = profile.ownedGear,
		gear = profile.gear,
		look = profile.look,
		codes = profile.codes,
		stats = profile.stats,
		daily = profile.daily,
	}
	call(`saving {player.Name}`, 3, function()
		return (store :: DataStore):UpdateAsync(key(player.UserId), function()
			return saved
		end)
	end)
	pushLeaderboards(player, profile)
end

-- The top `count` of a leaderboard stat from every server: { { userId, value } }. Nil when offline or failing.
function Data.top(stat: string, count: number): { { userId: number, value: number } }?
	local orderedStore = ordered[stat]
	if offline or not orderedStore then
		return nil
	end
	local ok, pages = call(`reading leaderboard {stat}`, 1, function()
		return orderedStore:GetSortedAsync(false, count)
	end)
	if not ok or not pages then
		return nil
	end
	local list = {}
	for _, entry in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(list, { userId = userId, value = entry.value })
		end
	end
	return list
end

-- Bans -------------------------------------------------------------------------------------------------

-- The ban reason if this account is banned, else nil.
function Data.banReason(userId: number): string?
	if memoryBans[userId] then
		return memoryBans[userId]
	end
	if offline or not banStore then
		return nil
	end
	local ok, entry = call("checking a ban", 2, function()
		return (banStore :: DataStore):GetAsync(tostring(userId))
	end)
	if ok and type(entry) == "table" and type(entry.reason) == "string" then
		return entry.reason
	end
	return nil
end

-- Bans (reason) or unbans (nil) an account on every server. Returns whether it was saved everywhere
-- (offline it only lasts on this server).
function Data.setBan(userId: number, reason: string?, by: string): boolean
	if reason then
		memoryBans[userId] = reason
	else
		memoryBans[userId] = nil
	end
	if offline or not banStore then
		return false
	end
	local ok = call("saving a ban", 3, function()
		if reason then
			(banStore :: DataStore):SetAsync(tostring(userId), { reason = reason, by = by, at = os.time() })
		else
			(banStore :: DataStore):RemoveAsync(tostring(userId))
		end
		return true
	end)
	return ok
end

-- Start-up ---------------------------------------------------------------------------------------------

function Data.start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Save.storeName)
	end)
	if ok then
		store = result
		local banOk, bans = pcall(function()
			return DataStoreService:GetDataStore(`{Config.Save.storeName}_Bans`)
		end)
		banStore = if banOk then bans else nil
		for _, stat in leaderboardStats() do
			local orderedOk, orderedStore = pcall(function()
				return DataStoreService:GetOrderedDataStore(`{Config.Save.storeName}_Top_{stat}`)
			end)
			if orderedOk then
				ordered[stat] = orderedStore
			end
		end
	else
		goOffline(tostring(result))
	end

	Players.PlayerRemoving:Connect(function(player)
		Data.save(player)
		profiles[player] = nil
	end)

	-- Autosave, a few players at a time so it never bursts the request budget.
	task.spawn(function()
		while true do
			task.wait(Config.Save.autosaveSeconds)
			for _, player in Players:GetPlayers() do
				if profiles[player] then
					task.spawn(Data.save, player)
					task.wait(1)
				end
			end
		end
	end)

	-- The server is shutting down: save everyone, and wait for it (Roblox allows about 30 seconds).
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			if profiles[player] then
				pending += 1
				task.spawn(function()
					Data.save(player)
					pending -= 1
				end)
			end
		end
		local waited = 0
		while pending > 0 and waited < 25 do
			waited += task.wait(0.2)
		end
	end)
end

return Data
