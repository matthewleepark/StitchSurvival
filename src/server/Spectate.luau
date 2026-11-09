-- Spectating, server side. The camera work is all on the client (client/Spectate.luau); the server only
-- makes sure the world around whoever you're watching is streamed to you (with streaming on, far-away
-- levels and players aren't sent otherwise). You can only watch someone who is in the round right now
-- (their "InRound" attribute), and only while you aren't in it yourself.

local Players = game:GetService("Players")

local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local Spectate = {}

local function watch(player: Player)
	-- Pulled into a round yourself: stream around your own doll again.
	player:GetAttributeChangedSignal("InRound"):Connect(function()
		if player:GetAttribute("InRound") then
			player.ReplicationFocus = nil
		end
	end)
end

function Spectate.start()
	Remotes.Spectate.OnServerEvent:Connect(function(player: Player, target: any)
		local root = nil
		if typeof(target) == "Instance" and target:IsA("Player") and target ~= player and target:GetAttribute("InRound") and not player:GetAttribute("InRound") then
			root = Util.rootPart(target)
		end
		player.ReplicationFocus = root
		if root then
			local position = root.Position
			task.spawn(function()
				pcall(function()
					player:RequestStreamAroundAsync(position, 5)
				end)
			end)
		end
	end)
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Spectate
