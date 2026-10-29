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

-- A glossy 2-stud plastic bubble with a little tin-foil star inside. It bobs gently (animated on
-- each player's screen) and hums faintly when you're close.
function Score.spawnBubble(parent: Instance, position: Vector3, lifetime: number?): Part
	local bubble = Craft.ball(parent, position, 2, Config.Colors.Bubble, Enum.Material.Glass, {
		Name = "ScoreBubble",
		CanCollide = false,
		CanQuery = false,
		Transparency = 0.45,
		Reflectance = 0.2,
	})
	local star = Craft.block(bubble, CFrame.new(position) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.7, 0.7, 0.15), Config.Colors.Gold, Enum.Material.Foil, Craft.DECOR)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bubble
	weld.Part1 = star
	weld.Parent = star
	bubble:SetAttribute("BaseY", position.Y)
	Craft.tag(bubble, "Bob")
	Util.loopSound("BubbleHum", bubble)

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
