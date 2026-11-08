-- The Killer Hotel building: a tall, wide, maze-like hotel with three floors. The wall layout comes from
-- MazeLayout (random every round, or fixed with Config.KillerHotel.map.seed). Numbers are in
-- Config.KillerHotel.map and the level's entry in Config.Levels.
--
--   * Every floor is a grid of 16-stud cells. Corridors are 14 studs wide between 2-stud walls, and the
--     walls are 26 studs tall: far taller than the old 16-stud hotel.
--   * Floors, inner walls and ramps are all breakable (they live in stage.breakables), so bombs punch
--     holes through walls and ceilings. The outer wall and the roof are solid.
--   * Ramps join the floors; each is walled in so nobody can fall into its hole from the side.
--   * Every floor has its own colour, so you can tell where you are in the maze.
--   * Acid under the whole hotel pops anyone who falls out of the bottom.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)
local Remotes = require(script.Parent.Parent.Remotes)
local Util = require(script.Parent.Parent.Util)
local KillerRooms = require(script.Parent.KillerRooms)
local MazeLayout = require(script.Parent.MazeLayout)

local Colors = Config.Colors
local M = Craft.Material

local SLAB = 2 -- floor slab thickness
local WALL = 2 -- wall thickness
local RAMP_WIDTH = 12

-- Wall colours (a darker lower band, a lighter upper band) and floor tiles for each floor.
local STYLES = {
	{ low = Color3.fromRGB(122, 84, 60), high = Color3.fromRGB(178, 132, 94), tileA = Colors.Paper, tileB = Color3.fromRGB(70, 60, 70) },
	{ low = Color3.fromRGB(48, 88, 90), high = Color3.fromRGB(98, 152, 148), tileA = Color3.fromRGB(226, 238, 232), tileB = Color3.fromRGB(190, 212, 206) },
	{ low = Color3.fromRGB(84, 54, 94), high = Color3.fromRGB(144, 106, 154), tileA = Color3.fromRGB(238, 228, 240), tileB = Color3.fromRGB(208, 194, 214) },
}

local KillerMaze = {}

-- A wooden plank ramp from `from` to `to` (both on the walking surface).
local function buildRamp(parent: Instance, from: Vector3, to: Vector3)
	local middle = (from + to) / 2
	local length = (to - from).Magnitude
	local plank = Craft.block(parent, CFrame.lookAt(middle, to) * CFrame.new(0, -0.5, 0), Vector3.new(RAMP_WIDTH, 1, length + 1), Colors.Wood, M.Wood)
	plank.Name = "Ramp"
	plank:SetAttribute("Breakable", true)
	local slats = math.floor(length / 3)
	for i = 1, slats do
		local point = from:Lerp(to, i / (slats + 1))
		Craft.block(parent, CFrame.lookAt(point, to) * CFrame.new(0, 0.02, 0), Vector3.new(RAMP_WIDTH, 0.05, 0.3), Colors.WoodDark, M.Wood, Craft.DECOR)
	end
	return plank
end

function KillerMaze.build(def)
	local map = Config.KillerHotel.map
	local N, cell = map.cells, map.cell
	local O = def.origin
	local W = N * cell
	local floors = def.floors
	local H = def.floorHeight
	local roofY = floors * H
	assert(def.width == W and def.depth == W, `Killer Hotel width/depth must be map.cells * map.cell = {W}`)

	local seed = map.seed or math.random(1, 2 ^ 30)
	local layout = MazeLayout.generate(N, floors, map.rampsPerFloor, map.loopChance, Random.new(seed))
	local rng = Random.new(seed + 1)
	local killerCell = (N // 2) + (N // 2) * N
	MazeLayout.placeRooms(layout, rng, Config.KillerHotel.rooms.perFloor, Config.KillerHotel.rooms.passThroughChance, { [0] = { [killerCell] = true } })

	local parkour = Config.KillerHotel.parkour
	local barricades = MazeLayout.placeBarricades(layout, rng, parkour.barricadesPerFloor, { [0] = { [killerCell] = true } })
	local barricadeCells = {}
	for f = 0, floors - 1 do
		barricadeCells[f] = {}
	end
	for _, barricade in barricades do
		barricadeCells[barricade.floor][barricade.cell] = true
	end

	-- The stage table is filled in at the end; doors and wardrobes keep hold of it for the whole round.
	local stage = { frozen = false }
	KillerRooms.setup(stage)

	local model = Instance.new("Model")
	model.Name = "KillerHotel"
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	local breakables = Instance.new("Folder") -- everything bombs can blow apart
	breakables.Name = "Breakables"
	breakables.Parent = model

	local function cellX(i: number): number
		return -W / 2 + cell / 2 + i * cell
	end
	local function at(x: number, y: number, z: number): Vector3
		return O + Vector3.new(x, y, z)
	end

	-- Floors: one tile per cell (a ramp's hole has none on the floor above).
	local ceilingTiles: { [number]: { [number]: BasePart } } = {} -- [floor][cell] = the tile that is that floor's ceiling
	for f = 0, floors - 1 do
		local style = STYLES[f % #STYLES + 1]
		local data = layout.floorData[f]
		ceilingTiles[f] = {}
		for j = 0, N - 1 do
			for i = 0, N - 1 do
				local c = i + j * N
				if not data.void[c] then
					local center = CFrame.new(at(cellX(i), f * H - SLAB / 2, cellX(j)))
					local tile
					if f == 0 then
						tile = Craft.block(breakables, center, Vector3.new(cell, SLAB, cell), if (i + j) % 2 == 0 then style.tileA else style.tileB, M.Wood)
						tile.Name = "FloorTile"
						tile:SetAttribute("Breakable", true)
					else
						tile = Craft.foam(breakables, center, Vector3.new(cell, SLAB, cell), (i + j) % 2 == 0)
						tile.Color = if (i + j) % 2 == 0 then style.tileA else style.tileB
					end
					if f >= 1 then
						ceilingTiles[f - 1][c] = tile
					end
				end
			end
		end
	end
	Craft.block(model, CFrame.new(at(0, roofY - SLAB / 2, 0)), Vector3.new(W + WALL * 2, SLAB, W + WALL * 2), Colors.Cardboard, M.Cardboard)

	-- Walls: two bands per wall segment (a darker lower half, a lighter upper half).
	local wallHeight = H - SLAB
	local bandHeight = wallHeight / 2
	-- A doorway where a room meets a corridor: the maze leaves that edge open, and a door goes in it.
	local function doorway(f: number, c: number, n: number, x: number, z: number, alongZ: boolean)
		local door = layout.floorData[f].door[MazeLayout.edgeKey(c, n)]
		if not door then
			return
		end
		local direction = if alongZ then Vector3.xAxis else Vector3.zAxis -- from c toward n
		local style = STYLES[f % #STYLES + 1]
		KillerRooms.buildDoorway(stage, breakables, {
			center = at(x, f * H, z),
			outDir = if door.room == c then direction else -direction,
			alongZ = alongZ,
			cell = cell,
			wall = WALL,
			wallHeight = wallHeight,
			frameColor = style.high,
			doorColor = Colors.Wood,
			rng = rng,
		})
	end
	local function wallSegment(parent: Instance, f: number, x: number, z: number, alongZ: boolean, breakable: boolean)
		local style = STYLES[f % #STYLES + 1]
		local length = cell + WALL
		for band = 0, 1 do
			local size = if alongZ then Vector3.new(WALL, bandHeight, length) else Vector3.new(length, bandHeight, WALL)
			local wall = Craft.block(parent, CFrame.new(at(x, f * H + bandHeight / 2 + band * bandHeight, z)), size, if band == 0 then style.low else style.high, M.Cardboard)
			wall.Name = "WallTile"
			if breakable then
				wall:SetAttribute("Breakable", true)
			end
		end
	end
	for f = 0, floors - 1 do
		for j = 0, N - 1 do
			for i = 0, N - 1 do
				local c = i + j * N
				if i + 1 < N then
					if MazeLayout.hasWall(layout, f, c, c + 1) then
						wallSegment(breakables, f, -W / 2 + (i + 1) * cell, cellX(j), true, true)
					else
						doorway(f, c, c + 1, -W / 2 + (i + 1) * cell, cellX(j), true)
					end
				end
				if j + 1 < N then
					if MazeLayout.hasWall(layout, f, c, c + N) then
						wallSegment(breakables, f, cellX(i), -W / 2 + (j + 1) * cell, false, true)
					else
						doorway(f, c, c + N, cellX(i), -W / 2 + (j + 1) * cell, false)
					end
				end
			end
		end
		-- The outer wall: solid, so nobody can leave through a hole in it.
		for k = 0, N - 1 do
			wallSegment(model, f, -W / 2, cellX(k), true, false)
			wallSegment(model, f, W / 2, cellX(k), true, false)
			wallSegment(model, f, cellX(k), -W / 2, false, false)
			wallSegment(model, f, cellX(k), W / 2, false, false)
		end
	end

	-- Furniture: each room gets a wardrobe to hide in (sometimes), a bed and a crate, against the walls that
	-- do not have a door, so the way in stays clear.
	local inner = cell / 2 - WALL / 2 -- how far the inside face of a wall is from the middle of a cell
	for _, room in layout.rooms do
		local f, c = room.floor, room.cell
		local i, j = c % N, c // N
		local data = layout.floorData[f]
		local sides = {}
		for _, side in { { 1, 0, if i + 1 < N then c + 1 else -1 }, { -1, 0, if i > 0 then c - 1 else -1 }, { 0, 1, if j + 1 < N then c + N else -1 }, { 0, -1, if j > 0 then c - N else -1 } } do
			if side[3] < 0 or not data.door[MazeLayout.edgeKey(c, side[3])] then
				table.insert(sides, side)
			end
		end
		for k = #sides, 2, -1 do
			local pick = rng:NextInteger(1, k)
			sides[k], sides[pick] = sides[pick], sides[k]
		end
		local middle = at(cellX(i), f * H, cellX(j))
		local style = STYLES[f % #STYLES + 1]
		local nextSide = 1
		if rng:NextNumber() < Config.KillerHotel.rooms.wardrobeChance and sides[nextSide] then
			local d = sides[nextSide]
			nextSide += 1
			local direction = Vector3.new(d[1], 0, d[2])
			KillerRooms.buildWardrobe(stage, breakables, middle + direction * (inner - 1.6), -direction, d[1] ~= 0)
		end
		if sides[nextSide] then
			local d = sides[nextSide]
			nextSide += 1
			local direction = Vector3.new(d[1], 0, d[2])
			local lateral = Vector3.new(d[2], 0, d[1]) * (if rng:NextNumber() < 0.5 then 3.5 else -3.5)
			KillerRooms.buildBed(breakables, middle + direction * (inner - 4.6) + lateral, d[1] ~= 0, style.low:Lerp(Colors.Felt, 0.5))
		end
		if sides[nextSide] then
			local d = sides[nextSide]
			local direction = Vector3.new(d[1], 0, d[2])
			local lateral = Vector3.new(d[2], 0, d[1]) * (if rng:NextNumber() < 0.5 then 4.5 else -4.5)
			if rng:NextNumber() < parkour.shelfChance then
				KillerRooms.buildShelf(breakables, middle + direction * (inner - 1.6) + lateral, d[1] ~= 0, parkour.shelfHeight)
			else
				KillerRooms.buildCrate(breakables, middle + direction * (inner - 2.2) + lateral)
			end
		end
	end

	-- Tall barricades across some straight corridors: too high to jump, so you have to clamber over (or find
	-- another way round).
	for _, barricade in barricades do
		local c = barricade.cell
		local position = at(cellX(c % N), barricade.floor * H, cellX(c // N))
		KillerRooms.buildBarricade(breakables, position, barricade.axis == "x", cell - WALL, parkour.barricadeHeight)
	end

	-- Ramps.
	for _, ramp in layout.ramps do
		local i0, j0 = ramp.i0, ramp.j0
		local direction = ramp.direction
		local startX = cellX(i0) + direction.X * cell / 2
		local startZ = cellX(j0) + direction.Y * cell / 2
		local from = at(startX, ramp.floor * H, startZ)
		local to = at(startX + direction.X * cell * 4, (ramp.floor + 1) * H, startZ + direction.Y * cell * 4)
		buildRamp(breakables, from, to)
	end

	-- Ceiling lamps, one in every other cell each way. A lamp hangs from the tile above it, and goes
	-- when that tile does (see cleanDecor below).
	local lamps: { { tile: BasePart?, parts: { Instance } } } = {}
	local spacing = map.lampSpacing
	for f = 0, floors - 1 do
		local data = layout.floorData[f]
		local ceilingBottom = (f + 1) * H - SLAB
		for j = 0, N - 1, spacing do
			for i = 0, N - 1, spacing do
				local c = i + j * N
				local hole = f + 1 < floors and layout.floorData[f + 1].void[c]
				if not data.void[c] and not hole then
					local cord = Craft.block(decor, CFrame.new(at(cellX(i), ceilingBottom - 1, cellX(j))), Vector3.new(0.2, 2, 0.2), Colors.WoodDark, M.Metal, Craft.DECOR)
					local bulb = Craft.ball(decor, at(cellX(i), ceilingBottom - 2.6, cellX(j)), 1.6, Colors.Gold, M.Neon, Craft.DECOR)
					local light = Instance.new("PointLight")
					light.Color = Color3.fromRGB(255, 214, 150)
					light.Range = 22
					light.Brightness = 0.9
					light.Parent = bulb
					Craft.tag(light, "FlickerLight") -- Mood.luau makes these stutter now and then
					table.insert(lamps, { tile = if f + 1 < floors then ceilingTiles[f][c] else nil, parts = { cord, bulb } })
				end
			end
		end
	end

	-- Acid all around and underneath: fall through a hole in the ground floor and you are popped.
	local acid = Craft.block(model, CFrame.new(at(0, -16, 0)), Vector3.new(W + 160, 2, W + 160), Color3.fromRGB(110, 255, 70), M.Neon, { CanCollide = false, CanQuery = false, Name = "Acid" })
	acid.Transparency = 0.15
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(110, 255, 70)
	glow.Range = 40
	glow.Brightness = 1.5
	glow.Parent = acid
	acid.Touched:Connect(function(hit)
		local character, humanoid = Util.characterFromPart(hit)
		if character and humanoid and humanoid.Health > 0 and Util.kill(humanoid) then
			Util.soundAt("AcidFizz", hit.Position)
			Remotes.fireAll("Poof", { position = hit.Position, color = Color3.fromRGB(110, 255, 70) })
		end
	end)

	-- A low, cozy building hum.
	local humSpot = Craft.block(decor, CFrame.new(at(0, roofY / 2, 0)), Vector3.one, Color3.new(), nil, Craft.DECOR)
	humSpot.Transparency = 1
	Util.loopSound("HotelHum", humSpot)

	Craft.boundaries(model, O, W + 40, roofY + 10, W + 40)
	model.Parent = workspace

	-- Where everyone starts. The killer starts in the middle of the ground floor; the innocents are
	-- spread over every floor, never close to the killer or to each other.
	local function cellPosition(f: number, c: number): Vector3
		return at(cellX(c % N), f * H + 3, cellX(c // N))
	end
	local killerSpawn = CFrame.new(cellPosition(0, killerCell))
	local candidates = {}
	for f = 0, floors - 1 do
		for c = 0, N * N - 1 do
			if not layout.floorData[f].void[c] and not barricadeCells[f][c] then
				local fromKiller = math.max(math.abs(c % N - killerCell % N), math.abs(c // N - killerCell // N))
				if f ~= 0 or fromKiller >= 5 then
					table.insert(candidates, { floor = f, cell = c })
				end
			end
		end
	end
	for i = #candidates, 2, -1 do
		local j = rng:NextInteger(1, i)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end
	local picked = {}
	for _, spot in candidates do
		local clear = true
		for _, other in picked do
			if other.floor == spot.floor and math.max(math.abs(other.cell % N - spot.cell % N), math.abs(other.cell // N - spot.cell // N)) < 3 then
				clear = false
				break
			end
		end
		if clear then
			table.insert(picked, spot)
			if #picked >= 24 then
				break
			end
		end
	end
	local spawns = {}
	for _, spot in picked do
		table.insert(spawns, CFrame.new(cellPosition(spot.floor, spot.cell)))
	end

	print(`[KillerHotel] maze seed {seed}: {#layout.rooms} rooms, {#barricades} barricades, {#stage.doors} doors, {#breakables:GetChildren()} breakable parts, {#model:GetDescendants()} instances`)

	stage.model = model
	stage.breakables = breakables
	stage.origin = O
	stage.width = W
	stage.depth = W
	stage.floors = floors
	stage.floorHeight = H
	stage.roofY = roofY
	stage.spawns = spawns
	stage.killerSpawn = killerSpawn
	stage.killY = O.Y - 25
	stage.seed = seed
	stage.layout = layout
	-- Lamps whose ceiling tile has been blown away go with it, so nothing hangs in mid-air.
	stage.cleanDecor = function()
		for index = #lamps, 1, -1 do
			local lamp = lamps[index]
			if lamp.tile and (not lamp.tile.Parent or not lamp.tile.Anchored) then
				for _, part in lamp.parts do
					part:Destroy()
				end
				table.remove(lamps, index)
			end
		end
	end
	return stage
end

return KillerMaze
