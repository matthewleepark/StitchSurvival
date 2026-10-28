-- Scuba gear rolls. The server does the random pick so nobody can fake a lucky roll.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local Gear = {}

local lastRoll: { [Player]: number } = {}

local function roll(player: Player)
	local now = os.clock()
	if lastRoll[player] and now - lastRoll[player] < 1 then
		return
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
	local current = Config.getGear(player:GetAttribute("Gear") :: string?)
	local kept = not current or gear.oxygen > current.oxygen
	if kept then
		player:SetAttribute("Gear", gear.name)
	end

	Remotes.fire(player, "GearResult", { name = gear.name, rarity = gear.rarity, oxygen = gear.oxygen, kept = kept })
	if gear.rarity == "Epic" or gear.rarity == "Legendary" then
		Remotes.fireAll("Announce", {
			text = `{player.DisplayName} rolled a {gear.rarity} {gear.name}!`,
			color = Config.RarityColors[gear.rarity],
		})
	end
end

function Gear.start(machine: BasePart)
	Remotes.RequestRoll.OnServerEvent:Connect(roll)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Roll Scuba Gear"
	prompt.ObjectText = `{Config.RollCost} Stickers`
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = machine
	prompt.Triggered:Connect(roll)

	Players.PlayerRemoving:Connect(function(player)
		lastRoll[player] = nil
	end)
end

return Gear
