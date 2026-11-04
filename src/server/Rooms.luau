-- Game rooms: each numbered guest-room door in the hotel is a queue for one level.
--
-- Step onto the glowing pad in front of a door to join: you're taken into that room's waiting room
-- and sat down in the next free chair (the next person to join gets the next chair). Jump to stand
-- up and leave; you're put back on the balcony. The floating text over the pad and the screen inside
-- the room show how many are waiting. The round loop in init.server.luau asks for the room that has
-- waited longest, then takes its players into the level.

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
	screenLabel: TextLabel?,
	seats: { Seat },
	exit: CFrame,
}

local rooms: { Room } = {}
local roomOf: { [Player]: Room } = {}
local seatOf: { [Player]: Seat } = {}
local lastTouch: { [Player]: number } = {}

local function tell(player: Player, text: string)
	Remotes.fire(player, "Announce", { text = text, color = Config.Colors.Gold })
end

local function refresh(room: Room)
	local count = #room.members
	local capacity = math.min(Config.Rooms.capacity, #room.seats)
	if room.label then
		room.label.Text = if count >= capacity
			then `Room {room.number}: {room.title}\nFull ({count}/{capacity})`
			else `Room {room.number}: {room.title}\n{count}/{capacity} waiting - step in to join`
	end
	if room.screenLabel then
		room.screenLabel.Text = `{room.title}\n{count}/{capacity} waiting`
	end
end

-- Gets a player out of their waiting-room chair without sending them anywhere.
local function unseat(player: Player)
	local seat = seatOf[player]
	seatOf[player] = nil
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
	end
	if seat then
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
	end
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

local function freeSeat(room: Room): Seat?
	for _, seat in room.seats do
		if not seat.Occupant then
			local taken = false
			for _, other in seatOf do
				if other == seat then
					taken = true
				end
			end
			if not taken then
				return seat
			end
		end
	end
	return nil
end

local function join(room: Room, player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 or roomOf[player] then
		return
	end
	local now = os.clock()
	if lastTouch[player] and now - lastTouch[player] < 1.5 then
		return
	end
	lastTouch[player] = now

	local seat = freeSeat(room)
	if #room.members >= Config.Rooms.capacity or not seat then
		tell(player, `Room {room.number} is full`)
		return
	end

	if #room.members == 0 then
		room.waitingSince = now
	end
	table.insert(room.members, player)
	roomOf[player] = room
	seatOf[player] = seat
	player:SetAttribute("Room", room.number)
	refresh(room)
	tell(player, `Joined room {room.number}: {room.title}. Jump to leave.`)

	-- Into the waiting room and down into the chair.
	character:PivotTo(seat.CFrame + Vector3.new(0, 2, 0))
	task.wait(0.1)
	if seatOf[player] == seat then
		seat:Sit(humanoid)
	end

	-- Standing up (jumping) means leaving the room: back out onto the balcony.
	local connection
	connection = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant ~= nil then
			return
		end
		connection:Disconnect()
		if seatOf[player] == seat and roomOf[player] == room then
			unseat(player) -- make sure the chair has really let go before moving them
			leave(player)
			task.wait()
			if player.Character then
				player.Character:PivotTo(room.exit)
			end
			tell(player, `You left room {room.number}`)
		end
	end)
end

-- `doors` comes from HotelLobby.build(): { number, level, title, pad, label, screenLabel, seats, exit }.
function Rooms.start(doors)
	for _, door in doors do
		local room: Room = {
			number = door.number,
			level = door.level,
			title = door.title,
			members = {},
			waitingSince = 0,
			label = door.label,
			screenLabel = door.screenLabel,
			seats = door.seats,
			exit = door.exit,
		}
		table.insert(rooms, room)
		refresh(room)

		door.pad.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			if player then
				join(room, player)
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		unseat(player)
		leave(player)
		lastTouch[player] = nil
	end)
	print(`[Rooms] {#rooms} game rooms ready`)
end

-- Takes a player out of any room and chair without moving them (used when a game pulls them in).
function Rooms.release(player: Player)
	unseat(player)
	leave(player)
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

-- Hands over a room's players (standing them up out of their chairs) and empties it, so people can
-- start queuing for the next game.
function Rooms.take(room: Room): { Player }
	local taken = table.clone(room.members)
	for _, player in taken do
		unseat(player)
		roomOf[player] = nil
		player:SetAttribute("Room", nil)
	end
	table.clear(room.members)
	refresh(room)
	return taken
end

return Rooms
