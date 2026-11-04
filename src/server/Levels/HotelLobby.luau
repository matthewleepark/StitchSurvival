-- The hub: a grand hotel lobby where players arrive, walk around, and roll for scuba gear between
-- levels. Same contract as Pod.build(): returns { model, machine, spawn }, plus `rooms`: the
-- numbered guest-room doors that act as game queues (see Rooms.luau).
--
-- Layout (the lobby is Config.Pod; x is left-right, z runs from the back wall (-) to the entrance (+)):
--   back wall   elevators | reception desk with keys and mailboxes | fireplace | gear machine
--   side walls  guest-room balconies upstairs, a library nook (left) and a piano nook (right) below
--   front wall  entrance doors, tall windows and a clock
--   middle      red runner rug, marble centerpiece, two lounge sets, six marble pillars

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)
local Pod = require(script.Parent.Pod)
local Props = require(script.Parent.HotelProps)

local Colors = Config.Colors
local L = Config.LobbyColors
local M = Craft.Material
local DECOR = Craft.DECOR
local MARBLE = Enum.Material.Marble

local HotelLobby = {}

local function box(parent: Instance, x: number, y: number, z: number, w: number, h: number, d: number, color: Color3, material: Enum.Material?, props)
	return Craft.block(parent, CFrame.new(x, y, z), Vector3.new(w, h, d), color, material, props)
end

local INVISIBLE = { Transparency = 1, CanQuery = false }

-- Placement helpers ---------------------------------------------------------------

local function makeContext(model: Model, decor: Folder)
	local def = Config.Pod
	local O = def.origin
	local ctx = { model = model, decor = decor, O = O, W = def.width, D = def.depth, H = def.height, MZ = def.mezzanineHeight, rooms = {} }

	function ctx.at(x: number, y: number, z: number): Vector3
		return O + Vector3.new(x, y, z)
	end

	-- A CFrame on one of the four walls, facing into the room. `along` runs to the right as you face
	-- the wall (so the left wall's along is -z), `out` pulls it off the wall surface.
	function ctx.wall(name: string, along: number, y: number, out: number?): CFrame
		local o = out or 0
		local halfW, halfD = ctx.W / 2, ctx.D / 2
		if name == "back" then
			return CFrame.new(O + Vector3.new(along, y, -halfD + o))
		elseif name == "front" then
			return CFrame.new(O + Vector3.new(-along, y, halfD - o)) * CFrame.Angles(0, math.pi, 0)
		elseif name == "left" then
			return CFrame.new(O + Vector3.new(-halfW + o, y, -along)) * CFrame.Angles(0, math.rad(90), 0)
		end
		return CFrame.new(O + Vector3.new(halfW - o, y, along)) * CFrame.Angles(0, math.rad(-90), 0)
	end

	-- Build something flat on a wall without doing any rotating: `build` makes it around the origin
	-- facing +Z (Craft's usual direction) and it is turned onto the wall afterwards.
	function ctx.wallItem(name: string, along: number, y: number, out: number?, build: (Model) -> ())
		local item = Instance.new("Model")
		build(item)
		item:PivotTo(ctx.wall(name, along, y, out) * item:GetPivot())
		item.Parent = decor
	end

	return ctx
end

-- Shell, walls and ceiling ------------------------------------------------------------

local function buildShell(ctx)
	local model, W, D, H = ctx.model, ctx.W, ctx.D, ctx.H
	local floor = ctx.at(0, -2, 0)
	box(model, floor.X, floor.Y, floor.Z, W + 8, 4, D + 8, L.Marble, MARBLE)
	for _, side in { -1, 1 } do
		local sideWall = ctx.at(side * (W / 2 + 2), H / 2, 0)
		box(model, sideWall.X, sideWall.Y, sideWall.Z, 4, H + 8, D + 8, L.Plaster, M.Foam)
		local endWall = ctx.at(0, H / 2, side * (D / 2 + 1))
		box(model, endWall.X, endWall.Y, endWall.Z, W + 8, H + 8, 2, L.Plaster, M.Foam)
	end
	local ceiling = ctx.at(0, H + 1, 0)
	box(model, ceiling.X, ceiling.Y, ceiling.Z, W + 8, 2, D + 8, L.Ceiling, M.Foam)

	-- Checkerboard marble: the base slab is the light squares, these are the dark ones. Big squares
	-- keep it to about 18 parts and read better in the dark.
	local tile = 16
	for ix = 0, math.floor(W / tile) - 1 do
		for iz = 0, math.floor(D / tile) - 1 do
			if (ix + iz) % 2 == 0 then
				local p = ctx.at(-W / 2 + tile / 2 + ix * tile, 0.05, -D / 2 + tile / 2 + iz * tile)
				box(model, p.X, p.Y, p.Z, tile, 0.1, tile, L.MarbleDark, MARBLE)
			end
		end
	end
end

local function wallpaper(ctx, wall: string, length: number)
	local H = ctx.H
	ctx.wallItem(wall, 0, 0, 0, function(item)
		box(item, 0, H / 2, 0.03, length, H, 0.06, L.Wallpaper, M.Felt, DECOR)
	end)
end

-- Mahogany paneling 8 studs tall, standing on `y` (the ground, or the balcony floor).
local function wainscot(ctx, wall: string, along: number, y: number, length: number)
	ctx.wallItem(wall, along, y, 0, function(item)
		box(item, 0, 4, 0.3, length, 8, 0.6, L.Panel, M.Wood, DECOR)
		for x = -length / 2 + 3, length / 2 - 2, 6 do
			box(item, x, 4.2, 0.66, 4.4, 5.4, 0.14, L.PanelLight, M.Wood, DECOR)
		end
		box(item, 0, 8.3, 0.5, length, 0.6, 1, L.PanelDark, M.Wood, DECOR)
		box(item, 0, 0.7, 0.55, length, 1.4, 1.1, L.PanelDark, M.Wood, DECOR)
	end)
end

local function crown(ctx, wall: string, length: number)
	ctx.wallItem(wall, 0, ctx.H, 0, function(item)
		box(item, 0, -0.9, 0.7, length, 1.8, 1.4, L.Cream, M.Foam, DECOR)
		box(item, 0, -2.3, 0.4, length, 0.5, 0.8, L.Brass, M.Metal, DECOR)
	end)
end

local function window(ctx, wall: string, along: number, y: number, width: number, height: number)
	ctx.wallItem(wall, along, y, 0.1, function(item)
		Craft.window(item, Vector3.zero, width, height, Colors.Sky, L.Velvet)
	end)
end

local function buildWalls(ctx)
	local W, D = ctx.W, ctx.D
	local lengths = { back = W, front = W, left = D, right = D }
	for wall, length in lengths do
		wallpaper(ctx, wall, length)
		if wall == "front" then
			-- Two runs of paneling with a gap for the entrance doors, so nothing pokes through them.
			local doorGap = 15
			local side = (length - doorGap) / 2
			for _, sign in { -1, 1 } do
				wainscot(ctx, wall, sign * (doorGap / 2 + side / 2), 0, side)
			end
		else
			wainscot(ctx, wall, 0, 0, length)
		end
		crown(ctx, wall, length)
	end

	-- Few windows, so the hall stays dark: two in front, two at the back, two on each side.
	for _, along in { -28, 28 } do
		window(ctx, "front", along, 21, 8, 14)
	end
	for _, along in { -48, 48 } do
		window(ctx, "back", along, 25, 8, 14)
	end
	for _, wall in { "left", "right" } do
		for _, along in { -16, 16 } do
			window(ctx, wall, along, 33, 8, 6) -- above the room-door signs
		end
	end
end

-- Coffered ceiling beams, rosettes and the chandeliers hanging from them.
local function buildCeiling(ctx)
	local decor, W, D, H = ctx.decor, ctx.W, ctx.D, ctx.H
	for _, z in { -30, -10, 10, 30 } do
		local p = ctx.at(0, H - 0.8, z)
		box(decor, p.X, p.Y, p.Z, W, 1.6, 1.6, L.PanelDark, M.Wood, DECOR)
	end
	for _, x in { -42, -14, 14, 42 } do
		local p = ctx.at(x, H - 0.8, 0)
		box(decor, p.X, p.Y, p.Z, 1.6, 1.6, D, L.PanelDark, M.Wood, DECOR)
	end
	for _, z in { 20, -20 } do -- midway between beams, with long dark stretches between them
		Craft.cylinder(decor, ctx.at(0, H - 1.7, z), 0.3, 9, "Y", L.Cream, M.Foam, DECOR)
		Props.chandelier(decor, ctx.at(0, H - 1.8, z))
	end
end

-- Mezzanine: balconies with guest-room doors, reached by two marble staircases ---------

local STAIR_RUN = 2
local BALCONY_WIDTH = 12
local STAIR_WIDTH = 10

-- Where the staircases sit front-to-back: near the entrance, facing into the lobby.
local function stairZ(ctx): number
	return ctx.D / 2 - 10
end

-- A grand staircase on each side. It starts out on the lobby floor (facing the middle of the room,
-- so you walk straight onto it from the red runner) and climbs sideways up to the balcony.
local function buildStairs(ctx, side: number)
	local model, decor, at, MZ = ctx.model, ctx.decor, ctx.at, ctx.MZ
	local steps = MZ - 1 -- the balcony floor is the 16th "step"
	local z = stairZ(ctx)
	local xTop = side * (ctx.W / 2 - BALCONY_WIDTH) -- where the balcony starts
	local xBottom = xTop - side * STAIR_RUN * steps

	-- Solid marble steps with a velvet runner. An invisible ramp along the nosings is what you
	-- actually walk on, so the climb is smooth.
	for i = 1, steps do
		local x = xBottom + side * (STAIR_RUN * (i - 1) + STAIR_RUN / 2)
		local p = at(x, i / 2, z)
		box(model, p.X, p.Y, p.Z, STAIR_RUN, i, STAIR_WIDTH, L.Marble, MARBLE)
		local tread = at(x, i + 0.05, z)
		box(decor, tread.X, tread.Y, tread.Z, STAIR_RUN - 0.2, 0.1, 7, L.Velvet, M.Felt, DECOR)
		if i % 2 == 0 then -- balusters on both sides, every other step
			for _, edge in { -1, 1 } do
				Craft.cylinder(decor, at(x, i + 1.85, z + edge * (STAIR_WIDTH / 2 - 0.3)), 3.6, 0.3, "Y", L.Brass, M.Metal, DECOR)
			end
		end
	end

	local bottom = at(xBottom - side * 1, 0, z)
	local top = at(xTop, steps + 0.5, z)
	local ramp = Craft.block(model, CFrame.lookAt((bottom + top) / 2, top) * CFrame.new(0, -0.5, 0), Vector3.new(STAIR_WIDTH, 1, (top - bottom).Magnitude), Color3.new(), nil, INVISIBLE)
	ramp.Name = "StairRamp"

	-- Sloped handrails on both sides, with a big newel post and brass ball at the bottom.
	for _, edge in { -1, 1 } do
		local railZ = z + edge * (STAIR_WIDTH / 2 - 0.3)
		local lowRail = at(xBottom, 4.2, railZ)
		local highRail = at(xTop, MZ + 3.2, railZ)
		for _, drop in { 0, 2.4 } do
			local a, b = lowRail - Vector3.new(0, drop, 0), highRail - Vector3.new(0, drop, 0)
			Craft.block(decor, CFrame.lookAt((a + b) / 2, b), Vector3.new(0.6, if drop == 0 then 0.5 else 0.25, (b - a).Magnitude), L.Panel, M.Wood, DECOR)
		end
		local newel = at(xBottom - side * 0.6, 3, railZ)
		box(decor, newel.X, newel.Y, newel.Z, 1.2, 6, 1.2, L.Panel, M.Wood, DECOR)
		Craft.ball(decor, newel + Vector3.new(0, 3.4, 0), 1.4, L.Brass, M.Metal, DECOR)
	end
end

-- A game room's door sign (its level and queue count, kept up to date by Rooms.luau) plus the
-- invisible zone in front of the door that carries the "join" prompt.
local function buildRoomEntry(ctx, wall: string, along: number, number: number, levelName: string)
	local title = levelName
	for _, def in Config.Levels do
		if def.name == levelName then
			title = def.title
		end
	end

	local label: BasePart
	ctx.wallItem(wall, along, ctx.MZ + 10.9, 0.3, function(item)
		box(item, 0, 0, 0.1, 7, 2, 0.4, L.PanelDark, M.Wood, DECOR)
		box(item, 0, 0, 0.32, 6.6, 1.6, 0.06, L.Brass, M.Metal, DECOR)
		label = Craft.label(item, Vector3.new(0, 0, 0.4), 6.2, 1.4, title, L.PanelDark, Enum.Font.GothamBold)
	end)

	local zone = Instance.new("Part")
	zone.Name = `Room{number}Entry`
	zone.Size = Vector3.new(5.5, 8.4, 3)
	zone.CFrame = ctx.wall(wall, along, ctx.MZ + 4.2, 1.8)
	zone.Anchored = true
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	zone.Parent = ctx.model

	table.insert(ctx.rooms, { number = number, level = levelName, title = title, zone = zone, label = label })
end

local function buildMezzanine(ctx)
	local model, decor, at, MZ, D = ctx.model, ctx.decor, ctx.at, ctx.MZ, ctx.D
	local zFront = D / 2 -- the balconies run all the way to the front wall, where the stairs land
	local zBack = -D / 2
	local gapFront, gapBack = stairZ(ctx) + STAIR_WIDTH / 2, stairZ(ctx) - STAIR_WIDTH / 2
	local length = zFront - zBack
	local zMid = (zFront + zBack) / 2

	for _, side in { -1, 1 } do
		local x = side * (ctx.W / 2 - BALCONY_WIDTH / 2)
		local edge = side * (ctx.W / 2 - BALCONY_WIDTH)
		buildStairs(ctx, side)

		-- Floor, runner and the carved fascia you see from the lobby.
		local floor = at(x, MZ - 0.75, zMid)
		box(model, floor.X, floor.Y, floor.Z, BALCONY_WIDTH, 1.5, length, L.Panel, M.Wood)
		Props.rug(decor, at(x + side * 0.5, MZ, zMid), 8, length - 2, L.Velvet, L.Brass)
		local band = at(edge - side * 0.1, MZ - 1.2, zMid)
		box(decor, band.X, band.Y, band.Z, 0.3, 2.4, length, L.Cream, M.Foam, DECOR)
		local trim = at(edge - side * 0.2, MZ - 2.5, zMid)
		box(decor, trim.X, trim.Y, trim.Z, 0.2, 0.3, length, L.Brass, M.Metal, DECOR)
		for z = zFront - 4, zBack + 4, -12 do
			local corbel = at(edge - side * 0.3, MZ - 3.1, z)
			box(decor, corbel.X, corbel.Y, corbel.Z, 0.8, 3.2, 1.2, L.Cream, M.Foam, DECOR)
			Craft.ball(decor, corbel + Vector3.new(-side * 0.1, -1.9, 0), 0.9, L.Brass, M.Metal, DECOR)
		end
		for _, z in { gapBack - 4, zMid, zBack + 6 } do
			Props.pillar(decor, at(edge - side * 1.9, 0, z), MZ - 1.5)
		end

		-- Balustrade: brass balusters with a mahogany rail, plus an invisible rail so nobody tumbles.
		-- It's built in two runs, leaving an opening where the staircase arrives.
		for _, run in { { zBack, gapBack }, { gapFront, zFront } } do
			local from, to = run[1], run[2]
			local runLength, runMid = to - from, (from + to) / 2
			local rail = at(edge + side * 0.3, MZ + 3.1, runMid)
			box(decor, rail.X, rail.Y, rail.Z, 0.7, 0.4, runLength, L.Panel, M.Wood)
			local base = at(edge + side * 0.3, MZ + 0.2, runMid)
			box(decor, base.X, base.Y, base.Z, 0.7, 0.4, runLength, L.Panel, M.Wood, DECOR)
			for z = to - 0.8, from + 0.5, -2.4 do
				Craft.cylinder(decor, at(edge + side * 0.3, MZ + 1.65, z), 2.9, 0.3, "Y", L.Brass, M.Metal, DECOR)
			end
			local guard = at(edge + side * 0.3, MZ + 3, runMid)
			Craft.block(model, CFrame.new(guard), Vector3.new(0.5, 6, runLength), Color3.new(), nil, INVISIBLE)
			for _, z in { from + 0.5, to - 0.5 } do
				local newel = at(edge + side * 0.3, MZ + 2, z)
				box(decor, newel.X, newel.Y, newel.Z, 1, 4, 1, L.Panel, M.Wood)
			end
		end

		-- Paneling, five numbered guest-room doors and brass lamps between them.
		local wall = if side == -1 then "left" else "right"
		-- the left wall's "along" runs toward the back of the room (-z); the right wall's toward the front (+z)
		local function alongOf(z: number): number
			return if side == -1 then -z else z
		end
		wainscot(ctx, wall, alongOf(zMid), MZ, length)
		for i = 0, 4 do
			local z = -2 - i * 8
			local number = if side == -1 then 201 + i * 2 else 202 + i * 2
			Props.roomDoor(decor, ctx.wall(wall, alongOf(z), MZ, 0), number)
			local levelName = Config.Rooms.levels[number]
			if levelName then
				buildRoomEntry(ctx, wall, alongOf(z), number, levelName)
			end
			if i == 1 or i == 3 then -- a lamp for every other gap between doors, so the corridor is mostly shadow
				Props.sconce(decor, ctx.wall(wall, alongOf(z - 4), MZ + 7, 0.3))
			end
		end
		for _, z in { zFront - 8, zBack + 8 } do
			Props.pendant(decor, at(x, MZ - 1.5, z))
		end
	end
end

-- Reception, fireplace, elevators, gear machine -----------------------------------------

local function buildBackWall(ctx)
	local decor, at = ctx.decor, ctx.at

	Props.reception(decor, CFrame.new(at(0, 0, -27)))
	Props.keyBoard(decor, ctx.wall("back", -7, 11, 0))
	Props.mailboxes(decor, ctx.wall("back", 10, 11, 0))

	ctx.wallItem("back", 0, 30, 0.6, function(item)
		Craft.sign(item, Vector3.zero, 34, 7, "THE STITCH GRAND", {
			bulbs = true,
			faceColor = L.Velvet,
			textColor = L.Cream,
			boardColor = L.PanelDark,
			stitchColor = L.Brass,
		})
	end)
	ctx.wallItem("back", 0, 22, 0.6, function(item)
		Craft.sign(item, Vector3.zero, 12, 3.4, "RECEPTION", { faceColor = L.Cream, boardColor = L.PanelDark, stitchColor = L.Brass })
	end)

	for _, along in { -34, -24 } do
		Props.elevator(decor, ctx.wall("back", along, 0, 0))
	end
	ctx.wallItem("back", -29, 16.4, 0.6, function(item)
		Craft.sign(item, Vector3.zero, 12, 3, "ELEVATORS", { faceColor = L.Cream, boardColor = L.PanelDark, stitchColor = L.Brass })
	end)

	Props.fireplace(decor, ctx.wall("back", 24, 0, 0))
	Props.sofa(decor, CFrame.new(at(19, 0, -31.5)) * CFrame.Angles(0, math.rad(150), 0), L.Teal, 5.2)
	Props.sofa(decor, CFrame.new(at(29, 0, -31.5)) * CFrame.Angles(0, math.rad(-150), 0), L.Teal, 5.2)

	for _, side in { -1, 1 } do
		Props.grandfatherClock(decor, ctx.wall("back", side * 50, 0, 1.4))
	end
end

-- Lounges, library, piano nook, and the odds and ends ---------------------------------------

-- Two sofas facing across a coffee table, on a rug. That's all: the empty floor around it matters.
local function loungeSet(ctx, cx: number, cz: number, sofaColor: Color3, rugColor: Color3)
	local decor, at = ctx.decor, ctx.at
	Props.rug(decor, at(cx, 0, cz), 20, 18, rugColor, L.Brass)
	Props.sofa(decor, CFrame.new(at(cx, 0, cz - 6)), sofaColor)
	Props.sofa(decor, CFrame.new(at(cx, 0, cz + 6)) * CFrame.Angles(0, math.pi, 0), sofaColor)
	Props.coffeeTable(decor, CFrame.new(at(cx, 0, cz)))
end

local function buildLounges(ctx)
	local decor, at = ctx.decor, ctx.at
	loungeSet(ctx, -30, 20, L.Navy, L.Cream)
	loungeSet(ctx, 30, 20, L.Teal, L.Cream)

	-- The red runner from the doors to the desk, with the big bouquet halfway along.
	Props.rug(decor, at(0, 0, 4), 12, 70, L.Velvet, L.Brass)
	Props.centerpiece(decor, CFrame.new(at(0, 0, 4)))
	-- Four pillars to hide behind instead of six to bump into.
	for _, z in { 22, -8 } do
		for _, side in { -1, 1 } do
			Props.pillar(decor, at(side * 14, 0, z), ctx.H - 2)
		end
	end

	for _, spot in { { -41, 10 }, { 41, 10 }, { -16, -30 }, { 51, -30 } } do
		Props.plant(decor, CFrame.new(at(spot[1], 0, spot[2])), 1)
	end
	Props.luggageCart(decor, CFrame.new(at(24, 0, 14)) * CFrame.Angles(0, math.rad(-20), 0))
end

local function buildNooks(ctx)
	local decor, at = ctx.decor, ctx.at

	-- Library under the left balcony.
	for i, along in { 10, 24 } do
		Props.bookshelf(decor, ctx.wall("left", along, 0, 1.1), 8, 12, i)
	end
	Props.rug(decor, at(-49, 0, -17), 9, 22, L.Navy, L.Brass)
	Props.sofa(decor, CFrame.new(at(-47.5, 0, -17)) * CFrame.Angles(0, math.rad(90), 0), L.Velvet, 5.2)
	Props.sideTable(decor, CFrame.new(at(-49, 0, -23)))

	-- Piano under the right balcony, with paintings above it.
	Props.piano(decor, CFrame.new(at(46, 0, -14)) * CFrame.Angles(0, math.rad(-90), 0))
	for _, along in { -26, -14, -2 } do
		ctx.wallItem("right", along, 10.5, 0.1, function(item)
			Craft.picture(item, Vector3.zero, 5, 3.6, Colors.Gold)
		end)
	end
end

-- Entrance ------------------------------------------------------------------------------

local function buildEntrance(ctx)
	local decor, at = ctx.decor, ctx.at
	Props.entranceDoor(decor, ctx.wall("front", 0, 0, 0))
	Props.rug(decor, at(0, 0, ctx.D / 2 - 5), 10, 5, L.Velvet, L.Brass)

	ctx.wallItem("front", 0, 25.5, 0.6, function(item)
		Craft.sign(item, Vector3.zero, 22, 5, "WELCOME", { bulbs = true, faceColor = L.Cream, boardColor = L.PanelDark, stitchColor = L.Velvet })
	end)

	ctx.wallItem("front", 0, 33, 0.5, function(item)
		Craft.disc(item, Vector3.zero, 6, L.Brass, M.Metal, DECOR)
		Craft.disc(item, Vector3.new(0, 0, 0.1), 5, L.Cream, M.Foam, DECOR)
		box(item, 0, 0.6, 0.25, 0.2, 1.4, 0.08, L.PanelDark, M.Plastic, DECOR)
		box(item, 0.7, 0, 0.25, 1.5, 0.2, 0.08, L.PanelDark, M.Plastic, DECOR)
	end)
end

function HotelLobby.build()
	local model = Instance.new("Model")
	model.Name = "HotelLobby"
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model

	local ctx = makeContext(model, decor)
	buildShell(ctx)
	buildWalls(ctx)
	buildCeiling(ctx)
	buildMezzanine(ctx)
	buildBackWall(ctx)
	buildLounges(ctx)
	buildNooks(ctx)
	buildEntrance(ctx)

	local machine = Pod.buildGearMachine(model, ctx.at(37, 0, -35))

	-- Soft hidden fill lights in a grid over the floor and along the balcony corridors, so every
	-- area can be seen. They don't flicker; the visible lamps still do.
	if Config.Mood.fillLight > 0 then
		local spots = {}
		for _, x in { -44, -22, 0, 22, 44 } do
			for _, z in { -30, -10, 10, 30 } do
				table.insert(spots, ctx.at(x, 11, z))
			end
		end
		for _, side in { -1, 1 } do
			for _, z in { -32, -16, 0, 16, 32 } do
				table.insert(spots, ctx.at(side * 50, ctx.MZ + 9, z))
			end
		end
		for _, spot in spots do
			local holder = box(decor, spot.X, spot.Y, spot.Z, 0.2, 0.2, 0.2, Color3.new(), nil, INVISIBLE)
			holder.CanCollide = false
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 214, 170)
			light.Range = 26
			light.Brightness = Config.Mood.fillLight
			light.Shadows = false
			light.Parent = holder
		end
	end

	-- Tiny details don't need to cast shadows; skipping them is a big saving with hundreds of parts.
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Size.Magnitude < 3 then
			part.CastShadow = false
		end
	end

	-- Invisible spawn pad on the runner just inside the doors; characters face down the hall.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(10, 0.2, 10)
	spawn.CFrame = CFrame.new(ctx.at(0, 0.1, 28))
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = model

	model.Parent = workspace

	return {
		model = model,
		machine = machine,
		spawn = spawn,
		rooms = ctx.rooms, -- the game-room doors, for Rooms.start()
	}
end

return HotelLobby
