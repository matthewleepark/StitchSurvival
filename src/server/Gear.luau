-- Gear: rolls, your collection, and equipping. The server does the random pick so nobody can fake a
-- lucky roll; the client only plays the spinning reel for the result it's told.
--
--   * Walk up to the gear machine in the lobby -> the client opens the gear panel.
--   * ROLL (costs Stickers) -> a random item from Config.Gear. It's added to your collection
--     ("OwnedGear" attribute), and equipped automatically if it's rarer than what you have on.
--   * EQUIP any item you own from the panel. Its passives (speed, jump...) apply right away.
-- Nothing is saved between sessions yet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local Gear = {}

local lastRoll: { [Player]: number } = {}

local function owned(player: Player): { [string]: boolean }
	local set = {}
	local list = player:GetAttribute("OwnedGear") :: string?
	if list then
		for name in string.gmatch(list, "[^,]+") do
			set[name] = true
		end
	end
	return set
end

local function rarityRank(name: string?): number
	local gear = Config.getGear(name)
	return if gear then Config.RarityOrder[gear.rarity] else 0
end

-- Applies the equipped item's movement passives to the player's doll.
function Gear.apply(player: Player)
	local humanoid = Util.aliveHumanoid(player)
	if not humanoid then
		return
	end
	local speed = Config.Doll.WalkSpeed + (Util.passive(player, "speed") or 0)
	humanoid.WalkSpeed = speed
	humanoid.JumpHeight = Config.Doll.JumpHeight + (Util.passive(player, "jump") or 0)
	-- Other scripts that slow you down for a moment put you back to this.
	humanoid:SetAttribute("BaseWalkSpeed", speed)
end

function Gear.equip(player: Player, name: string)
	if not owned(player)[name] then
		return
	end
	player:SetAttribute("Gear", name)
	Gear.apply(player)
end

-- Adds an item to the player's collection (and equips it if it beats what they're wearing).
-- Returns whether it was new to them.
function Gear.give(player: Player, name: string): boolean
	local set = owned(player)
	local isNew = not set[name]
	if isNew then
		local list = player:GetAttribute("OwnedGear") :: string?
		player:SetAttribute("OwnedGear", if list and list ~= "" then `{list},{name}` else name)
	end
	if rarityRank(name) > rarityRank(player:GetAttribute("Gear") :: string?) then
		player:SetAttribute("Gear", name)
		Gear.apply(player)
	end
	return isNew
end

local function roll(player: Player)
	local now = os.clock()
	if lastRoll[player] and now - lastRoll[player] < 3 then
		return -- one roll at a time, so the reel can finish spinning
	end
	lastRoll[player] = now

	local leaderstats = player:FindFirstChild("leaderstats")
	local stickers = leaderstats and leaderstats:FindFirstChild("Stickers") :: IntValue?
	if not stickers or stickers.Value < Config.RollCost then
		Remotes.fire(player, "GearResult", nil)
		return
	end
	stickers.Value -= Config.RollCost

	local gear = Util.weightedPick(Config.Gear)
	local isNew = Gear.give(player, gear.name)
	Remotes.fire(player, "GearResult", { name = gear.name, isNew = isNew })
	if Config.RarityOrder[gear.rarity] >= Config.RarityOrder.Epic then
		Remotes.fireAll("Announce", {
			text = `{player.DisplayName} rolled a {gear.rarity} {gear.name}!`,
			color = Config.RarityColors[gear.rarity],
		})
	end
end

function Gear.start(machine: BasePart)
	Remotes.RequestRoll.OnServerEvent:Connect(roll)
	Remotes.EquipGear.OnServerEvent:Connect(function(player, name)
		if type(name) == "string" then
			Gear.equip(player, name)
		end
	end)

	-- Walking up to the machine opens the gear panel.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Passive Machine"
	prompt.ObjectText = "Passives"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = machine
	prompt.Triggered:Connect(function(player)
		Remotes.fire(player, "OpenGearPanel")
	end)

	-- Passives come back after respawning (once the doll has been sized, which sets the defaults).
	local function watch(player: Player)
		player.CharacterAppearanceLoaded:Connect(function()
			task.wait(0.5)
			Gear.apply(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	-- The regen passive: heal a little every second.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local regen = Util.passive(player, "regen")
				local humanoid = regen and Util.aliveHumanoid(player)
				if humanoid and humanoid.Health < humanoid.MaxHealth then
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + regen)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRoll[player] = nil
	end)
end

return Gear
