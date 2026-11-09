-- Round loop: players wait in the hub and vote for the next map by standing on its pad at the voting
-- stage (server/Vote.luau); everyone in the server plays the winner, then results, then back to the hub.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Doll = require(script.Doll)
local Gear = require(script.Gear)
local Mood = require(script.Mood)
local Remotes = require(script.Remotes)
local RoundControl = require(script.RoundControl)
local Admin = require(script.Admin)
local Codes = require(script.Codes)
local Daily = require(script.Daily)
local Data = require(script.Data)
local Leaderboards = require(script.Leaderboards)
local Score = require(script.Score)
local Spectate = require(script.Spectate)
local Util = require(script.Util)
local Vote = require(script.Vote)
local Pod = require(script.Levels.HotelLobby) -- the hub; swap back to script.Levels.Pod for the old toybox

local levelModules = {
	BombHotel = require(script.Levels.BombHotel),
	SharkSurvival = require(script.Levels.SharkSurvival),
	KillerHotel = require(script.Levels.KillerHotel),
	HideAndSeek = require(script.Levels.HideAndSeek),
}

Players.RespawnTime = 3
workspace.Gravity = Config.Gravity
Mood.start() -- dark, foggy, flickering: the horror look

local function setStatus(text: string, timeLeft: number?)
	ReplicatedStorage:SetAttribute("Status", text)
	ReplicatedStorage:SetAttribute("TimeLeft", timeLeft or 0)
end

Data.start() -- saving; must start before anyone's profile loads

local nextColor = 0
local function setupPlayer(player: Player)
	nextColor += 1
	player:SetAttribute("Color", Config.PlayerColors[(nextColor - 1) % #Config.PlayerColors + 1])

	-- Banned on any server? (Admins can't be banned, so a mistake can always be undone.)
	if not Admin.isAdmin(player) then
		local reason = Data.banReason(player.UserId)
		if reason then
			player:Kick(`You are banned from Stitch Survival: {reason}`)
			return
		end
	end

	-- Their save: Stickers, Wins, passives, look, codes, challenges. (Yields; nil if they left meanwhile.)
	local profile = Data.load(player)
	if not profile then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = profile.wins
	wins.Parent = leaderstats

	local stickers = Instance.new("IntValue")
	stickers.Name = "Stickers"
	stickers.Value = profile.stickers
	stickers.Parent = leaderstats

	player:SetAttribute("OwnedGear", if profile.ownedGear ~= "" then profile.ownedGear else nil)
	if profile.gear then
		player:SetAttribute("Gear", profile.gear)
		Gear.apply(player)
	end
	player:SetAttribute("Look", profile.look)
	leaderstats.Parent = player
	Daily.playerReady(player)
end
Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(setupPlayer, player)
end

local pod = Pod.build()
Doll.start()
Gear.start(pod.machine)
Admin.start(pod)
Codes.start()
Daily.start()
Leaderboards.start()
Spectate.start()

local function sendToPod(player: Player)
	local character = player.Character
	if character and Util.aliveHumanoid(player) then
		character:PivotTo(pod.spawn.CFrame + Vector3.new(math.random(-3, 3), 4, 0))
	end
end

-- The client changes music and plays transition sounds based on this:
-- Intermission -> Loading -> Countdown -> Playing -> Results -> Intermission ...
local function setPhase(phase: string)
	ReplicatedStorage:SetAttribute("Phase", phase)
end

-- Waits a second, but returns true right away if an admin pressed "Start now".
local function waitSecond(): boolean
	for _ = 1, 10 do
		if RoundControl.skipIntermission then
			return true
		end
		task.wait(0.1)
	end
	return false
end

-- Between rounds: a short break, then the map vote at the voting stage. Returns the winning map's
-- Config.Levels entry, or nil if an admin started a round instead.
local function intermission(): any?
	setPhase("Intermission")
	for t = Config.Vote.breakSeconds, 1, -1 do
		setStatus("Next map vote in", t)
		if waitSecond() then
			return nil
		end
	end
	while #Players:GetPlayers() < Config.MinPlayers do
		setStatus("Waiting for players...")
		if waitSecond() then
			return nil
		end
	end

	local choices = Vote.choices(#Players:GetPlayers())
	if #choices == 0 then
		return nil
	end
	Vote.open(choices)
	for t = Config.Vote.seconds, 1, -1 do
		setStatus("Vote for the next map!", t)
		if waitSecond() then
			Vote.cancel()
			return nil
		end
	end
	setStatus("Counting the votes...")
	return Vote.close()
end

local function setFrozen(players: { Player }, frozen: boolean)
	for _, player in players do
		local root = Util.rootPart(player)
		if root then
			root.Anchored = frozen
		end
	end
end

-- Stops everything in place at the end of a round: hazards, debris, and the survivors.
local function freezeWorld(level, stage, survivors: { Player })
	if level.freeze then
		level.freeze(stage)
	end
	for _, part in CollectionService:GetTagged("LooseDebris") do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.Anchored = true
		end
	end
	setFrozen(survivors, true)
end

local function playRound(def)
	local level = levelModules[def.name]
	-- A level may set its own round length (def.roundTime) and may define these optional hooks:
	--   level.begin(stage, participants)    after everyone is sent in, before the countdown (hand out roles)
	--   level.isOver(stage, alive)          true to end the round early (a team has won)
	--   level.finish(stage, alive)          { winners = { [Player]: true }, text = string } when the round ends
	local roundTime = def.roundTime or Config.RoundTime
	-- Everyone in the server plays.
	local queued = Players:GetPlayers()

	-- Loading: the music dips while the new level tips out of the toybox.
	setPhase("Loading")
	setStatus(`Loading {def.title}...`)
	local stage = level.build(def)
	RoundControl.levelName = def.name
	RoundControl.stage = stage
	Score.reset()
	task.wait(Config.LoadingTime)

	-- Send everyone who's alive into the level (pop-pop-pop).
	local participants: { Player } = {}
	local alive: { [Player]: boolean } = {}
	local connections = {}
	for _, player in queued do
		local humanoid = Util.aliveHumanoid(player)
		if player.Parent and humanoid and player.Character then
			table.insert(participants, player)
			alive[player] = true
			player:SetAttribute("InRound", true) -- spectators can watch you (client/Spectate.luau)
			local spawnAt = stage.spawns[(#participants - 1) % #stage.spawns + 1]
			if humanoid.Sit then
				humanoid.Sit = false -- off any lobby sofa first
			end
			player.Character:PivotTo(spawnAt)
			Remotes.fireAll("Teleport", { position = spawnAt.Position, color = player:GetAttribute("Color") })
			table.insert(connections, humanoid.Died:Connect(function()
				alive[player] = nil
				player:SetAttribute("InRound", nil)
				local root = Util.rootPart(player)
				if root then
					Remotes.fireAll("Poof", { position = root.Position, color = player:GetAttribute("Color") })
				end
				Remotes.fireAll("Announce", { text = `{player.DisplayName} got popped!`, color = player:GetAttribute("Color") })
			end))
		end
	end
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		alive[player] = nil
	end))

	if level.begin then
		level.begin(stage, participants)
	end

	-- Countdown with everyone frozen in place.
	setPhase("Countdown")
	setFrozen(participants, true)
	Remotes.fireAll("LevelIntro", { title = def.title })
	setStatus(def.title)
	task.wait(1.5)
	for n = Config.CountdownTime, 1, -1 do
		Remotes.fireAll("Countdown", { text = tostring(n) })
		task.wait(1)
	end
	Remotes.fireAll("Countdown", { text = "GO!" })
	setFrozen(participants, false)
	setPhase("Playing")

	local startTime = os.clock()
	local active = true
	local ctx = {
		isActive = function()
			return active
		end,
		progress = function()
			return math.clamp((os.clock() - startTime) / roundTime, 0, 1)
		end,
	}
	stage.ctx = ctx -- the admin panel's "spawn a shark" needs it
	task.spawn(level.run, stage, ctx)

	local nextTick = startTime + 1
	while active do
		local timeLeft = roundTime - (os.clock() - startTime)
		setStatus(def.title, math.max(0, math.ceil(timeLeft)))

		if os.clock() >= nextTick then
			nextTick += 1
			for player in alive do
				Score.add(player, Config.SurvivalPointsPerSecond)
			end
			Score.decay()
		end

		for player in alive do
			local root = Util.rootPart(player)
			local humanoid = Util.aliveHumanoid(player)
			if root and humanoid and root.Position.Y < stage.killY then
				if not Util.kill(humanoid) and player.Character then
					-- God mode: fell out of the level, so pop back to the start instead.
					player.Character:PivotTo(stage.spawns[1])
				end
			end
		end

		if timeLeft <= 0 or next(alive) == nil or RoundControl.endRound or (level.isOver and level.isOver(stage, alive)) then
			RoundControl.endRound = false
			active = false
		end
		task.wait(0.2)
	end

	for _, connection in connections do
		connection:Disconnect()
	end

	-- The freeze: a clean click, the world stops, and the sound drops away.
	local survivors: { Player } = {}
	for player in alive do
		table.insert(survivors, player)
	end
	setPhase("Results")
	freezeWorld(level, stage, survivors)
	local outcome = if level.finish then level.finish(stage, alive) else nil

	-- Results: survivors get a bonus, everyone turns points into Stickers.
	local entries = {}
	local anySurvived = false
	for _, player in participants do
		player:SetAttribute("InRound", nil)
		if player.Parent then
			local survived = if outcome then outcome.winners[player] == true else alive[player] == true
			if survived then
				anySurvived = true
				Score.add(player, Config.SurviveBonus)
			end
			local score = Score.get(player)
			local earned = math.floor(score / Config.PointsPerSticker)
			Data.giveStickers(player, earned, true)
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats and survived then
				leaderstats.Wins.Value += 1
			end
			-- Lifetime stats (leaderboards) and today's challenges.
			local hunterWon = survived and stage.killer == player
			Data.addStat(player, "roundsPlayed", 1)
			Daily.track(player, "roundsPlayed", 1)
			Daily.track(player, "points", score)
			if survived then
				Data.addStat(player, "roundsSurvived", 1)
				Daily.track(player, "roundsSurvived", 1)
				if not hunterWon then
					Daily.track(player, `survive_{def.name}`, 1)
				end
			end
			if hunterWon then
				Data.addStat(player, "hunterWins", 1)
				Daily.track(player, "hunterWins", 1)
			end
			table.insert(entries, {
				name = player.DisplayName,
				score = score,
				survived = survived,
				stickers = earned,
				color = player:GetAttribute("Color"),
			})
			if survived then
				-- Fanfare overhead and a rain of plastic tokens.
				Remotes.fire(player, "Victory", { stickers = earned })
			end
		end
	end
	table.sort(entries, function(a, b)
		return a.score > b.score
	end)

	setStatus(if outcome then outcome.text elseif anySurvived then "Level complete!" else "Everyone got popped!")
	Remotes.fireAll("Results", { title = def.title, entries = entries })
	task.wait(Config.ResultsTime)

	for _, player in survivors do
		sendToPod(player)
	end
	setFrozen(survivors, false)
	if level.cleanup then
		level.cleanup(stage)
	end
	stage.model:Destroy()
	RoundControl.levelName = nil
	RoundControl.stage = nil
end

-- An admin pressed "Start now": the chosen level (or a random one), no vote.
local function adminPick()
	RoundControl.skipIntermission = false
	local def = Util.weightedPick(Config.Levels)
	for _, candidate in Config.Levels do
		if candidate.name == RoundControl.forceLevel then
			def = candidate
		end
	end
	RoundControl.forceLevel = nil
	return def
end

while true do
	local def = intermission()
	if RoundControl.skipIntermission then
		def = adminPick()
	end
	if def then
		playRound(def)
	end
end
