-- The LOOK button: switch between the knitted doll and your own Roblox avatar (Config.Look). The server
-- saves the choice and respawns you in it (right away in the lobby, after the round if you're playing).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Menu = require(script.Parent.Menu)

local player = Players.LocalPlayer

local LookButton = {}

function LookButton.start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetLook") :: RemoteEvent
	local button
	local function refresh()
		local look = player:GetAttribute("Look")
		button.Text = if look == "avatar" then "\u{1F642} ME" else "\u{1F9F8} DOLL"
	end
	button = Menu.add(3, "\u{1F9F8} DOLL", Color3.fromRGB(150, 100, 200), function()
		local look = player:GetAttribute("Look")
		remote:FireServer(if look == "avatar" then "doll" else "avatar")
	end)
	player:GetAttributeChangedSignal("Look"):Connect(refresh)
	refresh()
end

return LookButton
