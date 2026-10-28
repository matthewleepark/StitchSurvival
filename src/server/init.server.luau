-- Round loop: wait in the Pod, then a random survival level, then results.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Doll = require(script.Doll)
local Gear = require(script.Gear)
local Remotes = require(script.Remotes)
local Score = require(script.Score)
local Util = require(script.Util)
local Pod = require(script.Levels.Pod)

local levelModules = {
	BombHotel = require(script.Levels.BombHotel),
	SharkSurvival = require(script.Levels.SharkSurvival),
}

Players.RespawnTime = 3

local function setStatus(text: string, timeLeft: number?)
	ReplicatedStorage:SetAttribute("Status", text)
	ReplicatedStorage:SetAttribute("TimeLeft", timeLeft or 0)
end

local nextColor = 0
local function setupPlayer(player: Player)
	nextColor += 1
	player:SetAttribute("Color", Config.PlayerColors[(nextColor - 1) % #Config.PlayerColors + 1])

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = leaderstats

	local stickers = Instance.new("IntValue")
	stickers.Name = "Stickers"
	stickers.Value = Config.StartingStickers
	stickers.Parent = leaderstats

	leaderstats.Parent = player
end
Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

local pod = Pod.build()
Doll.start()
Gear.start(pod.machine)

local function sendToPod(player: Player)
	local character = player.Character
	if character and Util.aliveHumanoid(player) then
		character:PivotTo(pod.spawn.CFrame + Vector3.new(math.random(-3, 3), 4, 0))
	end
end

local function intermission()
	for t = Config.IntermissionTime, 1, -1 do
		if #Players:GetPlayers() < Config.MinPlayers then
			setStatus("Waiting for players...")
			repeat
				task.wait(1)
			until #Players:GetPlayers() >= Config.MinPlayers
		end
		setStatus("Next level in", t)
		task.wait(1)
	end
end

local function setFrozen(players: { Player }, frozen: boolean)
	for _, player in players do
		local root = Util.rootPart(player)
		if root then
			root.Anchored = frozen
		end
	end
end

local function playRound()
	local def = Util.weightedPick(Config.Levels)
	local level = levelModules[def.name]
	local stage = level.build(def)
	Score.reset()

	-- Send everyone who's alive into the level.
	local participants: { Player } = {}
	local alive: { [Player]: boolean } = {}
	local connections = {}
	for _, player in Players:GetPlayers() do
		local humanoid = Util.aliveHumanoid(player)
		if humanoid and player.Character then
			table.insert(participants, player)
			alive[player] = true
			player.Character:PivotTo(stage.spawns[(#participants - 1) % #stage.spawns + 1])
			table.insert(connections, humanoid.Died:Connect(function()
				alive[player] = nil
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

	-- Countdown with everyone frozen in place.
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

	local startTime = os.clock()
	local active = true
	local ctx = {
		isActive = function()
			return active
		end,
		progress = function()
			return math.clamp((os.clock() - startTime) / Config.RoundTime, 0, 1)
		end,
	}
	task.spawn(level.run, stage, ctx)

	local nextTick = startTime + 1
	while active do
		local timeLeft = Config.RoundTime - (os.clock() - startTime)
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
				humanoid.Health = 0
			end
		end

		if timeLeft <= 0 or next(alive) == nil then
			active = false
		end
		task.wait(0.2)
	end

	for _, connection in connections do
		connection:Disconnect()
	end

	-- Results: survivors get a bonus, everyone turns points into Stickers.
	local entries = {}
	local anySurvived = false
	for _, player in participants do
		if player.Parent then
			local survived = alive[player] == true
			if survived then
				anySurvived = true
				Score.add(player, Config.SurviveBonus)
			end
			local score = Score.get(player)
			local earned = math.floor(score / Config.PointsPerSticker)
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				leaderstats.Stickers.Value += earned
				if survived then
					leaderstats.Wins.Value += 1
				end
			end
			table.insert(entries, {
				name = player.DisplayName,
				score = score,
				survived = survived,
				stickers = earned,
				color = player:GetAttribute("Color"),
			})
		end
	end
	table.sort(entries, function(a, b)
		return a.score > b.score
	end)

	setStatus(if anySurvived then "Level complete!" else "Everyone got popped!")
	Remotes.fireAll("Results", { title = def.title, entries = entries })
	task.wait(Config.ResultsTime)

	for player in alive do
		sendToPod(player)
	end
	if level.cleanup then
		level.cleanup(stage)
	end
	stage.model:Destroy()
end

while true do
	intermission()
	playRound()
end
