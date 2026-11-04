-- The horror look: a dark, cold, hazy night, with lamps that stutter now and then.
-- The numbers live in Config.Mood. Lights tagged "FlickerLight" (see HotelProps.luau) are the ones
-- that flicker; everything else stays steady.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Mood = {}

local FLICKER_TAG = "FlickerLight"

-- Reuses an effect if the place already has one, so pressing Play twice never stacks them.
local function effect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created
end

local function applyLook()
	local m = Config.Mood
	Lighting.Ambient = m.ambient
	Lighting.OutdoorAmbient = m.outdoorAmbient
	Lighting.Brightness = m.brightness
	Lighting.ClockTime = m.clockTime
	Lighting.ExposureCompensation = m.exposure
	Lighting.EnvironmentDiffuseScale = 0.15
	Lighting.EnvironmentSpecularScale = 0.15
	Lighting.FogColor = m.fogColor
	Lighting.FogStart = m.fogStart
	Lighting.FogEnd = m.fogEnd

	local atmosphere = effect("Atmosphere", "MoodAtmosphere") :: Atmosphere
	atmosphere.Density = m.hazeDensity
	atmosphere.Offset = 0
	atmosphere.Color = m.fogColor
	atmosphere.Decay = m.fogColor
	atmosphere.Glare = 0
	atmosphere.Haze = 0

	local color = effect("ColorCorrectionEffect", "MoodColor") :: ColorCorrectionEffect
	color.Saturation = m.saturation
	color.Contrast = m.contrast
	color.TintColor = m.tint

	-- A little bloom so the warm lamps glow against the dark.
	local bloom = effect("BloomEffect", "MoodBloom") :: BloomEffect
	bloom.Intensity = 0.35
	bloom.Size = 20
	bloom.Threshold = 1.4
end

local function flickerLoop()
	local baseBrightness: { [PointLight]: number } = {}
	local lights: { PointLight } = {}

	local function add(instance: Instance)
		if instance:IsA("PointLight") and not baseBrightness[instance] then
			baseBrightness[instance] = instance.Brightness
			table.insert(lights, instance)
		end
	end
	for _, instance in CollectionService:GetTagged(FLICKER_TAG) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(FLICKER_TAG):Connect(add)

	-- Dims one light for a moment, sometimes twice, like a failing bulb.
	local function stutter(light: PointLight)
		local base = baseBrightness[light]
		task.spawn(function()
			for _ = 1, math.random(1, 2) do
				if not light.Parent then
					return
				end
				light.Brightness = base * 0.05
				task.wait(0.04 + math.random() * 0.12)
				if light.Parent then
					light.Brightness = base
				end
				task.wait(0.05 + math.random() * 0.1)
			end
		end)
	end

	local surgeRange = Config.Mood.surgeEvery
	local nextSurge = os.clock() + math.random(surgeRange[1], surgeRange[2])
	while true do
		task.wait(0.2)
		if #lights == 0 then
			continue
		end
		if os.clock() >= nextSurge then
			nextSurge = os.clock() + math.random(surgeRange[1], surgeRange[2])
			for _, light in lights do
				if math.random() < 0.7 then
					stutter(light)
				end
			end
		elseif math.random() < Config.Mood.lampChance then
			stutter(lights[math.random(1, #lights)])
		end
	end
end

function Mood.start()
	applyLook()
	task.spawn(flickerLoop)
end

return Mood
