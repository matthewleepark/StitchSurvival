-- Sounds for every doll in the game (yours and other players'):
--   footsteps that change with the floor material, a boing when jumping, a pouf or a heavy
--   thump when landing, an "oof" plus a zipper when hurt, and a slide whistle when popped.
-- The default Roblox running/jumping/landing/death sounds are muted so these replace them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundBank = require(ReplicatedStorage.Shared.SoundBank)
local Audio = require(script.Parent.Audio)


local REPLACED_DEFAULTS = { Running = true, Jumping = true, Landing = true, Died = true }

local CharacterAudio = {}

type Tracked = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	steps: { [string]: Sound },
	activeStyle: string?,
	lowestFall: number,
	floorPart: BasePart?,
	floorY: number,
	pitch: number,
	lastVelocityY: number,
}

local tracked: { [Model]: Tracked } = {}

-- Footstep loop for one style, with the effect that gives it its character.
local function footstepSound(root: BasePart, style: string): Sound?
	local def = Config.Footsteps[style]
	local sound = def and SoundBank.fromDef(def, "Footsteps" .. style)
	if not sound then
		return nil
	end
	sound.Looped = true
	sound.RollOffMaxDistance = 50
	sound.SoundGroup = Audio.group("Footsteps")

	if def.muffled then
		-- Felt: soft thump, no ring at all.
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain = -30
		eq.MidGain = -12
		eq.LowGain = 3
		eq.Parent = sound
	elseif def.echo then
		-- Cardboard/foam: a slight papery echo.
		local echo = Instance.new("EchoSoundEffect")
		echo.Delay = 0.09
		echo.Feedback = 0.15
		echo.WetLevel = -10
		echo.DryLevel = 0
		echo.Parent = sound
	elseif def.bright then
		-- Wood: bright clink-clack.
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain = 5
		eq.Parent = sound
	end

	sound.Parent = root
	return sound
end

local function muteDefaults(root: BasePart)
	local function mute(instance: Instance)
		if instance:IsA("Sound") and REPLACED_DEFAULTS[instance.Name] then
			instance.Volume = 0
			instance:GetPropertyChangedSignal("Volume"):Connect(function()
				if instance.Volume ~= 0 then
					instance.Volume = 0
				end
			end)
		end
	end
	for _, child in root:GetChildren() do
		mute(child)
	end
	root.ChildAdded:Connect(mute)
end

local function stopSteps(entry: Tracked)
	for _, sound in entry.steps do
		if sound.Playing then
			sound:Stop()
		end
	end
	entry.activeStyle = nil
end

local function track(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return
	end
	muteDefaults(root)

	local entry: Tracked = {
		character = character,
		humanoid = humanoid,
		root = root,
		steps = {},
		activeStyle = nil,
		lowestFall = 0,
		floorPart = nil,
		floorY = 0,
		pitch = 1,
		lastVelocityY = 0,
	}
	tracked[character] = entry

	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			Audio.play("Jump", root)
			entry.lowestFall = 0
		elseif new == Enum.HumanoidStateType.Freefall then
			entry.lowestFall = 0
		elseif new == Enum.HumanoidStateType.Landed then
			-- Just a soft landing sound; no heavy slam, screen shake or stagger.
			Audio.play("LandSoft", root)
			entry.lowestFall = 0
		end
	end)

	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth - 0.5 and health > 0 then
			Audio.play("Oof", root)
			Audio.play("Zipper", root)
		end
		lastHealth = health
	end)

	humanoid.Died:Connect(function()
		stopSteps(entry)
		local where = root.Position
		Audio.play("SlideWhistle", where)
		for i = 1, 3 do
			task.delay(0.12 + i * 0.16, Audio.play, "Flop", where, "Effects", 0.8 + math.random() * 0.5)
		end
	end)

	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			tracked[character] = nil
		end
	end)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function update(dt: number)
	for character, entry in tracked do
		local humanoid, root = entry.humanoid, entry.root
		if humanoid.Health <= 0 or not root.Parent then
			continue
		end

		local velocityY = root.AssemblyLinearVelocity.Y
		if velocityY < entry.lowestFall then
			entry.lowestFall = velocityY
		end
		-- At the very top of a jump: a low whoosh of air.
		if entry.lastVelocityY > 2 and velocityY <= 0 and humanoid.FloorMaterial == Enum.Material.Air then
			Audio.play("JumpWhoosh", root)
		end
		entry.lastVelocityY = velocityY

		local state = humanoid:GetState()
		local walking = humanoid.MoveDirection.Magnitude > 0.1
			and humanoid.FloorMaterial ~= Enum.Material.Air
			and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics)

		if not walking then
			-- Includes the top of a jump: the steps simply stop.
			if entry.activeStyle then
				stopSteps(entry)
			end
			continue
		end

		-- If the floor under you is sinking, the footsteps slur downward.
		rayParams.FilterDescendantsInstances = { character }
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), rayParams)
		local targetPitch = 1
		if hit and hit.Instance:IsA("BasePart") then
			local part = hit.Instance :: BasePart
			if part == entry.floorPart then
				local fallSpeed = (entry.floorY - part.Position.Y) / math.max(dt, 1 / 240)
				if fallSpeed > 1 then
					targetPitch = math.clamp(1 - fallSpeed * 0.04, 0.55, 1)
				end
			end
			entry.floorPart = part
			entry.floorY = part.Position.Y
		end
		entry.pitch += (targetPitch - entry.pitch) * math.min(1, dt * 6)

		local style = Config.FootstepMaterials[humanoid.FloorMaterial.Name] or "Cardboard"
		if style ~= entry.activeStyle then
			stopSteps(entry)
			if not entry.steps[style] then
				local sound = footstepSound(root, style)
				if sound then
					entry.steps[style] = sound
				end
			end
			local sound = entry.steps[style]
			if sound then
				sound:Play()
			end
			entry.activeStyle = style
		end

		local sound = entry.steps[style]
		if sound then
			local def = Config.Footsteps[style]
			sound.PlaybackSpeed = (def.speed or 1) * (humanoid.WalkSpeed / Config.Doll.WalkSpeed) * entry.pitch
		end
	end
end

function CharacterAudio.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(track, character)
		end)
		if player.Character then
			task.spawn(track, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	RunService.Heartbeat:Connect(update)
end

return CharacterAudio
