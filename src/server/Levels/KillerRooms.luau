-- Killer Hotel rooms: doorways with kick-open doors that lock, furniture, and wardrobes to hide in.
-- Numbers are in Config.KillerHotel.rooms and Config.KillerHotel.doors.
--
-- DOORS. Each room's doorway is a gap in the wall (frame, lintel) with a hinged door in it that swings OUT
-- of the room with a kick (the client animates the swing, see client/Doors.luau; the server only keeps the
-- state and plays the bang). Hold the open key to kick it open or shut it. From inside a closed door, the
-- lock key locks it. A locked door only gives way to the killer, who holds the open key for
-- breakSeconds while the door shudders and a loud pounding carries through the hotel, or to a bomb
-- (every part of a door is Breakable). E is taken by Grab, so doors use F and G.
--
-- WARDROBES. Hold the key at a wardrobe to climb in: you vanish and the wardrobe looks the same to
-- everyone. Hold it again to climb out. The killer can search a wardrobe: if someone is inside they are
-- pulled out. A blast that reaches a hidden player still hurts them. The prompt never changes its
-- text, so a wardrobe never shows whether it is occupied.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)
local Remotes = require(script.Parent.Parent.Remotes)
local Util = require(script.Parent.Parent.Util)

local Colors = Config.Colors
local M = Craft.Material
local DOORS = Config.KillerHotel.doors

local KillerRooms = {}

local function notice(player: Player, text: string)
	Remotes.fire(player, "Announce", { text = text, color = Colors.Paper })
end

local function breakable(part: BasePart)
	part:SetAttribute("Breakable", true)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Util.flatten(a - b).Magnitude
end

-- Doors -------------------------------------------------------------------------------------------

local function setPromptTexts(door)
	if door.locked then
		door.openPrompt.ActionText = "Locked"
		door.openPrompt.HoldDuration = DOORS.breakSeconds
		door.lockPrompt.ActionText = "Unlock"
	else
		door.openPrompt.ActionText = if door.open then "Close" else "Kick open"
		door.openPrompt.HoldDuration = DOORS.openHold
		door.lockPrompt.ActionText = "Lock"
	end
	door.lockPrompt.Enabled = not door.open and not door.broken
	door.bolt.Color = if door.locked then Color3.fromRGB(200, 40, 40) else Color3.fromRGB(88, 160, 96)
end

-- Is somebody standing in the doorway (so the door cannot shut on them)?
local function doorwayBusy(door): boolean
	for _, player in Players:GetPlayers() do
		local root = Util.rootPart(player)
		if root and Util.aliveHumanoid(player) then
			local rel = root.Position - door.center
			local normal = rel:Dot(door.outDir)
			local lateral = (rel - door.outDir * normal) * Vector3.new(1, 0, 1)
			if math.abs(normal) < DOORS.closeClearance and lateral.Magnitude < DOORS.width / 2 + 1.5 and math.abs(rel.Y) < 8 then
				return true
			end
		end
	end
	return false
end

local function retire(door)
	if door.broken then
		return
	end
	door.broken = true
	door.pounding = nil
	door.openPrompt.Enabled = false
	door.lockPrompt.Enabled = false
end

-- The killer breaks a locked door down: it bursts away from them into the room.
local function breakDown(stage, door, killer: Player)
	if door.broken then
		return
	end
	retire(door)
	local root = Util.rootPart(killer)
	local from = if root then root.Position else door.center + door.outDir * 4
	local away = Util.flatten(door.center - from)
	local direction = if away.Magnitude > 0.1 then away.Unit else -door.outDir
	for _, part in door.model:GetDescendants() do
		if part:IsA("BasePart") then
			part:SetAttribute("Breakable", false)
			part.Anchored = false
			part.CanCollide = true
			part.AssemblyLinearVelocity = direction * 36 + Vector3.new(0, 10, 0)
			part.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-6, 6), math.random(-6, 6))
		end
	end
	Util.soundAt("BlockBreak", door.center)
	Debris:AddItem(door.model, 8)
end

local function startPounding(door, player: Player)
	local token = {}
	door.pounding = token
	task.spawn(function()
		while door.pounding == token and not door.broken and door.locked do
			Util.playSound("DoorPound", door.panel)
			door.model:SetAttribute("Pound", (door.model:GetAttribute("Pound") or 0) + 1) -- the client shudders the door
			task.wait(DOORS.poundEvery)
		end
	end)
end

local function setOpen(door, open: boolean)
	door.open = open
	door.model:SetAttribute("Open", open)
	Util.playSound(if open then "DoorKick" else "DoorClose", door.panel)
	setPromptTexts(door)
end

-- Builds one doorway: a frame of wall either side of a gap, a lintel over it, and the door in the gap.
-- `center` is the middle of the wall line at floor level; `outDir` points out of the room.
function KillerRooms.buildDoorway(stage, parent: Instance, spec)
	local center: Vector3, outDir: Vector3 = spec.center, spec.outDir
	local alongZ: boolean = spec.alongZ
	local along = if alongZ then Vector3.zAxis else Vector3.xAxis
	local length = spec.cell + spec.wall
	local DW, DH = DOORS.width, DOORS.height
	local wallHeight = spec.wallHeight

	local function wallPiece(offset: number, pieceLength: number, y0: number, height: number)
		local at = center + along * offset + Vector3.new(0, y0 + height / 2, 0)
		local size = if alongZ then Vector3.new(spec.wall, height, pieceLength) else Vector3.new(pieceLength, height, spec.wall)
		local piece = Craft.block(parent, CFrame.new(at), size, spec.frameColor, M.Cardboard)
		piece.Name = "DoorFrame"
		breakable(piece)
	end
	local sideLength = (length - DW) / 2
	wallPiece(-(DW / 2 + sideLength / 2), sideLength, 0, wallHeight)
	wallPiece(DW / 2 + sideLength / 2, sideLength, 0, wallHeight)
	wallPiece(0, DW, DH, wallHeight - DH)

	-- The door: a panel hinged at one side of the gap (the side is random), with a knob each side and a
	-- deadbolt on the room side. The whole thing is one model so the client can swing it as one.
	local model = Instance.new("Model")
	model.Name = "KillerDoor"
	local panelWidth = DW - 0.3
	local hingeSide = if spec.rng:NextNumber() < 0.5 then 1 else -1
	local hinge = center + along * hingeSide * (panelWidth / 2) + Vector3.new(0, 0, 0)
	local toward = -along * hingeSide -- from the hinge toward the free edge
	local panelSize = if alongZ then Vector3.new(1.2, DH, panelWidth) else Vector3.new(panelWidth, DH, 1.2)
	local panel = Craft.block(model, CFrame.new(center + Vector3.new(0, DH / 2, 0)), panelSize, spec.doorColor, M.Wood)
	panel.Name = "Panel"
	breakable(panel)

	local knobAt = center + toward * (panelWidth / 2 - 0.9) + Vector3.new(0, 5.2, 0)
	for _, side in { -1, 1 } do
		local knob = Craft.ball(model, knobAt + outDir * side * 0.95, 0.9, Colors.Gold, M.Metal)
		knob.CanCollide = false
		breakable(knob)
	end
	local bolt = Craft.block(model, CFrame.new(knobAt - outDir * 0.85 + Vector3.new(0, 1.3, 0)), if alongZ then Vector3.new(0.5, 0.8, 1.4) else Vector3.new(1.4, 0.8, 0.5), Color3.fromRGB(88, 160, 96), M.Metal)
	bolt.Name = "Bolt"
	bolt.CanCollide = false
	breakable(bolt)

	-- Which way does the door turn to swing out? Try +90 degrees about Y and see whether it points outward.
	local turned = CFrame.Angles(0, math.rad(90), 0) * toward
	local sign = if turned:Dot(outDir) > 0 then 1 else -1
	model:SetAttribute("Hinge", hinge)
	model:SetAttribute("Sign", sign)
	model:SetAttribute("OpenAngle", math.rad(DOORS.openAngle))
	model:SetAttribute("Open", false)
	model:SetAttribute("Pound", 0)
	model.PrimaryPart = panel

	local openPrompt = Instance.new("ProximityPrompt")
	openPrompt.ObjectText = "Door"
	openPrompt.KeyboardKeyCode = DOORS.openKey
	openPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	openPrompt.MaxActivationDistance = 9
	openPrompt.RequiresLineOfSight = false
	openPrompt.Style = Enum.ProximityPromptStyle.Default
	openPrompt.Parent = panel
	local lockPrompt = Instance.new("ProximityPrompt")
	lockPrompt.ObjectText = "Door"
	lockPrompt.KeyboardKeyCode = DOORS.lockKey
	lockPrompt.GamepadKeyCode = Enum.KeyCode.ButtonL1
	lockPrompt.HoldDuration = 0.3
	lockPrompt.MaxActivationDistance = 4
	lockPrompt.RequiresLineOfSight = true -- the shut door hides it from anyone outside
	lockPrompt.Parent = bolt

	local door = {
		model = model,
		panel = panel,
		bolt = bolt,
		openPrompt = openPrompt,
		lockPrompt = lockPrompt,
		center = center + Vector3.new(0, DH / 2, 0),
		outDir = outDir,
		open = false,
		locked = false,
		broken = false,
	}
	table.insert(stage.doors, door)
	setPromptTexts(door)

	openPrompt.Triggered:Connect(function(player: Player)
		if stage.frozen or door.broken or not Util.aliveHumanoid(player) then
			return
		end
		door.pounding = nil
		if door.locked then
			if stage.killer == player then
				breakDown(stage, door, player)
			end
		elseif door.open then
			if doorwayBusy(door) then
				notice(player, "Something is in the way!")
			else
				setOpen(door, false)
			end
		else
			setOpen(door, true)
		end
	end)
	openPrompt.PromptButtonHoldBegan:Connect(function(player: Player)
		if door.locked and not door.broken and not stage.frozen and stage.killer == player then
			startPounding(door, player)
		end
	end)
	openPrompt.PromptButtonHoldEnded:Connect(function()
		door.pounding = nil
	end)
	lockPrompt.Triggered:Connect(function(player: Player)
		if stage.frozen or door.broken or door.open then
			return
		end
		local root = Util.rootPart(player)
		if not root or not Util.aliveHumanoid(player) then
			return
		end
		-- Only from inside the room.
		local rel = root.Position - door.center
		if rel:Dot(door.outDir) > -0.3 or flatDistance(root.Position, door.center) > 7 then
			return
		end
		door.locked = not door.locked
		Util.playSound("DoorLock", door.panel)
		setPromptTexts(door)
	end)

	-- A bomb tears the whole door loose (or shatters it): retire it so nobody can use the dead prompts.
	panel:GetPropertyChangedSignal("Anchored"):Connect(function()
		if not panel.Anchored then
			retire(door)
		end
	end)
	panel.AncestryChanged:Connect(function()
		if not panel.Parent then
			retire(door)
		end
	end)

	CollectionService:AddTag(model, "KillerDoor") -- client/Doors.luau swings anything with this tag
	model.Parent = parent
	return door
end

-- Wardrobes ---------------------------------------------------------------------------------------

local function restoreVisibility(entry)
	for instance, value in entry.saved do
		if instance.Parent then
			(instance :: any).Transparency = value
		end
	end
	if entry.humanoid and entry.humanoid.Parent then
		entry.humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
end

local function climbOut(stage, wardrobe, player: Player, spot: Vector3?)
	local entry = stage.hiding[player]
	if not entry then
		return
	end
	stage.hiding[player] = nil
	wardrobe.occupant = nil
	restoreVisibility(entry)
	local root = Util.rootPart(player)
	if root then
		root.Anchored = false
		if spot then
			root.CFrame = CFrame.new(spot)
		end
	end
	Util.playSound("WardrobeCreak", wardrobe.body)
end

local function climbIn(stage, wardrobe, player: Player)
	local character = player.Character
	local humanoid = Util.aliveHumanoid(player)
	local root = Util.rootPart(player)
	if not character or not humanoid or not root or stage.hiding[player] then
		return
	end
	local saved = {}
	for _, instance in character:GetDescendants() do
		if (instance:IsA("BasePart") or instance:IsA("Decal")) and instance.Transparency < 1 then
			saved[instance] = instance.Transparency
			instance.Transparency = 1
		end
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	root.Anchored = true
	root.CFrame = CFrame.new(wardrobe.body.Position)
	wardrobe.occupant = player
	stage.hiding[player] = { wardrobe = wardrobe, saved = saved, humanoid = humanoid }
	Util.playSound("WardrobeCreak", wardrobe.body)
	if stage.onHide then
		stage.onHide(player) -- e.g. a daily challenge counting it
	end
	humanoid.Died:Once(function()
		if stage.hiding[player] then
			climbOut(stage, wardrobe, player, nil)
		end
	end)
end

-- Where someone climbing out stands: in front of the wardrobe, on the floor.
local function exitSpot(wardrobe): Vector3
	return wardrobe.body.Position + wardrobe.front * 4 + Vector3.new(0, -2, 0)
end

function KillerRooms.buildWardrobe(stage, parent: Instance, position: Vector3, front: Vector3, alongZ: boolean)
	-- `position` is the floor point against the wall; `front` points into the room.
	local width, height, depth = 5, 10, 3.2
	local size = if alongZ then Vector3.new(depth, height, width) else Vector3.new(width, height, depth)
	local body = Craft.block(parent, CFrame.new(position + Vector3.new(0, height / 2, 0)), size, Colors.WoodDark, M.Wood)
	body.Name = "Wardrobe"
	breakable(body)
	for _, side in { -1, 1 } do
		local along = if alongZ then Vector3.zAxis else Vector3.xAxis
		local plate = Craft.block(parent, CFrame.new(position + Vector3.new(0, height / 2, 0) + front * (depth / 2 + 0.06) + along * side * (width / 4)), if alongZ then Vector3.new(0.12, height - 1, width / 2 - 0.3) else Vector3.new(width / 2 - 0.3, height - 1, 0.12), Colors.Wood, M.Wood, Craft.DECOR)
		plate.Name = "WardrobeDoor"
	end

	local wardrobe = { body = body, front = front, occupant = nil :: Player? }
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hide" -- never changes: it must not show whether someone is inside
	prompt.ObjectText = "Wardrobe"
	prompt.KeyboardKeyCode = DOORS.openKey
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 6
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	prompt.Triggered:Connect(function(player: Player)
		if stage.frozen or not Util.aliveHumanoid(player) then
			return
		end
		local isKiller = stage.killer == player
		if wardrobe.occupant == player then
			climbOut(stage, wardrobe, player, exitSpot(wardrobe))
		elseif wardrobe.occupant == nil then
			if isKiller then
				notice(player, "Nobody in here.")
			else
				climbIn(stage, wardrobe, player)
			end
		elseif isKiller then
			local victim = wardrobe.occupant :: Player
			climbOut(stage, wardrobe, victim, exitSpot(wardrobe)) -- found!
		else
			notice(player, "Someone is already in here.")
		end
	end)

	-- A blast that rips the wardrobe loose drops whoever is inside right where they are.
	local function dumped()
		local occupant = wardrobe.occupant
		if occupant then
			climbOut(stage, wardrobe, occupant, nil)
		end
		prompt.Enabled = false
	end
	body:GetPropertyChangedSignal("Anchored"):Connect(function()
		if not body.Anchored then
			dumped()
		end
	end)
	body.AncestryChanged:Connect(function()
		if not body.Parent then
			dumped()
		end
	end)
	return wardrobe
end

-- Furniture: a bed and a crate for cover.
function KillerRooms.buildBed(parent: Instance, position: Vector3, longAxisX: boolean, color: Color3)
	local frameSize = if longAxisX then Vector3.new(9, 1.6, 5) else Vector3.new(5, 1.6, 9)
	local frame = Craft.block(parent, CFrame.new(position + Vector3.new(0, 0.8, 0)), frameSize, Colors.WoodDark, M.Wood)
	frame.Name = "Bed"
	breakable(frame)
	local mattress = Craft.block(parent, CFrame.new(position + Vector3.new(0, 2, 0)), frameSize - Vector3.new(0.4, -0.4, 0.4), color, M.Felt)
	mattress.Name = "Mattress"
	breakable(mattress)
end

function KillerRooms.buildCrate(parent: Instance, position: Vector3)
	local crate = Craft.block(parent, CFrame.new(position + Vector3.new(0, 2, 0)), Vector3.new(4, 4, 4), Colors.Burlap, M.Wood)
	crate.Name = "Crate"
	breakable(crate)
	CollectionService:AddTag(crate, "Climbable") -- see Parkour.luau
end

-- A tall shelf against a wall, too high to jump onto (it takes a clamber). `wallAlongZ` says which way the wall runs.
function KillerRooms.buildShelf(parent: Instance, position: Vector3, wallAlongZ: boolean, height: number)
	local size = if wallAlongZ then Vector3.new(3, height, 6) else Vector3.new(6, height, 3)
	local shelf = Craft.block(parent, CFrame.new(position + Vector3.new(0, height / 2, 0)), size, Colors.WoodDark, M.Wood)
	shelf.Name = "Shelf"
	breakable(shelf)
	CollectionService:AddTag(shelf, "Climbable")
	return shelf
end

-- A tall barricade of crates across a corridor, too high to jump (it takes a clamber to get over).
-- `alongX` says which way the corridor runs; `width` is the corridor's clear width.
function KillerRooms.buildBarricade(parent: Instance, position: Vector3, alongX: boolean, width: number, height: number)
	local size = if alongX then Vector3.new(3, height, width) else Vector3.new(width, height, 3)
	local barricade = Craft.block(parent, CFrame.new(position + Vector3.new(0, height / 2, 0)), size, Colors.Burlap, M.Wood)
	barricade.Name = "Barricade"
	breakable(barricade)
	CollectionService:AddTag(barricade, "Climbable")
	-- Darker boards across it, so it reads as a stack of crates.
	for k = 1, 3 do
		local board = Craft.block(parent, CFrame.new(position + Vector3.new(0, height * k / 4, 0)), size + (if alongX then Vector3.new(0.1, -size.Y + 0.4, -0.2) else Vector3.new(-0.2, -size.Y + 0.4, 0.1)), Colors.WoodDark, M.Wood, Craft.DECOR)
		board.Name = "BarricadeBoard"
	end
	return barricade
end

-- Gives a stage what it needs to hold doors and wardrobes.
function KillerRooms.setup(stage)
	stage.doors = {}
	stage.hiding = {}
	-- Round over (or the killer leaves): everyone climbs out and shows again.
	stage.releaseHidden = function()
		for player, entry in table.clone(stage.hiding) do
			climbOut(stage, entry.wardrobe, player, nil)
			local root = Util.rootPart(player)
			if root then
				root.Anchored = true -- the round is over and everyone is frozen; the round loop frees them later
			end
		end
	end
	stage.removingConnection = Players.PlayerRemoving:Connect(function(player)
		local entry = stage.hiding[player]
		if entry then
			stage.hiding[player] = nil
			entry.wardrobe.occupant = nil
		end
	end)
end

-- When the stage is torn down.
function KillerRooms.cleanup(stage)
	if stage.removingConnection then
		stage.removingConnection:Disconnect()
		stage.removingConnection = nil
	end
end

return KillerRooms
