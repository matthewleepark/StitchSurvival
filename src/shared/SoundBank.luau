-- Turns an entry from Config.Sounds (or Config.Footsteps) into a Sound instance.
-- Used by both the server and the client so every sound is set up the same way.

local Config = require(script.Parent.Config)

export type SoundDef = {
	id: string,
	fallback: string?,
	volume: number?,
	speed: number?,
	looped: boolean?,
	range: number?,
}

local SoundBank = {}

function SoundBank.fromDef(def: SoundDef, name: string?): Sound?
	local id = if def.id ~= "" then def.id else def.fallback
	if not id or id == "" then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.Name = name or "Sound"
	sound.SoundId = id
	sound.Volume = def.volume or 0.5
	sound.PlaybackSpeed = def.speed or 1
	sound.Looped = def.looped == true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = def.range or 120
	return sound
end

-- Returns nil when the slot is empty, so callers can just skip playing it.
function SoundBank.create(name: string): Sound?
	local def = Config.Sounds[name]
	if not def then
		warn(`No sound named "{name}" in Config.Sounds`)
		return nil
	end
	return SoundBank.fromDef(def, name)
end

return SoundBank
