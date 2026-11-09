-- Promo codes (Config.Codes). A player types a code into the CODES box; the server checks it,
-- gives the reward (Stickers and/or a gear item) and answers with a message to show them.
-- Each code works once per player, ever: used codes are saved with their progress (server/Data.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.Data)
local Gear = require(script.Parent.Gear)
local Remotes = require(script.Parent.Remotes)

local Codes = {}

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
	local profile = Data.get(player)
	if not profile then
		return false, "Still loading your save, try again in a moment!"
	end
	if profile.codes[code] then
		return false, "You already used that code."
	end
	profile.codes[code] = true

	if reward.stickers then
		Data.giveStickers(player, reward.stickers, true)
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
		lastTry[player] = nil
	end)
end

return Codes
