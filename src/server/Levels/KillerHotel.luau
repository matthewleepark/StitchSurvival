-- Killer Hotel: one KILLER hunts everyone else (the INNOCENTS) with bombs.
--
--   * When a round starts, the server picks exactly one killer (weighted: every round you were not
--     the killer makes you a little likelier next time, Config.KillerHotel.killerPityWeight).
--     Each player is told only their OWN role (a private "Role" effect). Who the killer is lives only
--     in `stage.killer` on the server; nothing about it is a replicated attribute.
--   * The killer drops bombs (the "DropBomb" request). The server checks the role, the stock, the
--     cooldown and the round phase. Bombs are hidden: no timer number, no blink, no bell. Only the
--     killer gets a timer (a private "BombTimer" effect); everyone else can just hear the tick
--     (Config.Sounds.BombTick range), muffled through walls.
--   * The killer wins by getting every innocent before the round time (Config.Levels roundTime) runs
--     out. If any innocent is still alive at 0:00, the innocents win. If the killer leaves or is popped,
--     the innocents win; if every innocent leaves, the killer wins.
--
-- The building is a tall, wide, three-floor maze (Levels/KillerMaze.luau, layout in Levels/MazeLayout.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Parent.Remotes)
local RoundControl = require(script.Parent.Parent.RoundControl)
local Util = require(script.Parent.Parent.Util)
local Bombs = require(script.Parent.Bombs)
local KillerMaze = require(script.Parent.KillerMaze)
local KillerRooms = require(script.Parent.KillerRooms)

local KillerHotel = {}

local settings = Config.KillerHotel

-- Rounds since each player was last the killer (the pity counter). Only lives in server memory.
local roundsSinceKiller: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(player)
	roundsSinceKiller[player] = nil
end)

local function pickKiller(participants: { Player }): Player
	local total = 0
	local weights = {}
	for _, player in participants do
		local weight = 1 + settings.killerPityWeight * (roundsSinceKiller[player] or 0)
		weights[player] = weight
		total += weight
	end
	local roll = math.random() * total
	for _, player in participants do
		roll -= weights[player]
		if roll <= 0 then
			return player
		end
	end
	return participants[#participants]
end

local function innocentsStillIn(stage): number
	local count = 0
	for player in stage.innocents do
		if player.Parent and Util.aliveHumanoid(player) then
			count += 1
		end
	end
	return count
end

function KillerHotel.build(def)
	local stage = KillerMaze.build(def)
	stage.killer = nil :: Player? -- server only: never put this in an attribute
	stage.innocents = {} :: { [Player]: boolean }
	stage.hadInnocents = false
	stage.bombs = 0
	stage.lastDrop = 0
	stage.nextRestock = 0
	return stage
end

-- Called by the round loop once everyone is in the level (before the countdown): hand out the roles.
function KillerHotel.begin(stage, participants: { Player })
	local minimum = if settings.soloTest then 1 else 2
	if #participants < minimum then
		return -- no killer: isOver ends the round at once
	end

	local killer = pickKiller(participants)
	stage.killer = killer
	for _, player in participants do
		if player == killer then
			roundsSinceKiller[player] = 0
		else
			stage.innocents[player] = true
			roundsSinceKiller[player] = (roundsSinceKiller[player] or 0) + 1
		end
	end
	stage.hadInnocents = next(stage.innocents) ~= nil

	-- The killer starts in the middle of the ground floor; the innocents were spread over the hotel.
	if killer.Character then
		killer.Character:PivotTo(stage.killerSpawn)
	end
	stage.bombs = settings.startBombs

	-- Blasts, fire and falling blocks would also hurt the killer who dropped them, and the innocents have no
	-- way to fight back. An invisible ForceField makes the killer take no damage (Util.kill and Util.damage
	-- skip anyone who has one; if they fall out of the building the round loop puts them back).
	if settings.killerImmuneToOwnBombs and killer.Character then
		local shield = Instance.new("ForceField")
		shield.Name = "KillerShield"
		shield.Visible = false
		shield.Parent = killer.Character
	end

	Remotes.fire(killer, "Role", { role = "killer", seconds = settings.roleBannerSeconds, bombs = stage.bombs, max = settings.carryLimit })
	for player in stage.innocents do
		Remotes.fire(player, "Role", { role = "innocent", seconds = settings.roleBannerSeconds })
	end
	ReplicatedStorage:SetAttribute("InnocentsLeft", innocentsStillIn(stage))
end

-- The killer's own bombs can shatter the floor under them. Rather than lose the round to a fall, put them
-- back on the top floor if they drop out of the building (innocents who fall still die, as in Bomb Hotel).
local function rescueKiller(stage, ctx)
	while ctx.isActive() and not stage.frozen do
		local killer = stage.killer
		local root = killer and Util.rootPart(killer)
		if root and Util.aliveHumanoid(killer :: Player) and root.Position.Y < stage.origin.Y - 6 then
			local spawn = stage.spawns[math.random(1, #stage.spawns)]
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = spawn
		end
		task.wait(0.1)
	end
end

-- While the round is on: top up the killer's bombs and keep the "innocents left" count current.
function KillerHotel.run(stage, ctx)
	if settings.killerRescue then
		task.spawn(rescueKiller, stage, ctx)
	end
	stage.nextRestock = os.clock() + settings.restockSeconds
	while ctx.isActive() and not stage.frozen do
		ReplicatedStorage:SetAttribute("InnocentsLeft", innocentsStillIn(stage))

		local killer = stage.killer
		local now = os.clock()
		if stage.bombs >= settings.carryLimit then
			stage.nextRestock = now + settings.restockSeconds
		elseif now >= stage.nextRestock then
			stage.bombs += 1
			stage.nextRestock = now + settings.restockSeconds
			if killer then
				Remotes.fire(killer, "KillerBombs", { count = stage.bombs, max = settings.carryLimit })
			end
		end
		task.wait(0.5)
	end
end

-- True when the round should end now: nobody is hunting, the killer is gone, or no innocent is left.
function KillerHotel.isOver(stage, alive: { [Player]: boolean }): boolean
	local killer = stage.killer
	if not killer or not alive[killer] then
		return true
	end
	if stage.hadInnocents then
		for player in stage.innocents do
			if alive[player] then
				return false
			end
		end
		return true
	end
	return false -- solo test: nobody to catch, so run until the timer or an admin ends it
end

-- Who won, and what to say about it.
function KillerHotel.finish(stage, alive: { [Player]: boolean })
	local killer = stage.killer
	local winners: { [Player]: boolean } = {}
	local innocentsAlive = 0
	for player in stage.innocents do
		if alive[player] then
			winners[player] = true
			innocentsAlive += 1
		end
	end

	local text
	if not killer then
		table.clear(winners)
		text = "Killer Hotel needs two players"
	elseif not alive[killer] then
		text = if innocentsAlive > 0 then "The killer is out! Innocents win!" else "Nobody made it out"
	elseif stage.hadInnocents and innocentsAlive == 0 then
		table.clear(winners)
		winners[killer] = true
		text = "The killer got everyone!"
	else
		text = if innocentsAlive > 0 then "Time's up! The innocents survived!" else "Time's up"
	end

	if killer and killer.Parent then
		Remotes.fireAll("Announce", { text = `{killer.DisplayName} was the killer!`, color = killer:GetAttribute("Color") })
	end
	Remotes.fireAll("Role", { role = "none" })
	ReplicatedStorage:SetAttribute("InnocentsLeft", nil)
	stage.releaseHidden() -- everyone climbs out of the wardrobes
	local shield = killer and killer.Character and killer.Character:FindFirstChild("KillerShield")
	if shield then
		shield:Destroy()
	end
	return { winners = winners, text = text }
end

function KillerHotel.cleanup(stage)
	KillerRooms.cleanup(stage)
end

-- Round over: everything stops exactly where it is.
function KillerHotel.freeze(stage)
	stage.frozen = true
	for _, part in stage.model:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.Anchored = true
		end
	end
end

-- The killer's bomb button (the client binds Q / gamepad X / a touch button and sends this).
Remotes.DropBomb.OnServerEvent:Connect(function(player: Player)
	local stage = RoundControl.stage
	if RoundControl.levelName ~= "KillerHotel" or not stage or stage.frozen or stage.killer ~= player then
		return
	end
	if ReplicatedStorage:GetAttribute("Phase") ~= "Playing" then
		return
	end
	local humanoid = Util.aliveHumanoid(player)
	local root = Util.rootPart(player)
	if not humanoid or not root or not player.Character then
		return
	end
	local now = os.clock()
	if stage.bombs <= 0 or now - stage.lastDrop < settings.dropCooldown then
		return
	end
	stage.bombs -= 1
	stage.lastDrop = now

	-- Land the bomb a little in front of the killer, but not through a wall.
	local flat = Util.flatten(root.CFrame.LookVector)
	local direction = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(root.Position, direction * settings.dropAhead, params)
	local ahead = if hit then math.max(0, hit.Distance - 2.5) else settings.dropAhead
	local position = root.Position + direction * ahead + Vector3.new(0, 1, 0)

	Remotes.fire(player, "KillerBombs", { count = stage.bombs, max = settings.carryLimit })
	task.spawn(Bombs.plant, stage, position, {
		fuse = settings.fuse,
		hidden = true,
		owner = player,
		spareOwner = settings.killerImmuneToOwnBombs,
		onBomb = function(bomb, fuse)
			-- Only the killer sees the timer. A beat later, so the bomb has reached the killer's client first
			-- (a remote that names an instance the client does not have yet delivers nil).
			task.delay(0.15, function()
				if bomb.Parent then
					Remotes.fire(player, "BombTimer", { bomb = bomb, fuse = fuse - 0.15 })
				end
			end)
		end,
	})
end)

return KillerHotel
