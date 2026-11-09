-- Everything you might want to tweak lives here: layout, timing, scoring, colors, gear, sounds.

local Config = {}

-- Rounds ---------------------------------------------------------------------

-- Players who get the admin panel (testing tools). Roblox usernames, any capitalization.
Config.Admins = { "3HBQ", "ACKworld", "suweetiepie" }

-- Players per server. Set Max Players to the same number in Studio: Home > Game Settings > Basic Info.
Config.MaxPlayers = 12
Config.MinPlayers = 1 -- players needed in the server before the map vote starts

-- Map vote (server/Vote.luau): between rounds, pads for a few maps pop up out of the floor in front of the
-- reception desk. Stand on one to vote for it (your vote stays until you stand on another). When the timer
-- runs out the map with the most votes is played by everyone in the server (a tie, or no votes, is picked at
-- random). Maps that need more players than are here (Killer Hotel, Hide & Seek need 2) aren't offered.
Config.Vote = {
	choices = 3, -- how many maps pop up each time (picked at random from Config.Levels)
	seconds = 25, -- how long the vote lasts; lower it (e.g. 8) while testing
	breakSeconds = 4, -- a short breather in the lobby after a round before the pads pop up
}
Config.LoadingTime = 3 -- the "map tipping out of the toybox" moment before teleporting
Config.CountdownTime = 3
Config.RoundTime = 120
Config.ResultsTime = 7

-- World physics: Roblox's normal gravity. (It was 35, a floaty toybox, which made jumps huge.)
Config.Gravity = 196.2

-- Bomb Hotel: bombs keep falling out of the sky onto the hotel roof, each at a random spot. A bomb
-- smashes a hole through the roof where it hits, drops into the hotel and lands on whatever floor is
-- below. Its timer ticks twice a second, doubles speed for the last 5 seconds, then it explodes:
-- everything within 25 studs (floor blocks, pillars, ramps) is ripped loose and thrown outward.
Config.PlantedBombInterval = 5 -- seconds between bombs at the start; it shortens to half this by the end
Config.PlantedBombFuse = 12
Config.PlantedBombBlastRadius = 25

-- Bomb Hotel CHAOS MODE: sometimes a round turns chaotic. Points are doubled, and one huge,
-- battle-scarred flying shark chews its way in through an outer wall (a red crack warns where), then
-- flies around the hotel on its own wandering path for the rest of the round, chewing through anything
-- in its way and chomping anyone it runs into.
Config.Chaos = {
	chance = 0.25, -- chance a Bomb Hotel round is chaotic
	scoreMultiplier = 2,
	firstShark = 8, -- seconds into the round before the shark arrives
	warning = 1.5, -- seconds the red crack glows before the shark appears
	sharkScale = 2, -- how big the shark is (1 = 15 studs long, 2 = 30)
	sharkSpeed = 11, -- studs per second; slower than you walk, so you can get away
	sharkChew = 0.45, -- seconds per block it bites through
}

-- Shark Survival: the shark switches from patrolling to hunting when a player is this close.
Config.SharkHuntRadius = 45

-- The jumpscare on your own screen when a shark eats you (client/Jumpscare.luau). The sound is
-- Config.Sounds.JumpscareSting.
Config.Jumpscare = {
	seconds = 1.6, -- how long it plays (you are already dead underneath it; respawn takes 3 s)
}

-- Scoring: each score bubble is worth 10 points. Raise MaxMultiplier (e.g. to 8) to turn on
-- LBP-style combos, where grabbing bubbles quickly multiplies their value.

Config.SurvivalPointsPerSecond = 5
Config.BubblePoints = 10
Config.MaxMultiplier = 1
Config.MultiplierWindow = 4 -- grab another bubble within this many seconds to keep the combo
Config.SurviveBonus = 500
Config.PointsPerSticker = 50

Config.StartingStickers = 40

-- Promo codes players can type into the CODES box. Each works once per player, ever (it's saved with
-- their progress). Rewards: `stickers` (a number) and/or `gear` (an item name from Config.Gear).
-- Codes aren't case-sensitive. Add or remove them here.
Config.Codes = {
	WELCOME = { stickers = 100, message = "Welcome to the hotel! +100 Stickers" },
	STITCH = { stickers = 100, message = "+100 Stickers!" },
	CHOMP = { gear = "Bouncy Stuffing", message = "You got Bouncy Stuffing!" },
}
Config.RollCost = 20

-- Saving (server/Data.luau): Stickers, Wins, passives, used codes, daily challenges, your look and your
-- leaderboard stats are kept between visits in a DataStore. In Studio this only works with
-- Home > Game Settings > Security > "Enable Studio Access to API Services" turned on; without it the
-- game still runs, it just forgets everything when you stop.
Config.Save = {
	storeName = "StitchSurvival_v1", -- change the name to start everyone fresh
	autosaveSeconds = 120,
}

-- Daily challenges (server/Daily.luau, the DAILY button). Every day (resetting at midnight UTC) each
-- player gets `count` challenges picked from this list just for them. Finish one, then press CLAIM in
-- the DAILY panel for its Stickers. `stat` is what counts toward it:
--   roundsPlayed, roundsSurvived, points, bubbles, rolls, hides (climbing into a wardrobe), stuns (hitting the
--   seeker with debris), hunterWins (winning as the killer or seeker), and survive_<Level> for one level.
Config.Daily = {
	count = 3,
	challenges = {
		{ id = "play3", text = "Play 3 rounds", stat = "roundsPlayed", goal = 3, reward = 30 },
		{ id = "survive2", text = "Survive 2 rounds", stat = "roundsSurvived", goal = 2, reward = 50 },
		{ id = "points1500", text = "Score 1,500 points", stat = "points", goal = 1500, reward = 40 },
		{ id = "bubbles20", text = "Grab 20 score bubbles", stat = "bubbles", goal = 20, reward = 40 },
		{ id = "roll3", text = "Roll the passive machine 3 times", stat = "rolls", goal = 3, reward = 25 },
		{ id = "bomb", text = "Survive a Bomb Hotel round", stat = "survive_BombHotel", goal = 1, reward = 40 },
		{ id = "shark", text = "Survive a Shark Survival round", stat = "survive_SharkSurvival", goal = 1, reward = 40 },
		{ id = "hideseek", text = "Survive a Hide & Seek round", stat = "survive_HideAndSeek", goal = 1, reward = 50 },
		{ id = "killer", text = "Survive a Killer Hotel round", stat = "survive_KillerHotel", goal = 1, reward = 50 },
		{ id = "wardrobe", text = "Hide in a wardrobe 3 times", stat = "hides", goal = 3, reward = 30 },
		{ id = "stun", text = "Stun the seeker with debris", stat = "stuns", goal = 1, reward = 60 },
		{ id = "hunter", text = "Win a round as the killer or seeker", stat = "hunterWins", goal = 1, reward = 75 },
	},
}

-- Leaderboards: two big boards on the lobby's back wall (above the elevators and beside the fireplace).
-- Each board takes turns showing its categories, top 10 from every server. `stat` is a saved stat.
Config.Leaderboards = {
	refreshSeconds = 60, -- how often the boards fetch the latest top 10
	flipSeconds = 10, -- how long each category stays up before the board flips to the next
	boards = {
		{ { stat = "wins", title = "\u{1F3C6} MOST WINS" }, { stat = "hunterWins", title = "\u{1F52A} TOP HUNTERS" } },
		{ { stat = "stickersEarned", title = "\u{2B50} MOST STICKERS EARNED" }, { stat = "roundsPlayed", title = "\u{1F3AE} MOST ROUNDS PLAYED" } },
	},
}

-- Your look: the knitted doll (default) or your own Roblox avatar. Players switch with the LOOK button;
-- it's saved. Changing it in the lobby respawns you right away; during a round it waits until you respawn.
Config.Look = {
	default = "doll", -- "doll" or "avatar"
}

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
		icon = "\u{1F4A3}", -- bomb (on its vote pad)
		color = Color3.fromRGB(255, 150, 60),
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
		icon = "\u{1F988}", -- shark
		color = Color3.fromRGB(90, 180, 255),
		weight = 50,
		origin = Vector3.new(0, 20, 900),
		width = 300,
		depth = 300,
		height = 48,
		waterDepth = 20,
	},
	-- Killer Hotel: one killer hunts everyone else with bombs (see Config.KillerHotel below).
	-- weight 0: a "Random" admin start never picks it (it can still win the map vote).
	{
		name = "KillerHotel",
		title = "Killer Hotel",
		icon = "\u{1F52A}", -- knife
		color = Color3.fromRGB(200, 40, 50),
		weight = 0,
		minPlayers = 2, -- a killer needs someone to hunt (Config.KillerHotel.soloTest overrides it)
		roundTime = 600, -- 10 minutes
		origin = Vector3.new(0, 20, 1500),
		width = 224, -- = Config.KillerHotel.map.cells * map.cell
		depth = 224,
		floors = 3,
		floorHeight = 28, -- studs from one floor to the next (the old hotel was 16); walls are 2 less than this
		height = 3 * 28 + 20,
	},
	-- Hide & Seek: the same kind of maze hotel, no bombs. One SEEKER (red aura) hunts the HIDERS
	-- (see Config.HideAndSeek below).
	{
		name = "HideAndSeek",
		title = "Hide & Seek",
		icon = "\u{1F648}", -- see-no-evil monkey
		color = Color3.fromRGB(170, 110, 240),
		weight = 0,
		minPlayers = 2, -- a seeker needs someone to find (Config.HideAndSeek.soloTest overrides it)
		roundTime = 240, -- 4 minutes, counted from GO (the hiding time is part of it)
		origin = Vector3.new(0, 20, 2100),
		width = 224, -- = Config.KillerHotel.map.cells * map.cell (it reuses the Killer Hotel maze builder)
		depth = 224,
		floors = 3,
		floorHeight = 28,
		height = 3 * 28 + 20,
		-- More rooms than Killer Hotel, and a wardrobe in every one: plenty of places to hide.
		rooms = { perFloor = 14, passThroughChance = 0.4, wardrobeChance = 1 },
	},
}

-- Hide & Seek: one SEEKER hunts the HIDERS through the maze hotel. The seeker counts with their eyes
-- covered while everyone hides, then comes out glowing with a red aura. Touching a hider who isn't hidden
-- catches them (they're out). Hiders hide in wardrobes and rooms, and each hider can pick up ONE piece of
-- debris off the floor (hold E at it) and throw it at the seeker (click or tap where to throw, or press Q):
-- a hit stuns the seeker in place. Hiders win if anyone is still hidden when the timer runs out.
Config.HideAndSeek = {
	soloTest = false, -- true: a lone player becomes the seeker (testing only)
	hideSeconds = 20, -- the seeker counts this long (frozen, screen covered) while everyone hides
	catchRange = 4.5, -- studs: how close the seeker has to get to catch someone
	debrisPerFloor = 10, -- throwable debris pieces lying around on each floor
	throwSpeed = 95, -- studs per second
	throwLift = 10, -- a little upward push so the throw arcs
	throwKey = Enum.KeyCode.Q, -- (gamepad: X; touch gets a THROW button) — clicking or tapping also throws
	stunSeconds = 4, -- how long a hit freezes the seeker
	stunImmunitySeconds = 4, -- after a stun wears off the seeker can't be stunned again for this long
	catchPoints = 150, -- points for the seeker per catch
	stunPoints = 200, -- points for the hider who lands a stun
	aura = Color3.fromRGB(255, 40, 40), -- the seeker's glow
}

-- Killer Hotel: one KILLER hunts the INNOCENTS with bombs. The killer wins by getting everyone before
-- the timer (Config.Levels roundTime) runs out; the innocents win if any of them is still alive.
-- Innocents never see a bomb's timer; they only hear its tick (Config.Sounds.BombTick range) up close.
Config.KillerHotel = {
	killerPityWeight = 0.5, -- each round you were not the killer adds this much to your odds next time (1 = base)
	soloTest = false, -- true: a lone player becomes the killer (for testing only; normal rounds need minPlayers)
	fuse = 4, -- seconds from a thrown bomb to the blast
	startBombs = 3, -- bombs the killer starts with
	carryLimit = 3, -- the most bombs the killer can hold
	restockSeconds = 25, -- a new bomb every this many seconds, up to carryLimit
	dropCooldown = 2, -- seconds between drops
	throwSpeed = 80, -- how hard the killer throws a bomb (studs per second)
	throwLift = 12, -- a little extra upward push so throws arc instead of skidding along the floor
	dropKey = Enum.KeyCode.Q, -- throws toward where the camera points (gamepad: X); clicking or tapping throws at that spot
	killerImmuneToOwnBombs = true, -- the killer takes no damage from blasts, fire or falling blocks (an invisible ForceField), so their own bombs can't end the round
	killerRescue = true, -- the killer's own blasts can drop the floor away; falling out puts them back on the top floor instead of ending the round
	roleBannerSeconds = 5, -- how long the "you are the killer / an innocent" banner stays up
	-- The maze (Levels/KillerMaze.luau, layout in Levels/MazeLayout.luau). Each floor is cells x cells.
	-- Change cells or cell and also set the level's width and depth in Config.Levels to cells * cell.
	map = {
		cells = 14, -- 14 x 14 cells a floor
		cell = 16, -- studs per cell: 14 of corridor between 2-stud walls
		rampsPerFloor = 2, -- ramps from each floor up to the next
		loopChance = 0.12, -- of the walls left after the maze is carved, how many are opened to make loops and shortcuts
		lampSpacing = 2, -- a ceiling lamp in every this-many-th cell, each way
		seed = nil, -- set a number to get the same maze every round (nil = a new one each round)
	},
	-- Rooms: cells with a door (dead ends mostly), furnished, some with a wardrobe to hide in.
	rooms = {
		perFloor = 10,
		passThroughChance = 0.4, -- chance a room gets a second door onto another corridor (a way out, and a loop)
		wardrobeChance = 0.6, -- chance a room has a wardrobe to hide in
	},
	-- Doors swing OUT of the room with a kick. Hold the open key to kick one open or shut; from inside,
	-- the lock key locks it. The killer breaks a locked door by holding the open key for breakSeconds
	-- (a loud pounding the whole time) or blows it up with a bomb. (E is taken: it grabs things.)
	doors = {
		width = 6, -- studs of doorway
		height = 11,
		openAngle = 100, -- degrees it swings out (it overshoots a little and bounces back)
		openHold = 0.15, -- seconds to hold the open key
		breakSeconds = 6, -- how long the killer must hold to break a locked door
		poundEvery = 0.8, -- seconds between pounds while the killer breaks a door
		closeClearance = 2.5, -- a door will not shut while someone stands in its doorway (this close to the wall line)
		openKey = Enum.KeyCode.F, -- (gamepad: Y)
		lockKey = Enum.KeyCode.G, -- (gamepad: left bumper)
	},
	-- Parkour: hold the run key to run (it uses stamina), and press jump next to something climbable to
	-- clamber up onto it. Climbable things are tagged "Climbable": crates, shelves in rooms, and tall
	-- barricades across some corridors (taller than a jump, so they take a clamber). The server decides all of
	-- it: speeds, stamina, and whether a clamber is allowed. The killer walks and runs a bit faster, but is
	-- slower to clamber, so a good runner can lose them at a barricade. Walk speed is Config.Doll.WalkSpeed
	-- (plus passives).
	parkour = {
		runKey = Enum.KeyCode.LeftShift, -- (gamepad: left stick click; touch gets a RUN button)
		runMultiplier = 1.4, -- running speed, times walking speed
		killerWalkMultiplier = 1.1, -- the killer's walk and run, times everyone else's
		runSeconds = 4.5, -- of running from a full stamina bar
		regenSeconds = 6, -- to fill an empty bar again
		regenDelay = 1, -- seconds after running or clambering before it starts to refill
		exhaustedUntil = 0.3, -- empty means exhausted: no running until the bar is back to this much
		minLedge = 2.5, -- studs above your feet: lower than this you just step up
		reach = 10, -- studs above your feet: the highest top you can clamber onto (a jump is about 7)
		maxDistance = 4.5, -- how close to the edge you must be, in studs
		clamberCost = 0.12, -- of the stamina bar
		clamberCooldown = 0.5,
		clamberSeconds = 0.3, -- plus this much per stud of height
		clamberSecondsPerStud = 0.05,
		killerClamberMultiplier = 1.7, -- the killer takes this many times longer to clamber
		barricadesPerFloor = 8, -- tall barricades across straight corridors
		barricadeHeight = 8.5,
		shelfChance = 0.5, -- chance a room's crate is a tall shelf instead
		shelfHeight = 8.5,
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

-- Flashlight: L (for Light) on keyboard, D-pad up on a gamepad, a "Light" button on mobile. Only you see
-- your own beam. (It used to be F / L1, which also kicked doors and locked them in Killer Hotel.)
Config.Flashlight = {
	key = Enum.KeyCode.L,
	gamepadKey = Enum.KeyCode.DPadUp,
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

-- Passives (the RNG) ------------------------------------------------------------------
-- Walk up to the passive machine in the lobby to open its panel: it lists every passive, its rarity,
-- its chance and what it does, and has the ROLL button (a spinning reel picks one). Everything you
-- roll goes in your collection; equip whichever one you like. Every passive helps in every game.
--
-- What a passive can do (all optional, mix and match):
--   speed        extra walk speed
--   jump         extra jump height (studs)
--   toughness    0.2 = you take 20% less damage from everything (bombs, fire, drowning)
--   regen        heals this much health every second
--   air          extra seconds of air underwater
--   magnet       pulls in score bubbles from this many studs away
--   scoreBonus   0.25 = +25% points
--   sense        see bombs and sharks through walls
--   secondChance survive one pop (or knockout) per round, at half health
-- A "secret" passive shows up as ??? in the panel until you own it.
-- (The code still calls these "gear" internally: Config.Gear, the "Gear" attribute.)

Config.DefaultOxygen = 10 -- seconds of air everyone has; the air passive adds to this
-- Air only runs out, and you only drown, while your head is fully under: its centre this many studs
-- below the surface (a head is about 2 studs tall, so 1 is "the top of the head is under"). Floating,
-- treading water or bobbing never counts.
Config.DrownDepth = 1
Config.Gear = {
	{ name = "Lucky Thread", rarity = "Common", weight = 34, icon = "\u{1F9F5}", passives = { scoreBonus = 0.15 } },
	{ name = "Quick Laces", rarity = "Common", weight = 26, icon = "\u{1F45F}", passives = { speed = 2 } },
	{ name = "Bouncy Stuffing", rarity = "Uncommon", weight = 14, icon = "\u{2601}\u{FE0F}", passives = { jump = 3, speed = 1 } },
	{ name = "Thick Felt", rarity = "Uncommon", weight = 11, icon = "\u{1F9F6}", passives = { toughness = 0.2, air = 5 } },
	{ name = "Button Magnet", rarity = "Rare", weight = 6, icon = "\u{1F9F2}", passives = { magnet = 10, scoreBonus = 0.1 } },
	{ name = "Mending Needle", rarity = "Rare", weight = 4, icon = "\u{1FAA1}", passives = { regen = 2, toughness = 0.15 } },
	{ name = "Spooky Sense", rarity = "Epic", weight = 2.4, icon = "\u{1F441}\u{FE0F}", passives = { sense = true, speed = 2 } },
	{ name = "Deep Breath", rarity = "Epic", weight = 1.6, icon = "\u{1FAC1}", passives = { air = 20, regen = 1, speed = 1 } },
	{ name = "Golden Zipper", rarity = "Legendary", weight = 0.9, icon = "\u{2B50}", passives = { secondChance = true, scoreBonus = 0.25 } },
	{
		name = "Shark Tooth Charm",
		rarity = "Secret",
		weight = 0.1,
		icon = "\u{1F9B7}",
		secret = true,
		passives = { speed = 3, jump = 3, toughness = 0.4, regen = 3, air = 40, magnet = 12, scoreBonus = 0.5, sense = true, secondChance = true },
	},
}

Config.RarityOrder = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Secret = 6 }

Config.RarityColors = {
	Common = Color3.fromRGB(180, 170, 150),
	Uncommon = Color3.fromRGB(110, 190, 100),
	Rare = Color3.fromRGB(80, 150, 230),
	Epic = Color3.fromRGB(170, 90, 220),
	Legendary = Color3.fromRGB(250, 190, 40),
	Secret = Color3.fromRGB(255, 70, 110),
}

function Config.getGear(name: string?)
	for _, gear in Config.Gear do
		if gear.name == name then
			return gear
		end
	end
	return nil
end

-- One passive of the gear a player has equipped (by gear name), or nil.
function Config.passive(gearName: string?, key: string): any
	local gear = Config.getGear(gearName)
	return gear and gear.passives[key]
end

-- The chance of rolling an item, as a percentage.
function Config.gearChance(gear): number
	local total = 0
	for _, entry in Config.Gear do
		total += entry.weight
	end
	return gear.weight / total * 100
end

-- Plain-English lines describing an item's passives, for the panel and the HUD.
function Config.describePassives(gear): { string }
	local p = gear.passives
	local lines = {}
	if p.speed then
		table.insert(lines, `+{p.speed} walk speed`)
	end
	if p.jump then
		table.insert(lines, `+{p.jump} jump height`)
	end
	if p.toughness then
		table.insert(lines, `Take {math.floor(p.toughness * 100)}% less damage`)
	end
	if p.regen then
		table.insert(lines, `Heals {p.regen} health per second`)
	end
	if p.air then
		table.insert(lines, `+{p.air}s of air underwater`)
	end
	if p.magnet then
		table.insert(lines, `Pulls in score bubbles from {p.magnet} studs`)
	end
	if p.scoreBonus then
		table.insert(lines, `+{math.floor(p.scoreBonus * 100)}% points`)
	end
	if p.sense then
		table.insert(lines, "See bombs and sharks through walls")
	end
	if p.secondChance then
		table.insert(lines, "Survive one pop per round")
	end
	return lines
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

-- Background music (menu, lobby and level tracks). Off for now; set enabled = true to bring it back.
Config.Music = {
	enabled = false,
}

-- Jump and landing sounds. Both are off: the jump boing and the pouf on every landing were
-- annoying (the jump sound sat on a reverb that made it worse). Footsteps, oofs and the pop sound
-- are separate and stay on.
Config.CharacterAudio = {
	jumping = false,
	softLandings = false,
}

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
	ReelTick = { id = "", fallback = BUILTIN .. "volume_slider.ogg", volume = 0.3, speed = 2.6 }, -- click as each item spins past
	ReelWin = { id = "", volume = 0.8 }, -- the reel lands on your item

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
	DoorKick = { id = "rbxassetid://111763202035471", volume = 1, speed = 0.8, range = 90 }, -- a door kicked open: a hard BANG
	DoorClose = { id = "rbxassetid://111763202035471", volume = 0.55, range = 60 }, -- a door shut
	DoorLock = { id = "", fallback = BUILTIN .. "volume_slider.ogg", volume = 0.5, speed = 3, range = 40 }, -- deadbolt click
	DoorPound = { id = "", fallback = BUILTIN .. "action_jump_land.mp3", volume = 1, speed = 0.45, range = 110 }, -- the killer pounding on a locked door
	WardrobeCreak = { id = "rbxassetid://125209584906878", volume = 0.5, range = 30 }, -- a wardrobe door creaking
	Clamber = { id = "", fallback = BUILTIN .. "action_jump_land.mp3", volume = 0.45, speed = 1.5, range = 50 }, -- scrabbling up onto a ledge
	DebrisWhistle = { id = "", volume = 0.5, range = 80 }, -- descending fshhhhh as a block falls through the air
	Rumble = { id = "", fallback = BUILTIN .. "action_jump_land.mp3", volume = 0.7, speed = 0.3, range = 60 }, -- low grrrr-whump through the floor
	Gasp = { id = "", fallback = BUILTIN .. "ouch.ogg", volume = 0.5, speed = 1.3, range = 50 }, -- quick airless fabric gasp "uh!" while burning
	Crush = { id = "", fallback = BUILTIN .. "action_jump_land.mp3", volume = 1, speed = 0.35, range = 80 }, -- wet heavy squish (crushed!)
	FireCrackle = { id = "", volume = 0.5, looped = true, range = 50 }, -- stiff orange cellophane being crinkled

	-- Shark Survival ------------------------------------------------------------------------
	WaterRustle = { id = "", volume = 0.25, looped = true, range = 250 }, -- thousands of tissue-paper pieces stirred by a fan
	SharkMotor = { id = "", volume = 0.6, looped = true, range = 90 }, -- clockwork whir-click-whir (pitched up when it hunts)
	Breach = { id = "", fallback = BUILTIN .. "impact_water.mp3", volume = 0.9, range = 150 }, -- violent RIP-CRUNCH as it breaks the surface
	AcidFizz = { id = "", fallback = BUILTIN .. "impact_water.mp3", volume = 0.8, speed = 1.4, range = 80 }, -- a sizzle as someone drops into the acid
	SharkRoar = { id = "", volume = 0.9, range = 150 }, -- a deep rumble as a shark bursts through a wall
	WallCrack = { id = "", fallback = BUILTIN .. "action_jump_land.mp3", volume = 0.8, speed = 0.4, range = 100 }, -- the wall cracking right before
	Chomp = { id = "", volume = 0.9, range = 120 }, -- blunt CLACK of two thick plywood slabs
	PlatformSnap = { id = "", volume = 0.8, range = 120 }, -- wooden popsicle stick SNAP
	PlatformSink = { id = "", volume = 0.6, range = 100 }, -- fizz-muffle / gurgle-glug as it sinks
	PlatformSwish = { id = "", volume = 0.4, range = 60 }, -- soft swish-shhh against the paper ocean
	RaftSqueak = { id = "", volume = 0.5, range = 50 }, -- damp squeak-crunch of foam when you land on a raft
	PlatformSlosh = { id = "", fallback = BUILTIN .. "impact_water.mp3", volume = 0.4, speed = 0.7, range = 60 }, -- wet slosh-muffle as a raft edge dips under
	Splash = { id = "", fallback = BUILTIN .. "impact_water.mp3", volume = 0.7, range = 120 },

	-- Played on the victim's own screen when a shark eats them (client/Jumpscare.luau).
	JumpscareSting = { id = "rbxassetid://1841353939", volume = 1 }, -- "Rising Fear Hit 3" (APM Music, free), 4 s: peaks at 0.1 s and fades

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
