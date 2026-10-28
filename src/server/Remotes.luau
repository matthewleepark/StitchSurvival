-- One RemoteEvent carries all visual effects to clients (popups, explosions, countdowns...),
-- so the client can make them smooth without the server animating anything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local effect = Instance.new("RemoteEvent")
effect.Name = "Effect"
effect.Parent = folder

local requestRoll = Instance.new("RemoteEvent")
requestRoll.Name = "RequestRoll"
requestRoll.Parent = folder

folder.Parent = ReplicatedStorage

local Remotes = {
	RequestRoll = requestRoll,
}

function Remotes.fireAll(kind: string, data: any?)
	effect:FireAllClients(kind, data)
end

function Remotes.fire(player: Player, kind: string, data: any?)
	effect:FireClient(player, kind, data)
end

return Remotes
