-- Admin testing tools. Only players named in Config.Admins get the panel, and every command is
-- checked here on the server, so nobody else can use them even with a hacked client.
--
-- Commands (sent from the client's admin panel):
--   StartRound <level|"Random">  start a round now (ends the current one first if needed)
--   EndRound                     end the current round right away
--   God <true|false>             can't be hurt or popped; falling out puts you back at the start
--   Heal, Respawn
--   Teleport <stage>             "Pod", "BombHotel" or "SharkSurvival" (levels must be running)
--   DropBomb                     drop a Bomb Hotel bomb right above you
--   Bubbles                      spawn a ring of score bubbles around you
--   Stickers
--   GivePassive { passive, target }  give a passive (target = "me" or a player name) and equip it
--   GiveAllPassives { target }       every passive
--   RemovePassive { target }         take the equipped passive off
--   Kick { target, reason }          remove a player from this server
--   Ban { target, reason }           kick them and keep them out of every server (saved; see Data.luau).
--                                    target can be someone who isn't here: type their exact username.
--   Unban { target }                 let a banned username back in
--   SpawnShark                       Bomb Hotel: send in a chaos shark right now
-- Admins can't be kicked or banned (by anyone), so a slip of the finger can't lock an admin out.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)
local RoundControl = require(script.Parent.RoundControl)
local Score = require(script.Parent.Score)
local Util = require(script.Parent.Util)
local Bombs = require(script.Parent.Levels.Bombs)
local FlyingShark = require(script.Parent.Levels.FlyingShark)
local Data = require(script.Parent.Data)
local Gear = require(script.Parent.Gear)

local Admin = {}

local pod -- the lobby, set in Admin.start

local function isAdminName(username: string): boolean
	for _, name in Config.Admins do
		if string.lower(name) == string.lower(username) then
			return true
		end
	end
	return false
end

local function isAdmin(player: Player): boolean
	return isAdminName(player.Name)
end
Admin.isAdmin = isAdmin

local function tell(player: Player, text: string)
	Remotes.fire(player, "Announce", { text = text, color = Config.Colors.Gold })
end

-- God mode: an invisible ForceField blocks normal damage, and the "God" attribute makes
-- instant pops (shark bites, crushing, falling out) skip you too.
local function applyGod(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local on = player:GetAttribute("God") == true
	character:SetAttribute("God", on)
	local shield = character:FindFirstChild("AdminShield")
	if on and not shield then
		local forceField = Instance.new("ForceField")
		forceField.Name = "AdminShield"
		forceField.Visible = false
		forceField.Parent = character
	elseif not on and shield then
		shield:Destroy()
	end
end

local commands = {}

function commands.StartRound(player: Player, levelName: string?)
	if levelName == "BombHotelChaos" then
		RoundControl.forceChaos = true
		levelName = "BombHotel"
	end
	RoundControl.forceLevel = if levelName and levelName ~= "Random" then levelName else nil
	RoundControl.skipIntermission = true
	if RoundControl.levelName then
		RoundControl.endRound = true
		tell(player, "Ending this round, the next one starts right after the results")
	else
		tell(player, "Starting now!")
	end
end

function commands.EndRound(player: Player)
	if RoundControl.levelName then
		RoundControl.endRound = true
		tell(player, "Round ended")
	else
		tell(player, "No round is running")
	end
end

function commands.God(player: Player, on: boolean?)
	player:SetAttribute("God", on == true)
	applyGod(player)
	tell(player, if on then "God mode ON" else "God mode OFF")
end

function commands.Heal(player: Player)
	local humanoid = Util.aliveHumanoid(player)
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
end

function commands.Respawn(player: Player)
	player:LoadCharacterAsync()
end

function commands.Teleport(player: Player, stageName: string?)
	local character = player.Character
	if not character or not Util.aliveHumanoid(player) then
		return
	end
	if stageName == "Pod" then
		character:PivotTo(pod.spawn.CFrame + Vector3.new(0, 4, 0))
	elseif stageName == RoundControl.levelName and RoundControl.stage then
		character:PivotTo(RoundControl.stage.spawns[1])
	else
		tell(player, "That level isn't loaded. Start it first.")
	end
end

function commands.DropBomb(player: Player)
	local root = Util.rootPart(player)
	if RoundControl.levelName == "BombHotel" and RoundControl.stage and root then
		task.spawn(Bombs.plant, RoundControl.stage, root.Position + Vector3.new(0, 8, 0))
	else
		tell(player, "Bombs only work in Bomb Hotel")
	end
end

function commands.Bubbles(player: Player)
	local root = Util.rootPart(player)
	if not root then
		return
	end
	local parent = if RoundControl.stage then RoundControl.stage.model else workspace
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		Score.spawnBubble(parent, root.Position + Vector3.new(math.cos(angle) * 6, 1, math.sin(angle) * 6))
	end
end

function commands.Stickers(player: Player)
	Data.giveStickers(player, 100, false) -- a gift, so it doesn't count on the "stickers earned" board
end

function commands.SpawnShark(player: Player)
	local stage = RoundControl.stage
	if RoundControl.levelName == "BombHotel" and stage and stage.ctx and not stage.frozen then
		task.spawn(FlyingShark.attack, stage, stage.ctx)
		tell(player, "Here comes a shark! Watch the walls for a red crack")
	else
		tell(player, "Sharks can only be sent into a Bomb Hotel round")
	end
end

-- Finds who a passive command is for: blank or "me" means you; otherwise the start of a player's
-- name or display name (any capitalization).
local function findTarget(player: Player, name: any): Player?
	if type(name) ~= "string" or name == "" or string.lower(name) == "me" then
		return player
	end
	local wanted = string.lower(name)
	for _, other in Players:GetPlayers() do
		if string.sub(string.lower(other.Name), 1, #wanted) == wanted or string.sub(string.lower(other.DisplayName), 1, #wanted) == wanted then
			return other
		end
	end
	tell(player, `No player called "{name}"`)
	return nil
end

-- A short, clean reason (or a default).
local function reasonFrom(args: any): string
	local reason = if type(args) == "table" and type(args.reason) == "string" then args.reason else ""
	reason = string.sub(string.gsub(reason, "[%c]", " "), 1, 120)
	return if string.match(reason, "%S") then reason else "Breaking the rules"
end

-- A player named for kicking or banning, but never an admin, and never yourself.
local function punishable(player: Player, target: Player?): boolean
	if not target then
		return false
	end
	if target == player then
		tell(player, "You can't do that to yourself")
		return false
	end
	if isAdmin(target) then
		tell(player, `{target.DisplayName} is an admin and can't be kicked or banned`)
		return false
	end
	return true
end

function commands.Kick(player: Player, args: any)
	local name = type(args) == "table" and args.target or nil
	if type(name) ~= "string" or name == "" or string.lower(name) == "me" then
		tell(player, "Type the player's name first")
		return
	end
	local target = findTarget(player, name)
	if target and punishable(player, target) then
		local reason = reasonFrom(args)
		target:Kick(`You were kicked: {reason}`)
		tell(player, `Kicked {target.Name}`)
	end
end

function commands.Ban(player: Player, args: any)
	local name = type(args) == "table" and args.target or nil
	if type(name) ~= "string" or name == "" or string.lower(name) == "me" then
		tell(player, "Type the player's name first")
		return
	end
	local reason = reasonFrom(args)
	-- Someone on this server (matched by the start of their name), or else an exact username.
	local wanted = string.lower(name)
	local online: Player? = nil
	for _, other in Players:GetPlayers() do
		if string.sub(string.lower(other.Name), 1, #wanted) == wanted or string.sub(string.lower(other.DisplayName), 1, #wanted) == wanted then
			online = other
			break
		end
	end
	local userId, username
	if online then
		if not punishable(player, online) then
			return
		end
		userId, username = online.UserId, online.Name
	else
		local ok, id = pcall(function()
			return Players:GetUserIdFromNameAsync(name)
		end)
		if not ok or not id then
			tell(player, `No Roblox user called "{name}"`)
			return
		end
		if isAdminName(name) then
			tell(player, `{name} is an admin and can't be banned`)
			return
		end
		userId, username = id, name
	end
	local everywhere = Data.setBan(userId, reason, player.Name)
	if online then
		online:Kick(`You are banned from Stitch Survival: {reason}`)
	end
	tell(player, if everywhere then `Banned {username} from every server` else `Banned {username} on this server only (saving is off)`)
end

function commands.Unban(player: Player, args: any)
	local name = type(args) == "table" and args.target or nil
	if type(name) ~= "string" or name == "" then
		tell(player, "Type the username to unban first")
		return
	end
	local ok, id = pcall(function()
		return Players:GetUserIdFromNameAsync(name)
	end)
	if not ok or not id then
		tell(player, `No Roblox user called "{name}"`)
		return
	end
	Data.setBan(id, nil, player.Name)
	tell(player, `Unbanned {name}`)
end

-- Give a passive (and equip it). Argument: { passive = name, target = player name or "me" }.
function commands.GivePassive(player: Player, args: any)
	if type(args) ~= "table" or not Config.getGear(args.passive) then
		return
	end
	local target = findTarget(player, args.target)
	if target then
		Gear.give(target, args.passive)
		Gear.equip(target, args.passive)
		tell(player, `Gave {args.passive} to {if target == player then "you" else target.DisplayName}`)
		if target ~= player then
			tell(target, `An admin gave you {args.passive}!`)
		end
	end
end

-- Give every passive (equips the secret one, since it has everything).
function commands.GiveAllPassives(player: Player, args: any)
	local target = findTarget(player, type(args) == "table" and args.target or nil)
	if target then
		for _, passive in Config.Gear do
			Gear.give(target, passive.name)
		end
		Gear.equip(target, Config.Gear[#Config.Gear].name)
		tell(player, `Gave every passive to {if target == player then "you" else target.DisplayName}`)
	end
end

-- Take away the equipped passive (they keep their collection).
function commands.RemovePassive(player: Player, args: any)
	local target = findTarget(player, type(args) == "table" and args.target or nil)
	if target then
		target:SetAttribute("Gear", nil)
		Gear.apply(target)
		tell(player, `Took the passive off {if target == player then "you" else target.DisplayName}`)
	end
end

function Admin.start(podInfo)
	pod = podInfo

	local function setUp(player: Player)
		if not isAdmin(player) then
			return
		end
		player:SetAttribute("IsAdmin", true)
		-- Keep god mode on across respawns.
		player.CharacterAdded:Connect(function()
			task.wait()
			applyGod(player)
		end)
	end
	Players.PlayerAdded:Connect(setUp)
	for _, player in Players:GetPlayers() do
		setUp(player)
	end

	Remotes.AdminCommand.OnServerEvent:Connect(function(player, command, argument)
		if not isAdmin(player) then
			return
		end
		local handler = commands[command]
		if handler then
			handler(player, argument)
		end
	end)
end

return Admin
