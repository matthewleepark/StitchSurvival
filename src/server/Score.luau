-- LBP-style scoring: points for surviving, score bubbles to grab, and a combo multiplier
-- that grows when you grab bubbles quickly and resets when you get hurt.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Craft)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local Score = {}

local scores: { [Player]: number } = {}
local lastBubble: { [Player]: number } = {}

function Score.reset()
	table.clear(scores)
	table.clear(lastBubble)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Score", 0)
		player:SetAttribute("Multiplier", 1)
	end
end

function Score.get(player: Player): number
	return scores[player] or 0
end

function Score.add(player: Player, points: number, position: Vector3?)
	scores[player] = (scores[player] or 0) + points
	player:SetAttribute("Score", scores[player])
	if position then
		Remotes.fireAll("Popup", { text = `+{points}`, position = position, color = player:GetAttribute("Color") })
	end
end

function Score.breakCombo(player: Player)
	lastBubble[player] = nil
	player:SetAttribute("Multiplier", 1)
end

-- Call about once a second so combos run out if you stop grabbing bubbles.
function Score.decay()
	local now = os.clock()
	for player, time in lastBubble do
		if now - time > Config.MultiplierWindow then
			Score.breakCombo(player)
		end
	end
end

local function collect(player: Player, position: Vector3)
	local now = os.clock()
	local multiplier = 1
	if lastBubble[player] and now - lastBubble[player] <= Config.MultiplierWindow then
		multiplier = math.min(((player:GetAttribute("Multiplier") :: number?) or 1) + 1, Config.MaxMultiplier)
	end
	lastBubble[player] = now
	player:SetAttribute("Multiplier", multiplier)
	Score.add(player, Config.BubblePoints * multiplier, position)
	Remotes.fireAll("Pop", { position = position, userId = player.UserId })
end

function Score.spawnBubble(parent: Instance, position: Vector3, lifetime: number?): Part
	local bubble = Craft.ball(parent, position, 1.8, Config.Colors.Bubble, Enum.Material.ForceField, {
		Name = "ScoreBubble",
		CanCollide = false,
		CanQuery = false,
	})
	bubble:SetAttribute("BaseY", position.Y)
	Craft.tag(bubble, "Bob")

	local collected = false
	bubble.Touched:Connect(function(hit)
		if collected then
			return
		end
		local character = Util.characterFromPart(hit)
		local player = character and Players:GetPlayerFromCharacter(character)
		if player and Util.aliveHumanoid(player) then
			collected = true
			collect(player, bubble.Position)
			bubble:Destroy()
		end
	end)

	Debris:AddItem(bubble, lifetime or 14)
	return bubble
end

Players.PlayerRemoving:Connect(function(player)
	scores[player] = nil
	lastBubble[player] = nil
end)

return Score
