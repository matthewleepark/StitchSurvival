-- Client audio engine.
--   * Sound groups (Music, Ambient, Effects, Interface) so whole categories can be ducked at once.
--   * Music + tape hiss that change with the round phase (lobby -> loading dip -> level -> freeze).
--   * Room echo per stage: the lobby is a giant hollow toybox, the hotel a big hollow building,
--     the sea is open air, and everything goes muffled when your head is underwater.
--   * Sounds that have a wall or floor between them and you get muffled (anything tagged
--     "Occluded", like bombs, fire and the clock), so you can tell a bomb is on another floor.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundBank = require(ReplicatedStorage.Shared.SoundBank)
local Stages = require(script.Parent.Stages)

local player = Players.LocalPlayer

local Audio = {}

local groups: { [string]: SoundGroup } = {}
-- Each group's volume is the product of these factors, so a phase duck and a danger duck stack.
local factors: { [string]: { [string]: number } } = {}

local ROOM_REVERB = {
	Pod = Enum.ReverbType.Hangar, -- huge enclosed toybox: faint hollow echo, walls far away
	BombHotel = Enum.ReverbType.Auditorium, -- hollow, cavernous indoor space
	KillerHotel = Enum.ReverbType.Auditorium,
	SharkSurvival = Enum.ReverbType.Plain,
}

-- Footsteps get their own group so they stay crisp when the low-health muffle kicks in.
for _, name in { "Music", "Ambient", "Effects", "Footsteps", "Interface" } do
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Volume = 1
	group.Parent = SoundService
	groups[name] = group
	factors[name] = {}
end

-- Muffling: underwater muffles everything except the interface; low health muffles the music
-- and the world but leaves your footsteps (and the heartbeat, which is Interface) clear.
local muffles: { [string]: EqualizerSoundEffect } = {}
local muffleReasons = { underwater = false, danger = false }
for _, name in { "Music", "Ambient", "Effects", "Footsteps" } do
	local eq = Instance.new("EqualizerSoundEffect")
	eq.HighGain = -25
	eq.MidGain = -8
	eq.LowGain = 4
	eq.Enabled = false
	eq.Parent = groups[name]
	muffles[name] = eq
end

function Audio.setMuffle(reason: string, on: boolean)
	muffleReasons[reason] = on
	for name, eq in muffles do
		eq.Enabled = muffleReasons.underwater or (muffleReasons.danger and name ~= "Footsteps")
	end
end

local function applyVolume(groupName: string, seconds: number)
	local volume = 1
	for _, value in factors[groupName] do
		volume *= value
	end
	TweenService:Create(groups[groupName], TweenInfo.new(seconds), { Volume = volume }):Play()
end

-- Turn a whole group down (or back up). `key` lets different systems duck independently.
function Audio.setFactor(groupName: string, key: string, value: number, seconds: number?)
	factors[groupName][key] = value
	applyVolume(groupName, seconds or 0.4)
end

function Audio.group(name: string): SoundGroup
	return groups[name]
end

function Audio.create(name: string, groupName: string?): Sound?
	local sound = SoundBank.create(name)
	if sound then
		sound.SoundGroup = groups[groupName or "Effects"]
	end
	return sound
end

-- Play a one-shot sound. `where` can be a world position, a part to attach to, or nil for
-- a flat sound in both ears (music stings, UI).
function Audio.play(name: string, where: (Vector3 | Instance)?, groupName: string?, speedScale: number?): Sound?
	local sound = Audio.create(name, groupName)
	if not sound then
		return nil
	end
	if speedScale then
		sound.PlaybackSpeed *= speedScale
	end

	if typeof(where) == "Vector3" then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.Position = where
		holder.Parent = workspace
		sound.Parent = holder
		Debris:AddItem(holder, 10)
	elseif typeof(where) == "Instance" then
		sound.Parent = where
		Debris:AddItem(sound, 10)
	else
		sound.Parent = SoundService
		Debris:AddItem(sound, 10)
	end
	sound:Play()
	return sound
end

-- Music --------------------------------------------------------------------------------------

local currentMusicName: string? = nil
local currentMusic: Sound? = nil

function Audio.setMusic(name: string?)
	if not Config.Music.enabled then
		name = nil -- music is switched off in Config.Music
	end
	if name == currentMusicName then
		return
	end
	currentMusicName = name

	local old = currentMusic
	if old then
		local fade = TweenService:Create(old, TweenInfo.new(1.2), { Volume = 0 })
		fade.Completed:Connect(function()
			old:Destroy()
		end)
		fade:Play()
	end

	currentMusic = nil
	if not name then
		return
	end
	local music = Audio.create(name, "Music")
	if music then
		local target = music.Volume
		music.Looped = true
		music.Volume = 0
		music.Parent = SoundService
		music:Play()
		TweenService:Create(music, TweenInfo.new(1.5), { Volume = target }):Play()
		currentMusic = music
	end
end

local hiss: Sound? = nil
local function startHiss()
	if hiss then
		return
	end
	hiss = Audio.create("TapeHiss", "Ambient")
	if hiss then
		hiss.Looped = true
		hiss.Parent = SoundService
		hiss:Play()
	end
end

-- Round phases ---------------------------------------------------------------------------------

local inGame = false -- false while the title screen is up
local lastPhase: string? = nil

local function onPhase(phase: string?)
	local previous = lastPhase
	lastPhase = phase
	if not inGame or not phase then
		return
	end

	if phase == "Intermission" then
		for _, name in { "Music", "Ambient", "Effects", "Footsteps" } do
			Audio.setFactor(name, "phase", 1, 1)
		end
		Audio.setMusic("LobbyMusic")
		if previous == "Results" then
			-- Old level packed away, everyone swept back to the lobby.
			Audio.play("MapClear", nil, "Interface")
			task.delay(0.5, Audio.play, "PlayersWhoosh", nil, "Interface")
		end
	elseif phase == "Loading" then
		Audio.setFactor("Music", "phase", 0.5, 0.3)
		Audio.play("MapLoad", nil, "Interface")
		task.delay(0.35, Audio.play, "ToyboxTip", nil, "Interface")
	elseif phase == "Countdown" then
		Audio.setFactor("Music", "phase", 1, 0.5)
		Audio.setMusic("LevelMusic")
	elseif phase == "Results" then
		-- Clean click, and the whole world cuts to dead silence. (The fanfare and the coin
		-- shower play on the Interface group, which stays on.)
		Audio.play("Freeze", nil, "Interface")
		for _, name in { "Music", "Ambient", "Effects", "Footsteps" } do
			Audio.setFactor(name, "phase", 0, 0.05)
		end
	end
end

-- Called when the player presses PLAY on the title screen.
function Audio.beginGame()
	inGame = true
	startHiss()
	local phase = ReplicatedStorage:GetAttribute("Phase") :: string?
	lastPhase = nil
	onPhase(phase or "Intermission")
end

function Audio.startMenu()
	startHiss()
	Audio.setMusic("MenuMusic")
end

-- Rooms + underwater ---------------------------------------------------------------------------

local function updateRoom()
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local stage = Stages.find(head.Position)
	if not stage then
		return
	end

	local depth = stage.waterDepth
	local underwater = depth ~= nil and head.Position.Y < stage.origin.Y + depth - 0.3
	SoundService.AmbientReverb = if underwater then Enum.ReverbType.UnderWater else (ROOM_REVERB[stage.name] or Enum.ReverbType.NoReverb)
	Audio.setMuffle("underwater", underwater)
end

-- A big explosion drowns out the music for a moment and a half.
function Audio.blast()
	Audio.setFactor("Music", "blast", 0.05, 0.05)
	task.delay(1.5, Audio.setFactor, "Music", "blast", 1, 0.6)
end

-- Muffle sounds coming from behind a wall or floor ---------------------------------------------

local occludedParts: { [BasePart]: boolean } = {}
local occlusionParams = RaycastParams.new()
occlusionParams.FilterType = Enum.RaycastFilterType.Exclude
occlusionParams.IgnoreWater = true

local function occlusionFilter(sound: Sound): EqualizerSoundEffect
	local eq = sound:FindFirstChild("Occlusion") :: EqualizerSoundEffect?
	if eq then
		return eq
	end
	local new = Instance.new("EqualizerSoundEffect")
	new.Name = "Occlusion"
	new.HighGain = -30
	new.MidGain = -12
	new.LowGain = 2
	new.Parent = sound
	return new
end

local function updateOcclusion()
	local listener = workspace.CurrentCamera.CFrame.Position
	local character = player.Character
	for part in occludedParts do
		if not part.Parent then
			occludedParts[part] = nil
			continue
		end
		local ignore: { Instance } = { part }
		if character then
			table.insert(ignore, character)
		end
		occlusionParams.FilterDescendantsInstances = ignore
		local toSound = part.Position - listener
		local blocked = toSound.Magnitude > 2 and workspace:Raycast(listener, toSound, occlusionParams) ~= nil
		for _, child in part:GetChildren() do
			if child:IsA("Sound") then
				occlusionFilter(child).Enabled = blocked
			end
		end
	end
end

function Audio.start()
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
		onPhase(ReplicatedStorage:GetAttribute("Phase") :: string?)
	end)
	local function watchOccluded(instance: Instance)
		if instance:IsA("BasePart") then
			occludedParts[instance] = true
		end
	end
	for _, instance in CollectionService:GetTagged("Occluded") do
		watchOccluded(instance)
	end
	CollectionService:GetInstanceAddedSignal("Occluded"):Connect(watchOccluded)

	task.spawn(function()
		while true do
			updateRoom()
			updateOcclusion()
			task.wait(0.15)
		end
	end)
end

return Audio
