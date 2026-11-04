-- Everything you might want to tweak lives here: layout, timing, scoring, colors, gear, sounds.

local Config = {}

-- Rounds ---------------------------------------------------------------------

-- Players who get the admin panel (testing tools). Roblox usernames, any capitalization.
Config.Admins = { "3HBQ" }

Config.MinPlayers = 1 -- players a room needs queued before its start countdown begins
Config.IntermissionTime = 60 -- countdown once a room is ready; lower this (e.g. 10) while testing
Config.LoadingTime = 3 -- the "map tipping out of the toybox" moment before teleporting
Config.CountdownTime = 3
Config.RoundTime = 120
Config.ResultsTime = 7

-- World physics: Roblox's normal gravity. (It was 35, a floaty toybox, which made jumps huge.)
Config.Gravity = 196.2

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

-- The hub is the Grand Hotel lobby (Levels/HotelLobby.luau). It keeps the Pod name so the client's
-- stage detection and room reverb keep working. The old toybox Pod (Levels/Pod.luau) still builds
-- from these numbers if you want it back, just bigger.
Config.Pod = {
	origin = Vector3.new(0, 20, 0),
	width = 112,
	depth = 80,
	height = 38,
	mezzanineHeight = 16, -- the balcony floor; the staircases are built for exactly this (15 steps)
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

-- Game rooms: the numbered guest-room doors on the hotel balconies. Walk up and hold E to join a
-- room's queue (again to leave). Rounds run one at a time, so rooms take turns: the room that has
-- been waiting longest (with at least MinPlayers) plays its level next.
-- Also set Max Players to 32 in Studio: Home > Game Settings > Basic Info.
Config.Rooms = {
	capacity = 32,
	-- room number -> level name from Config.Levels. Odd numbers are the left balcony, even the right.
	levels = {
		[201] = "BombHotel",
		[203] = "BombHotel",
		[205] = "BombHotel",
		[207] = "BombHotel",
		[209] = "BombHotel",
		[202] = "SharkSurvival",
		[204] = "SharkSurvival",
		[206] = "SharkSurvival",
		[208] = "SharkSurvival",
		[210] = "SharkSurvival",
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

-- Horror look: dark and cold with warm pools of light around the lamps. All of this is applied by
-- Mood.luau when the server starts (Studio's Lighting panel will look bright until you press Play).
Config.Mood = {
	-- Neutral horror lighting: dim and moody, but every area can be seen. Lower these for darker, raise for brighter.
	ambient = Color3.fromRGB(38, 36, 46), -- indoor fill light; raise it if it's too dark to play
	outdoorAmbient = Color3.fromRGB(34, 38, 52),
	brightness = 0.4, -- moonlight strength
	clockTime = 0, -- midnight
	exposure = -0.15,
	fogColor = Color3.fromRGB(16, 16, 24),
	fogStart = 40,
	fogEnd = 260,
	hazeDensity = 0.26, -- 0 to 1
	lampBrightness = 1.2, -- every lobby lamp's brightness is multiplied by this
	lampRange = 1.1, -- ... and how far its light reaches
	fillLight = 0.22, -- soft hidden lights spread over the lobby so no area is pitch black (0 = off)
	saturation = -0.3, -- drained colors
	contrast = 0.12,
	tint = Color3.fromRGB(205, 220, 235),
	lampChance = 0.15, -- chance per 0.2 s that one lamp flickers
	surgeEvery = { 45, 90 }, -- seconds between brief power surges where every lamp stutters
}

-- Camera: how close and how far you can zoom (studs from your doll), and how far the camera stays
-- in front of walls so it never peeks through them.
Config.Camera = {
	minZoom = 2,
	maxZoom = 18,
	wallGap = 1.2,
}

-- Spooky lobby extras (cobwebs, dust, portraits whose eyes light up now and then).
Config.Spooky = {
	eyesEvery = { 6, 14 }, -- seconds between a portrait's eyes glowing
	dust = 12, -- floating dust specks per second (0 = none)
}

-- Flashlight: F on keyboard, L1 on a gamepad, a "Light" button on mobile. Only you see your own beam.
Config.Flashlight = {
	range = 70, -- studs
	angle = 50, -- degrees of cone, wider = more floodlight
	brightness = 4,
	color = Color3.fromRGB(255, 238, 205),
	shadows = true, -- beams stop at walls; turn off if it hurts frame rate on phones
}

-- Hotel lobby palette: faded burgundy wallpaper, dark mahogany, dusty marble and tarnished brass.
Config.LobbyColors = {
	Marble = Color3.fromRGB(150, 146, 138),
	MarbleShade = Color3.fromRGB(128, 124, 116),
	MarbleDark = Color3.fromRGB(38, 36, 42),
	Plaster = Color3.fromRGB(110, 102, 92),
	Ceiling = Color3.fromRGB(96, 90, 84),
	Wallpaper = Color3.fromRGB(88, 48, 56),
	WallpaperStripe = Color3.fromRGB(76, 40, 48),
	Panel = Color3.fromRGB(58, 38, 30),
	PanelLight = Color3.fromRGB(72, 48, 38),
	PanelDark = Color3.fromRGB(40, 26, 22),
	Cream = Color3.fromRGB(176, 164, 140),
	Brass = Color3.fromRGB(150, 118, 62),
	Velvet = Color3.fromRGB(92, 28, 44),
	Navy = Color3.fromRGB(30, 40, 66),
	Teal = Color3.fromRGB(36, 80, 80),
	Leaf = Color3.fromRGB(70, 92, 50),
	LeafDark = Color3.fromRGB(52, 66, 38),
	Terracotta = Color3.fromRGB(120, 68, 50),
	Soil = Color3.fromRGB(50, 36, 28),
	Trunk = Color3.fromRGB(84, 64, 44),
	Fire = Color3.fromRGB(255, 120, 40),
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
	Scale = 1, -- normal Roblox avatar height
	Ragdoll = true, -- when popped, all the joints go loose instead of falling apart
	-- Roblox's defaults (16 studs/s, 7.2 stud jump) are for a 5.4 stud avatar, so scale them down
	-- with the doll. Slower than default on purpose: it keeps the tension up.
	WalkSpeed = 16, -- Roblox default
	JumpHeight = 7.2, -- studs, Roblox default
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
	LobbyCreak = { id = "", volume = 0.4, range = 90 }, -- old wooden floorboards / door hinge creaking in the dark
	LobbyWhisper = { id = "", volume = 0.25, range = 60 }, -- faint, unclear whispering
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
