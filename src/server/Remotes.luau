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

-- Equip an item you own from the gear panel.
local equipGear = Instance.new("RemoteEvent")
equipGear.Name = "EquipGear"
equipGear.Parent = folder

-- Promo codes: the client asks, the server checks and answers with a message.
local redeemCode = Instance.new("RemoteFunction")
redeemCode.Name = "RedeemCode"
redeemCode.Parent = folder

-- Admin panel buttons. The server checks the sender is an admin before doing anything.
local adminCommand = Instance.new("RemoteEvent")
adminCommand.Name = "AdminCommand"
adminCommand.Parent = folder

-- Killer Hotel: the killer asks to drop a bomb. The server checks everything (role, stock, cooldown).
local dropBomb = Instance.new("RemoteEvent")
dropBomb.Name = "DropBomb"
dropBomb.Parent = folder

folder.Parent = ReplicatedStorage

local Remotes = {
	RequestRoll = requestRoll,
	EquipGear = equipGear,
	RedeemCode = redeemCode,
	AdminCommand = adminCommand,
	DropBomb = dropBomb,
}

function Remotes.fireAll(kind: string, data: any?)
	effect:FireAllClients(kind, data)
end

function Remotes.fire(player: Player, kind: string, data: any?)
	effect:FireClient(player, kind, data)
end

return Remotes
