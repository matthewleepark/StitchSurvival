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

-- Killer Hotel: the killer asks to throw a bomb at a spot (a Vector3). The server checks everything (role, stock, cooldown).
local dropBomb = Instance.new("RemoteEvent")
dropBomb.Name = "DropBomb"
dropBomb.Parent = folder

-- Killer Hotel parkour: intents only. The server decides speeds, stamina and whether a clamber is allowed.
local sprint = Instance.new("RemoteEvent")
sprint.Name = "Sprint"
sprint.Parent = folder
local clamber = Instance.new("RemoteEvent")
clamber.Name = "Clamber"
clamber.Parent = folder

-- Daily challenges: claim the Stickers for a finished challenge (its id). The server checks it's finished.
local claimDaily = Instance.new("RemoteEvent")
claimDaily.Name = "ClaimDaily"
claimDaily.Parent = folder

-- Hide & Seek: a hider holding debris asks to throw it at a spot (a Vector3).
local throwDebris = Instance.new("RemoteEvent")
throwDebris.Name = "ThrowDebris"
throwDebris.Parent = folder

-- Your look: "doll" or "avatar".
local setLook = Instance.new("RemoteEvent")
setLook.Name = "SetLook"
setLook.Parent = folder

-- Spectating: which player you're watching (or nil to stop), so the server streams the world around them to you.
local spectate = Instance.new("RemoteEvent")
spectate.Name = "Spectate"
spectate.Parent = folder

folder.Parent = ReplicatedStorage

local Remotes = {
	RequestRoll = requestRoll,
	EquipGear = equipGear,
	RedeemCode = redeemCode,
	AdminCommand = adminCommand,
	DropBomb = dropBomb,
	Sprint = sprint,
	Clamber = clamber,
	ClaimDaily = claimDaily,
	ThrowDebris = throwDebris,
	SetLook = setLook,
	Spectate = spectate,
}

function Remotes.fireAll(kind: string, data: any?)
	effect:FireAllClients(kind, data)
end

function Remotes.fire(player: Player, kind: string, data: any?)
	effect:FireClient(player, kind, data)
end

return Remotes
