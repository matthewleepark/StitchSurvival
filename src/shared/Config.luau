-- Everything you might want to tweak lives here: layout, timing, scoring, colors, gear, sounds.

local Config = {}

-- Rounds ---------------------------------------------------------------------

Config.MinPlayers = 1
Config.IntermissionTime = 60 -- lower this (e.g. 10) while testing so you don't wait a full minute
Config.LoadingTime = 3 -- the "map tipping out of the toybox" moment before teleporting
Config.CountdownTime = 3
Config.RoundTime = 120
Config.ResultsTime = 7

-- World physics: a floaty, low-gravity toybox (Roblox's normal gravity is 196.2).
Config.Gravity = 35

-- Bomb Hotel: every 15 seconds a bomb is dropped at a random spot inside the hotel. Its timer
-- ticks twice a second, doubles speed for the last 5 seconds, then it explodes: everything
-- within 25 studs (floor blocks, pillars, ramps) is ripped loose and thrown outward.
Config.PlantedBombInterval = 15
Config.PlantedBombFuse = 12
Config.PlantedBombBlastRadius = 25

-- Shark Survival: the shark switches from patrolling to hunting when a player is this close.
Config.SharkHuntRadius = 45

-- Scoring: each score bubble is worth 10 points. Raise MaxMultiplier (e.g. to 8) to turn on
-- LBP-style combos, where grabbing bubbles quickly multiplies their value.

Config.SurvivalPointsPerSecond = 5
Config.BubblePoints = 10
Config.MaxMultiplier = 1
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
-- Every stage is a full 3D space with the normal Roblox third-person camera.
-- origin = the center of the stage's floor. width = left-right (X), depth = front-back (Z).

Config.Pod = {
	origin = Vector3.new(0, 20, 0),
	width = 64,
	depth = 48,
	height = 36,
}

Config.Levels = {
	{
		name = "BombHotel",
		title = "Bomb Hotel",
		weight = 50,
		origin = Vector3.new(0, 20, 400),
		width = 96,
		depth = 96,
		floors = 5, -- the lobby plus four breakable foam floors above it
		floorHeight = 16, -- studs from one floor to the next (ramps get longer if you raise it)
		height = 5 * 16 + 20,
	},
	{
		name = "SharkSurvival",
		title = "Shark Survival",
		weight = 50,
		origin = Vector3.new(0, 20, 900),
		width = 300,
		depth = 300,
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
	Scale = 0.6, -- shrinks avatars to about 3 studs tall, like a little sack doll
	Ragdoll = true, -- when popped, all the joints go loose instead of falling apart
}

-- Below this fraction of health the heartbeat starts and the world sounds muffled.
Config.LowHealth = 0.4

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
	BombTick = { id = "", fallback = BUILTIN .. "volume_slider.ogg", volume = 0.7, speed = 2.6, range = 30 }, -- the bomb's egg-timer tick (twice a second, then double speed)
	FuseHiss = { id = "", volume = 0.5, looped = true, range = 30 }, -- sputtering fuse hiss, ssssss-krrr-ssss, like a burning flare
	BombLand = { id = "", fallback = BUILTIN .. "action_jump_land.mp3", volume = 0.8, speed = 0.55, range = 60 }, -- heavy hollow thud as a bomb hits the floor
	Bang = { id = "", fallback = BUILTIN .. "impact_explosion_03.mp3", volume = 1, range = 250 }, -- CRACK-FOOM: giant paper bag pop + thunder clap
	VelcroRip = { id = "", volume = 0.8, range = 150 }, -- riiiiip of industrial Velcro as walls tear loose
	BlockBreak = { id = "", volume = 0.6, range = 100 }, -- dry wood snapping + phonebook ripping
	DebrisThud = { id = "", fallback = BUILTIN .. "action_jump_land.mp3", volume = 0.8, speed = 0.5, range = 100 }, -- heavy hollow thud-clatter
	DebrisWhistle = { id = "", volume = 0.5, range = 80 }, -- descending fshhhhh as a block falls through the air
	Rumble = { id = "", fallback = BUILTIN .. "action_jump_land.mp3", volume = 0.7, speed = 0.3, range = 60 }, -- low grrrr-whump through the floor
	Gasp = { id = "", fallback = BUILTIN .. "ouch.ogg", volume = 0.5, speed = 1.3, range = 50 }, -- quick airless fabric gasp "uh!" while burning
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
	RaftSqueak = { id = "", volume = 0.5, range = 50 }, -- damp squeak-crunch of foam when you land on a raft
	PlatformSlosh = { id = "", fallback = BUILTIN .. "impact_water.mp3", volume = 0.4, speed = 0.7, range = 60 }, -- wet slosh-muffle as a raft edge dips under
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
	JumpWhoosh = { id = "", volume = 0.25, range = 40 }, -- low sweeping whoosh of air at the top of a jump
	BubbleHum = { id = "", volume = 0.15, looped = true, range = 14 }, -- faint crystalline mmm-ring-mmm from each score bubble
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
