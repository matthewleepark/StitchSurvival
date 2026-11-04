-- Promo codes (Config.Codes). A player types a code into the CODES box; the server checks it,
-- gives the reward (Stickers and/or a gear item) and answers with a message to show them.
-- Each code works once per player. Nothing is saved yet, so that's once per visit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Gear = require(script.Parent.Gear)
local Remotes = require(script.Parent.Remotes)

local Codes = {}

local used: { [Player]: { [string]: boolean } } = {}
local lastTry: { [Player]: number } = {}

local function redeem(player: Player, typed: any): (boolean, string)
	if type(typed) ~= "string" then
		return false, "Type a code first!"
	end
	local now = os.clock()
	if lastTry[player] and now - lastTry[player] < 1 then
		return false, "Slow down a little!"
	end
	lastTry[player] = now

	local code = string.upper((string.gsub(typed, "%s", "")))
	local reward = Config.Codes[code]
	if not reward then
		return false, "That code doesn't exist."
	end
	used[player] = used[player] or {}
	if used[player][code] then
		return false, "You already used that code."
	end
	used[player][code] = true

	if reward.stickers then
		local leaderstats = player:FindFirstChild("leaderstats")
		local stickers = leaderstats and leaderstats:FindFirstChild("Stickers") :: IntValue?
		if stickers then
			stickers.Value += reward.stickers
		end
	end
	if reward.gear and Config.getGear(reward.gear) then
		Gear.give(player, reward.gear)
	end
	return true, reward.message or "Code redeemed!"
end

function Codes.start()
	Remotes.RedeemCode.OnServerInvoke = function(player, typed)
		local ok, message = redeem(player, typed)
		return { ok = ok, message = message }
	end
	Players.PlayerRemoving:Connect(function(player)
		used[player] = nil
		lastTry[player] = nil
	end)
end

return Codes
