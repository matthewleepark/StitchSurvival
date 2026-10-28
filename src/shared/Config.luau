-- Everything you might want to tweak lives here: layout, timing, scoring, colors, gear, sounds.

local Config = {}

-- Rounds ---------------------------------------------------------------------

Config.MinPlayers = 1
Config.IntermissionTime = 20
Config.CountdownTime = 3
Config.RoundTime = 120
Config.ResultsTime = 6

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
		height = 76,
	},
	{
		name = "SharkSurvival",
		title = "Shark Survival",
		weight = 50,
		origin = Vector3.new(0, 20, 800),
		width = 112,
		height = 48,
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
-- Paste Roblox audio IDs here, e.g. "rbxassetid://1234567890".
-- Find them in Studio: Toolbox > Audio. Empty ones are simply skipped.

Config.Sounds = {
	Music = "", -- acoustic guitar / marimba / whistling loop
	Tick = "",
	Bang = "",
	BlockBreak = "",
	BubblePop = "",
	Countdown = "",
	Go = "",
	Fanfare = "",
	SharkWhir = "",
	Chomp = "",
	Splash = "",
	GearRoll = "",
}

return Config
