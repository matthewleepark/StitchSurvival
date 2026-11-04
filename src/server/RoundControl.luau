-- Shared switches between the round loop and the admin panel.
-- The admin panel flips these; the round loop in init.server.luau checks them.

local RoundControl = {
	-- Set to true to end the lobby countdown right away.
	skipIntermission = false,
	-- Set to a level name (e.g. "BombHotel") to make the next round use that level.
	forceLevel = nil :: string?,
	-- Set to true to end the current round right away (survivors still win).
	endRound = false,

	-- What's running right now (nil between rounds).
	levelName = nil :: string?,
	stage = nil :: any,
}

return RoundControl
