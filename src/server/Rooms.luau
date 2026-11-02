-- Game rooms: each numbered guest-room door in the hotel is a queue for one level. Players hold E at
-- a door to join (or leave) that room; the door sign shows who's queued. The round loop in
-- init.server.luau asks for the room that has waited longest, then takes its players into the level.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)

local Rooms = {}

export type Room = {
	number: number,
	level: string,
	title: string,
	members: { Player },
	waitingSince: number, -- when the room first got a player, so the longest-waiting room goes first
	label: TextLabel?,
	prompt: ProximityPrompt,
}

local rooms: { Room } = {}
local roomOf: { [Player]: Room } = {}
local lastTrigger: { [Player]: number } = {}

local function tell(player: Player, text: string)
	Remotes.fire(player, "Announce", { text = text, color = Config.Colors.Gold })
end

local function refresh(room: Room)
	local count = #room.members
	local full = count >= Config.Rooms.capacity
	if room.label then
		room.label.Text = `{room.title}  {count}/{Config.Rooms.capacity}`
	end
	room.prompt.ObjectText = `Room {room.number} - {room.title} ({count}/{Config.Rooms.capacity})`
	room.prompt.ActionText = if full then "Room full" else "Join or leave"
end

local function leave(player: Player)
	local room = roomOf[player]
	if not room then
		return
	end
	roomOf[player] = nil
	local index = table.find(room.members, player)
	if index then
		table.remove(room.members, index)
	end
	player:SetAttribute("Room", nil)
	refresh(room)
end

local function join(room: Room, player: Player)
	local now = os.clock()
	if lastTrigger[player] and now - lastTrigger[player] < 0.5 then
		return
	end
	lastTrigger[player] = now

	if roomOf[player] == room then
		leave(player)
		tell(player, `You left room {room.number}`)
		return
	end
	if #room.members >= Config.Rooms.capacity then
		tell(player, `Room {room.number} is full`)
		return
	end

	leave(player)
	if #room.members == 0 then
		room.waitingSince = now
	end
	table.insert(room.members, player)
	roomOf[player] = room
	player:SetAttribute("Room", room.number)
	refresh(room)
	tell(player, `Joined room {room.number}: {room.title}`)
	print(`[Rooms] {player.Name} joined room {room.number} ({#room.members}/{Config.Rooms.capacity})`)
end

-- `doors` comes from HotelLobby.build(): { number, level, title, zone, label } for each game room.
function Rooms.start(doors)
	for _, door in doors do
		local prompt = Instance.new("ProximityPrompt")
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = door.zone

		local room: Room = {
			number = door.number,
			level = door.level,
			title = door.title,
			members = {},
			waitingSince = 0,
			label = door.label:FindFirstChildWhichIsA("TextLabel", true),
			prompt = prompt,
		}
		table.insert(rooms, room)
		refresh(room)

		prompt.Triggered:Connect(function(player: Player)
			join(room, player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		lastTrigger[player] = nil
	end)
	print(`[Rooms] {#rooms} game rooms ready`)
end

-- The room that has been waiting longest with enough players, or nil if none is ready.
function Rooms.pick(): Room?
	local best: Room? = nil
	for _, room in rooms do
		if #room.members >= Config.MinPlayers and (not best or room.waitingSince < best.waitingSince) then
			best = room
		end
	end
	return best
end

-- Hands over a room's players and empties it, so people can start queuing for the next game.
function Rooms.take(room: Room): { Player }
	local taken = table.clone(room.members)
	for _, player in taken do
		roomOf[player] = nil
		player:SetAttribute("Room", nil)
	end
	table.clear(room.members)
	refresh(room)
	return taken
end

return Rooms
