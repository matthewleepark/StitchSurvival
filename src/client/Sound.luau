-- Plays the sounds listed in Config.Sounds. Missing IDs are skipped quietly.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Sound = {}

function Sound.play(name: string, position: Vector3?, volume: number?)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6

	if position then
		-- Put it in the world so it's louder when it's close to you.
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.Position = position
		holder.Parent = workspace
		sound.RollOffMaxDistance = 200
		sound.Parent = holder
		Debris:AddItem(holder, 8)
	else
		sound.Parent = SoundService
		Debris:AddItem(sound, 8)
	end
	sound:Play()
end

function Sound.startMusic()
	local id = Config.Sounds.Music
	if id == "" then
		return
	end
	local music = Instance.new("Sound")
	music.Name = "Music"
	music.SoundId = id
	music.Looped = true
	music.Volume = 0.25
	music.Parent = SoundService
	music:Play()
end

return Sound
