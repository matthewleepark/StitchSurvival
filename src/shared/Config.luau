-- Everything you might want to tweak lives here: layout, timing, scoring, colors, gear, sounds.

local Config = {}

-- Rounds ---------------------------------------------------------------------

Config.MinPlayers = 1
Config.IntermissionTime = 60 -- lower this (e.g. 10) while testing so you don't wait a full minute
Config.LoadingTime = 3 -- the "map tipping out of the toybox" moment before teleporting
Config.CountdownTime = 3
Config.RoundTime = 120
Config.ResultsTime = 7

-- Bomb Hotel: a planted time bomb appears this often, beeps faster and faster, then
-- blows a hole through the floors, collapses the blocks around it and starts a fire.
Config.PlantedBombInterval = 15
Config.PlantedBombFuse = 8

-- Scoring (LBP-style: points, score bubbles, and a combo multiplier) ---------

Config.SurvivalPointsPerSecond = 5
Config.BubblePoints = 10
Config.MaxMultiplier = 8
Config.MultiplierWindow = 4 -- grab another bubble within this many seconds to keep the combo
Config.SurviveBonus = 500
Config.PointsPerSticker = 50

Config.StartingStickers = 40
Config.RollCost = 20

-- Each player gets a color, like the blue/pink/green/yellow players in LBP.
Config.PlayerColors = {
	Color3.fromRGB(70, 150, 255),
	Color3.fromRGB(255, 105, 180),
	Color3.fromRGB(100, 210, 90),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(170, 110, 230),
	Color3.fromRGB(255, 140, 60),
}

-- Stage layout ---------------------------------------------------------------
-- Every stage is a side-on diorama. Players move left/right, and W/S hops between
-- three depth layers. The camera always looks at the stage from the front (+Z).

Config.Layers = { -5, 0, 5 }
Config.StageDepth = 16

Config.Pod = {
	origin = Vector3.new(0, 20, 0),
	width = 64,
	height = 36,
}

Config.Levels = {
	{
		name = "BombHotel",
		title = "Bomb Hotel",
		weight = 50,
		origin = Vector3.new(0, 20, 400),
		width = 96,
		height = 96,
		floors = 5, -- the lobby plus four breakable foam floors above it
	},
	{
		name = "SharkSurvival",
		title = "Shark Survival",
		weight = 50,
		origin = Vector3.new(0, 20, 800),
		width = 112,
		height = 48,
		waterDepth = 20,
	},
}

-- Look -----------------------------------------------------------------------

Config.Colors = {
	Cardboard = Color3.fromRGB(196, 154, 108),
	CardboardDark = Color3.fromRGB(150, 111, 72),
	Foam = Color3.fromRGB(244, 244, 236),
	FoamShade = Color3.fromRGB(222, 222, 210),
	Felt = Color3.fromRGB(214, 84, 84),
	Wood = Color3.fromRGB(166, 116, 72),
	WoodDark = Color3.fromRGB(110, 72, 45),
	Paper = Color3.fromRGB(250, 240, 214),
	Ink = Color3.fromRGB(60, 42, 30),
	Warning = Color3.fromRGB(255, 150, 40),
	Gold = Color3.fromRGB(250, 200, 60),
	Burlap = Color3.fromRGB(170, 128, 84),
	Bomb = Color3.fromRGB(38, 34, 42),
	Sky = Color3.fromRGB(150, 205, 240),
	Sea = Color3.fromRGB(70, 145, 215),
	SeaDeep = Color3.fromRGB(35, 80, 150),
	Sand = Color3.fromRGB(230, 200, 140),
	Seaweed = Color3.fromRGB(60, 150, 80),
	Bubble = Color3.fromRGB(190, 235, 255),
}

-- One wallpaper per hotel floor, bottom to top: { base, stripe }.
Config.Wallpapers = {
	{ Color3.fromRGB(196, 86, 86), Color3.fromRGB(172, 66, 66) },
	{ Color3.fromRGB(92, 140, 190), Color3.fromRGB(74, 118, 168) },
	{ Color3.fromRGB(120, 168, 98), Color3.fromRGB(98, 146, 80) },
	{ Color3.fromRGB(214, 172, 92), Color3.fromRGB(190, 148, 72) },
	{ Color3.fromRGB(160, 110, 180), Color3.fromRGB(138, 90, 160) },
}

-- Characters become little knitted dolls with a zipper in their player color.
Config.Doll = {
	Enabled = true,
	RemoveClothing = true,
}

-- Scuba gear (the RNG) ----------------------------------------------------------
-- Players roll at the gear machine in the lobby. More oxygen = longer underwater.
-- You always keep your best gear, so a bad roll never makes you worse.

Config.DefaultOxygen = 5
Config.Gear = {
	{ name = "Paper Snorkel", rarity = "Common", weight = 60, oxygen = 8 },
	{ name = "Bubble Wrap Suit", rarity = "Uncommon", weight = 25, oxygen = 12 },
	{ name = "Tin Can Helmet", rarity = "Rare", weight = 10, oxygen = 18 },
	{ name = "Clockwork Diving Bell", rarity = "Epic", weight = 4, oxygen = 28 },
	{ name = "Golden Fishbowl", rarity = "Legendary", weight = 1, oxygen = 45 },
}

Config.RarityColors = {
	Common = Color3.fromRGB(180, 170, 150),
	Uncommon = Color3.fromRGB(110, 190, 100),
	Rare = Color3.fromRGB(80, 150, 230),
	Epic = Color3.fromRGB(170, 90, 220),
	Legendary = Color3.fromRGB(250, 190, 40),
}

function Config.getGear(name: string?)
	for _, gear in Config.Gear do
		if gear.name == name then
			return gear
		end
	end
	return nil
end

-- Sounds -----------------------------------------------------------------------
-- Every sound in the game is listed here. To fill one in, find audio in Studio
-- (Toolbox > Audio, or the Creator Store website), copy its ID and paste it as
--     id = "rbxassetid://1234567890"
-- Some slots have a `fallback`: a sound built into Roblox that plays until you add your own.
-- Slots with no id and no fallback are silent (the visuals still play).
--
--   volume  0 to 1 (ish)
--   speed   playback speed; also changes pitch (2 = an octave higher)
--   looped  keeps playing until stopped
--   range   how far away (in studs) you can still hear it, for sounds placed in the world

local BUILTIN = "rbxasset://sounds/"

Config.Sounds = {
	-- Music + background ------------------------------------------------------
	MenuMusic = { id = "", volume = 0.4, looped = true }, -- bouncy, slightly out-of-tune acoustic guitar + playful marimba
	LobbyMusic = { id = "", volume = 0.35, looped = true }, -- steady acoustic guitar loop, soft tambourine every fourth beat
	LevelMusic = { id = "", volume = 0.35, looped = true }, -- fast, frantic marimba with a bouncy bassline
	TapeHiss = { id = "", volume = 0.08, looped = true }, -- soft analog hiss of a bedroom tape recorder

	-- Menus / HUD ------------------------------------------------------------------
	ButtonHover = { id = "", fallback = BUILTIN .. "volume_slider.ogg", volume = 0.35, speed = 2.2 }, -- crisp bubble-wrap pop
	ButtonClick = { id = "", fallback = BUILTIN .. "volume_slider.ogg", volume = 0.6, speed = 0.7 }, -- clack-whir of a View-Master changing reels
	TallyClick = { id = "", fallback = BUILTIN .. "volume_slider.ogg", volume = 0.25, speed = 3 }, -- old mechanical tally counter ticking over
	Countdown = { id = "", fallback = BUILTIN .. "volume_slider.ogg", volume = 0.7, speed = 1.2 },
	Go = { id = "", fallback = BUILTIN .. "volume_slider.ogg", volume = 0.9, speed = 1.8 },
	GearRoll = { id = "", volume = 0.6 }, -- gumball machine crank

	-- Round flow ---------------------------------------------------------------------
	MapClear = { id = "", volume = 0.5 }, -- structural clink-clack as the old level is packed away
	PlayersWhoosh = { id = "", volume = 0.5 }, -- wide sweeping whoosh of empty air
	MapLoad = { id = "", volume = 0.7 }, -- heavy mechanical thump-chunk
	ToyboxTip = { id = "", volume = 0.6 }, -- a big box of wooden/cardboard toys tipped onto a hardwood floor
	TeleportPop = { id = "", fallback = BUILTIN .. "volume_slider.ogg", volume = 0.5, speed = 1.6, range = 80 }, -- pop!
	Freeze = { id = "", fallback = BUILTIN .. "volume_slider.ogg", volume = 0.8, speed = 0.5 }, -- sudden clean click that freezes everything
	Fanfare = { id = "", volume = 0.8 }, -- brassy toy-trumpet "Ta-da-da-daaa!"
	CoinClink = { id = "", volume = 0.4, range = 60 }, -- plastic tokens raining down, clink-clink-clink

	-- Bomb Hotel -----------------------------------------------------------------------
	HotelHum = { id = "", volume = 0.15, looped = true, range = 200 }, -- cozy building hum
	ClockTock = { id = "", volume = 0.5, looped = true, range = 60 }, -- heavy wooden grandfather-clock tock... tock...
	AlarmBuzz = { id = "", volume = 0.7, range = 200 }, -- alarming buzz-whir as the round kicks off
	EggTimer = { id = "", volume = 0.5, looped = true, range = 200 }, -- egg timer spring grinding: Zzzzzzz
	BombBell = { id = "", volume = 0.7, range = 120 }, -- sharp metal bicycle bell "ping": a new bomb appeared
	BombBeep = { id = "", fallback = BUILTIN .. "volume_slider.ogg", volume = 0.7, speed = 2.6, range = 30 }, -- bright electronic beep
	BombTone = { id = "", volume = 0.8, looped = true, range = 30 }, -- the solid "Beeeeeee" right before it goes off
	Tick = { id = "", fallback = BUILTIN .. "volume_slider.ogg", volume = 0.3, speed = 3, range = 40 }, -- falling bombs' fuse click
	Bang = { id = "", fallback = BUILTIN .. "impact_explosion_03.mp3", volume = 1, range = 250 }, -- CRACK-FOOM: giant paper bag pop + thunder clap
	VelcroRip = { id = "", volume = 0.8, range = 150 }, -- riiiiip of industrial Velcro as walls tear loose
	BlockBreak = { id = "", volume = 0.6, range = 100 }, -- dry wood snapping + phonebook ripping
	DebrisThud = { id = "", fallback = BUILTIN .. "action_jump_land.mp3", volume = 0.8, speed = 0.5, range = 100 }, -- heavy hollow thud-clatter
	Crush = { id = "", fallback = BUILTIN .. "action_jump_land.mp3", volume = 1, speed = 0.35, range = 80 }, -- wet heavy squish (crushed!)
	FireCrackle = { id = "", volume = 0.5, looped = true, range = 50 }, -- stiff orange cellophane being crinkled

	-- Shark Survival ------------------------------------------------------------------------
	WaterRustle = { id = "", volume = 0.25, looped = true, range = 250 }, -- thousands of tissue-paper pieces stirred by a fan
	SharkMotor = { id = "", volume = 0.6, looped = true, range = 90 }, -- clockwork whir-click-whir (pitched up when it hunts)
	Breach = { id = "", fallback = BUILTIN .. "impact_water.mp3", volume = 0.9, range = 150 }, -- violent RIP-CRUNCH as it breaks the surface
	Chomp = { id = "", volume = 0.9, range = 120 }, -- blunt CLACK of two thick plywood slabs
	PlatformSnap = { id = "", volume = 0.8, range = 120 }, -- wooden popsicle stick SNAP
	PlatformSink = { id = "", volume = 0.6, range = 100 }, -- fizz-muffle / gurgle-glug as it sinks
	PlatformSwish = { id = "", volume = 0.4, range = 60 }, -- soft swish-shhh against the paper ocean
	Splash = { id = "", fallback = BUILTIN .. "impact_water.mp3", volume = 0.7, range = 120 },

	-- Players ----------------------------------------------------------------------------------
	Jump = { id = "", fallback = BUILTIN .. "action_jump.mp3", volume = 0.5, speed = 1.5, range = 60 }, -- tight boing / plucked guitar string
	LandSoft = { id = "", fallback = BUILTIN .. "action_jump_land.mp3", volume = 0.5, speed = 1.1, range = 60 }, -- soft fabric pouf
	LandHeavy = { id = "", fallback = BUILTIN .. "action_jump_land.mp3", volume = 1, speed = 0.65, range = 80 }, -- heavy THUMP-CLACK, limbs rattling
	Oof = { id = "", fallback = BUILTIN .. "oof.ogg", volume = 0.6, range = 80 }, -- hollow beanbag "oof!"
	Zipper = { id = "", volume = 0.5, range = 60 }, -- zzzzt: your health ribbon unzipping
	Heartbeat = { id = "", fallback = BUILTIN .. "action_jump_land.mp3", volume = 0.9, speed = 0.4 }, -- heavy wool sack thump-thump
	Flop = { id = "", fallback = BUILTIN .. "action_jump_land.mp3", volume = 0.7, speed = 0.8, range = 80 }, -- soft weighted parts tumbling
	SlideWhistle = { id = "", volume = 0.7, range = 120 }, -- sad descending slide whistle "fweeeeooooo"
	GrabTack = { id = "", fallback = BUILTIN .. "volume_slider.ogg", volume = 0.6, speed = 0.9, range = 60 }, -- duct tape slapped on a table
	GrabCreak = { id = "", volume = 0.4, looped = true, range = 50 }, -- yarn straining creak-uuuup-creak
	GrabRelease = { id = "", fallback = BUILTIN .. "volume_slider.ogg", volume = 0.5, speed = 2.6, range = 60 }, -- rubber band flick
	BubblePop = { id = "", fallback = BUILTIN .. "volume_slider.ogg", volume = 0.6, speed = 3.2, range = 80 }, -- glassy "ting!" (marble on crystal)
}

-- Footsteps change with what you're standing on. Each material picks a footstep style below.
-- Paste a looping footstep sound into `id` to replace the built-in one for that style.
Config.Footsteps = {
	Cardboard = { id = "", fallback = BUILTIN .. "action_footsteps_plastic.mp3", volume = 0.45, speed = 1.35, echo = true }, -- hollow papery pitter-patter
	Felt = { id = "", fallback = BUILTIN .. "action_footsteps_plastic.mp3", volume = 0.35, speed = 0.8, muffled = true }, -- muffled thump, zero ring
	Wood = { id = "", fallback = BUILTIN .. "action_footsteps_plastic.mp3", volume = 0.6, speed = 1.1, bright = true }, -- bright wooden-block clink-clack
	Foam = { id = "", fallback = BUILTIN .. "action_footsteps_plastic.mp3", volume = 0.4, speed = 1.55, echo = true }, -- squeaky polystyrene
}

-- Which footstep style each surface material uses (anything not listed uses Cardboard).
Config.FootstepMaterials = {
	Cardboard = "Cardboard",
	Fabric = "Felt",
	Carpet = "Felt",
	Sand = "Felt",
	Wood = "Wood",
	WoodPlanks = "Wood",
	Plaster = "Foam",
	SmoothPlastic = "Foam",
}

return Config
