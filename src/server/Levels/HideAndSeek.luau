-- Hide & Seek: one SEEKER hunts everyone else (the HIDERS) through a maze hotel full of rooms and wardrobes.
-- Numbers are in Config.HideAndSeek; the level's size and room settings are its Config.Levels entry.
--
--   * The building is the Killer Hotel maze (Levels/KillerMaze.luau) with more rooms and a wardrobe in every
--     one. Doors, wardrobes, running and clambering all work the same (KillerRooms.luau, Parkour.luau): the
--     seeker plays the killer's part there (stage.killer), so they can break locked doors and search wardrobes.
--   * HIDING TIME: when the round starts the seeker is frozen in the middle of the ground floor with their
--     screen covered for hideSeconds while the hiders scatter and hide. Then the seeker comes out, glowing
--     with a red aura so everyone can see them coming.
--   * CATCHING: the seeker catches a hider by getting within catchRange of them (not while they're in a
--     wardrobe: the seeker has to search it first). A caught hider is out (popped, and can spectate).
--   * DEBRIS: pieces of junk lie on every floor. Each hider can pick up ONE (hold the use key at it) and throw
--     it once (click or tap where to throw, or the throw key). If it hits the seeker, the seeker is stunned in
--     place for stunSeconds (then can't be stunned again for stunImmunitySeconds).
--   * Hiders win if anyone is still in when the timer runs out; the seeker wins by catching everyone.
--
-- Like Killer Hotel, who the seeker is lives only in `stage.killer` on the server, and each player is told
-- only their own role (the "Role" effect: "seeker" or "hider"). The red aura makes the seeker easy to spot.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)
local Daily = require(script.Parent.Parent.Daily)
local Data = require(script.Parent.Parent.Data)
local Remotes = require(script.Parent.Parent.Remotes)
local RoundControl = require(script.Parent.Parent.RoundControl)
local Score = require(script.Parent.Parent.Score)
local Util = require(script.Parent.Parent.Util)
local KillerMaze = require(script.Parent.KillerMaze)
local KillerRooms = require(script.Parent.KillerRooms)

local HideAndSeek = {}

local settings = Config.HideAndSeek
local MAP = Config.KillerHotel.map
local DOORS = Config.KillerHotel.doors

-- Rounds since each player was last the seeker: everyone gets a turn.
local roundsSinceSeeker: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(player)
	roundsSinceSeeker[player] = nil
end)

local function pickSeeker(participants: { Player }): Player
	local total = 0
	local weights = {}
	for _, player in participants do
		local weight = 1 + 0.5 * (roundsSinceSeeker[player] or 0)
		weights[player] = weight
		total += weight
	end
	local roll = math.random() * total
	for _, player in participants do
		roll -= weights[player]
		if roll <= 0 then
			return player
		end
	end
	return participants[#participants]
end

local function hidersStillIn(stage): number
	local count = 0
	for player in stage.innocents do
		if player.Parent and Util.aliveHumanoid(player) then
			count += 1
		end
	end
	return count
end

-- The live Hide & Seek stage while a round is being played, else nil.
local function playingStage()
	local stage = RoundControl.stage
	if RoundControl.levelName == "HideAndSeek" and stage and not stage.frozen and ReplicatedStorage:GetAttribute("Phase") == "Playing" then
		return stage
	end
	return nil
end

-- Debris ----------------------------------------------------------------------------------------------

local JUNK = {
	{ name = "Brick", size = Vector3.new(1.8, 0.9, 0.9), color = Color3.fromRGB(176, 74, 58), material = Enum.Material.Brick },
	{ name = "Plank", size = Vector3.new(2.6, 0.45, 0.9), color = Color3.fromRGB(150, 104, 62), material = Enum.Material.WoodPlanks },
	{ name = "Can", size = Vector3.new(1.3, 0.9, 0.9), color = Color3.fromRGB(200, 205, 212), material = Enum.Material.Metal, cylinder = true },
	{ name = "Shoe", size = Vector3.new(1.6, 0.8, 0.8), color = Color3.fromRGB(80, 110, 190), material = Enum.Material.Fabric },
}

local function pickUp(stage, piece: BasePart, prompt: ProximityPrompt, player: Player)
	if stage.frozen or ReplicatedStorage:GetAttribute("Phase") ~= "Playing" or not stage.innocents[player] then
		if stage.killer == player then
			Remotes.fire(player, "Announce", { text = "Only hiders can throw debris!", color = Config.Colors.Paper })
		end
		return
	end
	if stage.used[player] then
		Remotes.fire(player, "Announce", { text = "You already used your one throw this round!", color = Config.Colors.Paper })
		return
	end
	local character = player.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	if not character or not hand or stage.holding[player] or stage.hiding[player] or not Util.aliveHumanoid(player) or not piece.Anchored then
		return
	end
	prompt.Enabled = false
	piece.Anchored = false
	piece.CanCollide = false
	piece.Massless = true
	piece.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.3, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "HoldWeld"
	weld.Part0 = hand
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = character -- so it hides with them if they climb into a wardrobe
	stage.holding[player] = piece
	Util.playSound("GrabTack", piece)
	Remotes.fire(player, "Debris", { state = "holding", name = piece.Name })
end

-- Junk lying around each floor: in random corridor and room cells, never inside furniture or a barricade.
local function placeDebris(stage)
	local N, cell = MAP.cells, MAP.cell
	local W = N * cell
	local O = stage.origin
	local rng = Random.new(stage.seed + 7)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { stage.model }
	local folder = Instance.new("Folder")
	folder.Name = "Debris"
	folder.Parent = stage.model

	for f = 0, stage.floors - 1 do
		local placed, tries = 0, 0
		while placed < settings.debrisPerFloor and tries < settings.debrisPerFloor * 12 do
			tries += 1
			local c = rng:NextInteger(0, N * N - 1)
			if not stage.layout.floorData[f].void[c] then
				local x = -W / 2 + cell / 2 + (c % N) * cell + rng:NextNumber(-4, 4)
				local z = -W / 2 + cell / 2 + (c // N) * cell + rng:NextNumber(-4, 4)
				local floorY = O.Y + f * stage.floorHeight
				local spot = Vector3.new(O.X + x, floorY, O.Z + z)
				-- Nothing solid where it would sit (a crate, a bed, a barricade, a ramp, a wall).
				if #workspace:GetPartBoundsInBox(CFrame.new(spot + Vector3.new(0, 1.6, 0)), Vector3.new(3, 2.6, 3), overlap) == 0 then
					local kind = JUNK[rng:NextInteger(1, #JUNK)]
					local piece = Craft.block(folder, CFrame.new(spot + Vector3.new(0, kind.size.Y / 2 + 0.05, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), kind.size, kind.color, kind.material)
					if kind.cylinder then
						piece.Shape = Enum.PartType.Cylinder
					end
					piece.Name = kind.name
					piece.CanCollide = false
					piece:SetAttribute("ThrowDebris", true)
					-- A soft glow so it's easy to spot on a dark floor.
					local glow = Instance.new("PointLight")
					glow.Color = Color3.fromRGB(255, 236, 190)
					glow.Range = 7
					glow.Brightness = 0.7
					glow.Shadows = false
					glow.Parent = piece
					local prompt = Instance.new("ProximityPrompt")
					prompt.ActionText = "Pick up"
					prompt.ObjectText = `{kind.name} (1 throw)`
					prompt.KeyboardKeyCode = DOORS.openKey -- the maze's use key (E grabs walls)
					prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
					prompt.HoldDuration = 0.25
					prompt.MaxActivationDistance = 8
					prompt.RequiresLineOfSight = false
					prompt.Parent = piece
					prompt.Triggered:Connect(function(player: Player)
						pickUp(stage, piece, prompt, player)
					end)
					placed += 1
				end
			end
		end
	end
end

-- The seeker's red aura: a glow on their outline, a red light and embers drifting up around them.
local function addAura(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "SeekerAura"
	highlight.FillColor = settings.aura
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = settings.aura
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded -- walls still hide them
	highlight.Parent = character
	local light = Instance.new("PointLight")
	light.Name = "SeekerAura"
	light.Color = settings.aura
	light.Range = 16
	light.Brightness = 2.5
	light.Shadows = false
	light.Parent = root
	local embers = Instance.new("ParticleEmitter")
	embers.Name = "SeekerAura"
	embers.Color = ColorSequence.new(settings.aura, Color3.fromRGB(255, 140, 90))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.45, 0)
	embers.Transparency = NumberSequence.new(0.1, 1)
	embers.Lifetime = NumberRange.new(0.8, 1.4)
	embers.Speed = NumberRange.new(0.5, 1.5)
	embers.Acceleration = Vector3.new(0, 4, 0)
	embers.SpreadAngle = Vector2.new(180, 180)
	embers.Rate = 30
	embers.Parent = root
end

local function removeAura(character: Model?)
	if not character then
		return
	end
	for _, item in character:GetDescendants() do
		if item.Name == "SeekerAura" or item.Name == "StunStars" then
			item:Destroy()
		end
	end
end

-- Stun ------------------------------------------------------------------------------------------------

local function stun(stage, thrower: Player)
	local seeker = stage.killer
	local character = seeker and seeker.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not seeker or not character or not head or not Util.aliveHumanoid(seeker) then
		return
	end
	local now = os.clock()
	if now < stage.stunImmuneUntil then
		Remotes.fire(thrower, "Announce", { text = "Bonk! But the seeker was only just stunned. Too soon!", color = Config.Colors.Paper })
		return
	end
	stage.stunnedUntil = now + settings.stunSeconds
	stage.stunImmuneUntil = stage.stunnedUntil + settings.stunImmunitySeconds

	-- Dizzy stars over their head for everyone to see.
	local stars = Instance.new("BillboardGui")
	stars.Name = "StunStars"
	stars.Size = UDim2.fromOffset(180, 60)
	stars.StudsOffset = Vector3.new(0, 3.2, 0)
	stars.AlwaysOnTop = true
	stars.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Config.Colors.Gold
	label.TextStrokeTransparency = 0
	label.Text = "\u{1F4AB} STUNNED! \u{1F4AB}"
	label.Parent = stars
	stars.Parent = head
	Debris:AddItem(stars, settings.stunSeconds)

	Util.playSound("DebrisThud", head)
	Util.playSound("Oof", head)
	Remotes.fireAll("Announce", { text = `{thrower.DisplayName} stunned the seeker!`, color = thrower:GetAttribute("Color") })
	Remotes.fire(seeker, "Stunned", { seconds = settings.stunSeconds })
	Remotes.fireAll("Rumble", { position = head.Position })
	Score.add(thrower, settings.stunPoints, head.Position)
	Data.addStat(thrower, "stuns", 1)
	Daily.track(thrower, "stuns", 1)
end

-- Follows a thrown piece for a moment: if it touches the seeker, stun them.
local function trackThrow(stage, piece: BasePart, thrower: Player)
	local seeker = stage.killer
	local character = seeker and seeker.Character
	if not character then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { character }
	local last = piece.Position
	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not piece.Parent or stage.frozen or os.clock() - started > 2.5 then
			connection:Disconnect()
			return
		end
		local now = piece.Position
		local step = now - last
		local hit = if step.Magnitude > 0.05 then workspace:Spherecast(last, 1.3, step, params) else nil
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local close = root ~= nil and (root.Position - now).Magnitude < 3
		last = now
		if hit or close then
			connection:Disconnect()
			piece.AssemblyLinearVelocity = -piece.AssemblyLinearVelocity * 0.15 + Vector3.new(0, 8, 0) -- bonk, and it drops
			stun(stage, thrower)
		end
	end)
end

local function throw(player: Player, target: any)
	local stage = playingStage()
	if not stage then
		return
	end
	local piece = stage.holding[player]
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not piece or not character or not head or piece.Parent ~= character or not Util.aliveHumanoid(player) then
		return
	end
	if stage.hiding[player] then
		Remotes.fire(player, "Announce", { text = "Climb out of the wardrobe first!", color = Config.Colors.Paper })
		return
	end
	stage.holding[player] = nil
	stage.used[player] = true

	local from = head.Position + Vector3.new(0, 0.6, 0)
	local direction
	if typeof(target) == "Vector3" and (target - from).Magnitude > 1 then
		direction = (target - from).Unit
	else
		local flat = Util.flatten(head.CFrame.LookVector)
		direction = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
	end
	-- Let go just in front of the face, unless a wall is right there.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local start = from + direction * 2
	if workspace:Raycast(head.Position, start - head.Position, params) then
		start = head.Position
	end

	local weld = piece:FindFirstChild("HoldWeld")
	if weld then
		weld:Destroy()
	end
	piece.Parent = stage.model
	piece.Massless = false
	piece.CanCollide = true
	piece.CFrame = CFrame.new(start)
	piece:SetNetworkOwner(nil) -- the server flies it, so nobody can steer it into the seeker
	piece.AssemblyLinearVelocity = direction * settings.throwSpeed + Vector3.new(0, settings.throwLift, 0)
	piece.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12))
	Util.playSound("GrabRelease", piece)
	Remotes.fire(player, "Debris", { state = "used" })
	trackThrow(stage, piece, player)
	Debris:AddItem(piece, 12)
end

-- Round hooks -----------------------------------------------------------------------------------------

function HideAndSeek.build(def)
	local stage = KillerMaze.build(def)
	stage.killer = nil :: Player? -- the seeker; server only, never put this in an attribute
	stage.innocents = {} :: { [Player]: boolean } -- the hiders
	stage.hadInnocents = false
	stage.seekFrom = math.huge -- when the seeker is let out
	stage.stunnedUntil = 0
	stage.stunImmuneUntil = 0
	stage.used = {} :: { [Player]: boolean } -- hiders who have thrown their one piece
	stage.holding = {} :: { [Player]: BasePart }
	stage.spared = {} :: { [Player]: number } -- saved by a second chance: not catchable again for a moment
	stage.onHide = function(player: Player)
		Daily.track(player, "hides", 1)
	end
	placeDebris(stage)
	return stage
end

-- After everyone is sent in, before the countdown: pick the seeker, tell everyone their role.
function HideAndSeek.begin(stage, participants: { Player })
	local minimum = if settings.soloTest then 1 else 2
	if #participants < minimum then
		return -- no seeker: isOver ends the round at once
	end
	local seeker = pickSeeker(participants)
	stage.killer = seeker
	for _, player in participants do
		if player == seeker then
			roundsSinceSeeker[player] = 0
		else
			stage.innocents[player] = true
			roundsSinceSeeker[player] = (roundsSinceSeeker[player] or 0) + 1
		end
	end
	stage.hadInnocents = next(stage.innocents) ~= nil
	if seeker.Character then
		seeker.Character:PivotTo(stage.killerSpawn)
		addAura(seeker.Character)
	end
	local banner = Config.KillerHotel.roleBannerSeconds
	Remotes.fire(seeker, "Role", { role = "seeker", seconds = banner })
	for player in stage.innocents do
		Remotes.fire(player, "Role", { role = "hider", seconds = banner })
	end
	ReplicatedStorage:SetAttribute("InnocentsLeft", hidersStillIn(stage))
end

function HideAndSeek.run(stage, ctx)
	local seeker = stage.killer
	stage.seekFrom = os.clock() + settings.hideSeconds
	if seeker then
		Remotes.fire(seeker, "Blindfold", { seconds = settings.hideSeconds })
	end
	for player in stage.innocents do
		Remotes.fire(player, "HidePhase", { seconds = settings.hideSeconds })
	end
	local released = false

	while ctx.isActive() and not stage.frozen do
		local now = os.clock()
		ReplicatedStorage:SetAttribute("InnocentsLeft", hidersStillIn(stage))
		seeker = stage.killer
		local root = seeker and Util.rootPart(seeker)

		-- Held in place while counting, and while stunned.
		local held = now < stage.seekFrom or now < stage.stunnedUntil
		if root and root.Anchored ~= held then
			root.Anchored = held
		end
		if not released and now >= stage.seekFrom then
			released = true
			Util.playSound("AlarmBuzz", root or stage.model)
			for player in stage.innocents do
				Remotes.fire(player, "SeekerOut")
			end
			if seeker then
				Remotes.fire(seeker, "SeekerOut")
			end
		end

		-- Catching: anyone the seeker reaches who isn't tucked away in a wardrobe.
		if not held and root and seeker and Util.aliveHumanoid(seeker) then
			for hider in stage.innocents do
				local hiderRoot = Util.rootPart(hider)
				local humanoid = Util.aliveHumanoid(hider)
				if hiderRoot and humanoid and not stage.hiding[hider] and now >= (stage.spared[hider] or 0) then
					local offset = hiderRoot.Position - root.Position
					if Util.flatten(offset).Magnitude <= settings.catchRange and math.abs(offset.Y) < 5 then
						if Util.kill(humanoid) then
							Remotes.fireAll("Popup", { text = "FOUND!", position = hiderRoot.Position, color = settings.aura })
							Score.add(seeker, settings.catchPoints, hiderRoot.Position)
						else
							stage.spared[hider] = now + 2 -- a second chance (or god mode): a moment to run
						end
					end
				end
			end
		end
		task.wait(0.1)
	end
end

function HideAndSeek.isOver(stage, alive: { [Player]: boolean }): boolean
	local seeker = stage.killer
	if not seeker or not alive[seeker] then
		return true
	end
	if stage.hadInnocents then
		for player in stage.innocents do
			if alive[player] then
				return false
			end
		end
		return true
	end
	return false -- solo test: run until the timer or an admin ends it
end

function HideAndSeek.finish(stage, alive: { [Player]: boolean })
	local seeker = stage.killer
	local winners: { [Player]: boolean } = {}
	local hidersAlive = 0
	for player in stage.innocents do
		if alive[player] then
			winners[player] = true
			hidersAlive += 1
		end
	end

	local text
	if not seeker then
		table.clear(winners)
		text = "Hide & Seek needs two players"
	elseif not alive[seeker] then
		text = if hidersAlive > 0 then "The seeker is out! Hiders win!" else "Nobody made it"
	elseif stage.hadInnocents and hidersAlive == 0 then
		table.clear(winners)
		winners[seeker] = true
		text = "The seeker found everyone!"
	else
		text = if hidersAlive > 0 then "Time's up! The hiders win!" else "Time's up"
	end

	if seeker and seeker.Parent then
		Remotes.fireAll("Announce", { text = `{seeker.DisplayName} was the seeker!`, color = Config.HideAndSeek.aura })
		removeAura(seeker.Character)
	end
	Remotes.fireAll("Role", { role = "none" })
	Remotes.fireAll("Debris", { state = "none" })
	ReplicatedStorage:SetAttribute("InnocentsLeft", nil)
	for _, piece in stage.holding do
		piece:Destroy()
	end
	table.clear(stage.holding)
	stage.releaseHidden() -- everyone climbs out of the wardrobes
	return { winners = winners, text = text }
end

function HideAndSeek.cleanup(stage)
	KillerRooms.cleanup(stage)
	if stage.killer then
		removeAura(stage.killer.Character)
	end
end

-- Round over: everything stops exactly where it is.
function HideAndSeek.freeze(stage)
	stage.frozen = true
	for _, part in stage.model:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.Anchored = true
		end
	end
end

Remotes.ThrowDebris.OnServerEvent:Connect(throw)

return HideAndSeek
