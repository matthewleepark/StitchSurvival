-- The shape of the Killer Hotel maze, with no parts and no game code in it (so it can be tested on its own).
--
-- The hotel is `floors` floors of an N x N grid of cells. Cell id = i + j * N (i along X, j along Z).
-- For every floor this works out which walls exist, from a seeded Random, so each round is different:
--   * a random spanning tree (randomized Kruskal) opens exactly enough doorways to reach every cell, then
--     `loopChance` of the leftover walls are opened as well, so there are loops and shortcuts,
--   * ramps join the floors. A ramp climbs along 4 cells in a straight line (c1..c4), from the cell before
--     them (c0) to the cell after them on the floor above (c5):
--         lower floor:  c0 -> [c1 c2 c3 c4]   a dead-end corridor with the ramp in it, entered from c0
--         upper floor:  [c1 c2 c3 c4] -> c5   a hole (no floor), walled off except where the ramp arrives at c5
--     so every ramp is walled in and nobody can fall into its hole from the side.
-- `validate` checks that every cell on every floor can be reached from the ground floor.

local MazeLayout = {}

local DIRECTIONS = { Vector2.new(1, 0), Vector2.new(-1, 0), Vector2.new(0, 1), Vector2.new(0, -1) }
local KEY = 4096 -- edge keys are low * KEY + high, so N * N must be under this

export type Ramp = {
	floor: number, -- the lower floor; it climbs to floor + 1
	cells: { [number]: number }, -- [0] = c0 ... [5] = c5
	direction: Vector2, -- (dx, dz) in cells, the way it climbs
	i0: number,
	j0: number,
}

function MazeLayout.edgeKey(a: number, b: number): number
	if a > b then
		a, b = b, a
	end
	return a * KEY + b
end

local edgeKey = MazeLayout.edgeKey

-- Is there a wall between neighbouring cells a and b on this floor?
function MazeLayout.hasWall(layout, floor: number, a: number, b: number): boolean
	local data = layout.floorData[floor]
	if data.void[a] and data.void[b] then
		return false -- inside a ramp's hole: nothing to wall off
	end
	local key = edgeKey(a, b)
	return not (data.open[key] or data.voidOpen[key])
end

local function shuffle(list, rng: Random)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

local function placeRamps(N: number, floors: number, rampsPerFloor: number, rng: Random)
	local voidSet, chainSet, required = {}, {}, {}
	for f = 0, floors - 1 do
		voidSet[f], chainSet[f], required[f] = {}, {}, {}
	end
	local ramps: { Ramp } = {}

	for f = 0, floors - 2 do
		local placed: { Ramp } = {}
		for _ = 1, rampsPerFloor do
			local found = false
			for _ = 1, 400 do
				local direction = DIRECTIONS[rng:NextInteger(1, 4)]
				local i0, j0 = rng:NextInteger(0, N - 1), rng:NextInteger(0, N - 1)
				local cells = {}
				local inside = true
				for k = 0, 5 do
					local i, j = i0 + direction.X * k, j0 + direction.Y * k
					if i < 0 or i >= N or j < 0 or j >= N then
						inside = false
						break
					end
					cells[k] = i + j * N
				end
				if inside then
					local good = true
					for k = 1, 4 do
						local c = cells[k]
						if voidSet[f][c] or chainSet[f][c] or required[f][c] or voidSet[f + 1][c] or required[f + 1][c] then
							good = false
						end
					end
					if voidSet[f][cells[0]] or chainSet[f][cells[0]] then
						good = false
					end
					if voidSet[f + 1][cells[5]] or chainSet[f + 1][cells[5]] then
						good = false
					end
					for _, other in placed do
						if math.abs(i0 - other.i0) + math.abs(j0 - other.j0) < 6 then
							good = false -- keep the ramps of one floor well apart
						end
					end
					if good then
						local ramp: Ramp = { floor = f, cells = cells, direction = direction, i0 = i0, j0 = j0 }
						table.insert(ramps, ramp)
						table.insert(placed, ramp)
						for k = 1, 4 do
							chainSet[f][cells[k]] = true
							voidSet[f + 1][cells[k]] = true
						end
						required[f][cells[0]] = true
						required[f + 1][cells[5]] = true
						found = true
						break
					end
				end
			end
			if not found then
				return nil
			end
		end
	end
	return ramps, voidSet, chainSet
end

-- Opens the doorways on one floor. Returns { void, open, voidOpen, chain } or nil if it came out in pieces.
local function carveFloor(N: number, f: number, ramps: { Ramp }, void, chain, loopChance: number, rng: Random)
	local open, voidOpen = {}, {}
	local parent = {}
	local function find(x: number): number
		while parent[x] ~= x do
			parent[x] = parent[parent[x]]
			x = parent[x]
		end
		return x
	end
	local function union(a: number, b: number): boolean
		local ra, rb = find(a), find(b)
		if ra == rb then
			return false
		end
		parent[ra] = rb
		return true
	end
	for c = 0, N * N - 1 do
		parent[c] = c
	end

	local forcedOpen = {}
	for _, ramp in ramps do
		local c = ramp.cells
		if ramp.floor == f then
			for k = 0, 3 do
				forcedOpen[edgeKey(c[k], c[k + 1])] = true
			end
		elseif ramp.floor == f - 1 then
			voidOpen[edgeKey(c[4], c[5])] = true -- where the ramp arrives from below
		end
	end

	local candidates = {}
	for c = 0, N * N - 1 do
		if not void[c] then
			local i, j = c % N, c // N
			for _, n in { if i + 1 < N then c + 1 else -1, if j + 1 < N then c + N else -1 } do
				if n >= 0 and not void[n] then
					local key = edgeKey(c, n)
					if forcedOpen[key] then
						open[key] = true
						union(c, n)
					elseif not (chain[c] or chain[n]) then
						table.insert(candidates, { c, n, key })
					end
				end
			end
		end
	end

	shuffle(candidates, rng)
	local leftover = {}
	for _, edge in candidates do
		if union(edge[1], edge[2]) then
			open[edge[3]] = true
		else
			table.insert(leftover, edge)
		end
	end
	for _, edge in leftover do
		if rng:NextNumber() < loopChance then
			open[edge[3]] = true -- a loop or shortcut
		end
	end

	local root
	for c = 0, N * N - 1 do
		if not void[c] then
			root = root or find(c)
			if find(c) ~= root then
				return nil
			end
		end
	end
	return { void = void, open = open, voidOpen = voidOpen, chain = chain }
end

-- Builds a maze. Tries again with the same Random until it comes out connected.
function MazeLayout.generate(N: number, floors: number, rampsPerFloor: number, loopChance: number, rng: Random)
	assert(N * N < KEY, "MazeLayout: grid too big")
	for _ = 1, 80 do
		local ramps, voidSet, chainSet = placeRamps(N, floors, rampsPerFloor, rng)
		if ramps then
			local floorData = {}
			local ok = true
			for f = 0, floors - 1 do
				local data = carveFloor(N, f, ramps, voidSet[f], chainSet[f], loopChance, rng)
				if not data then
					ok = false
					break
				end
				floorData[f] = data
			end
			if ok then
				return { N = N, floors = floors, ramps = ramps, floorData = floorData }
			end
		end
	end
	error("MazeLayout: could not build a connected maze")
end

-- Walks every doorway and ramp from the middle of the ground floor. Returns whether every cell on every
-- floor was reached, how many were, and how many there are.
function MazeLayout.validate(layout): (boolean, number, number)
	local N = layout.N
	local cellsPerFloor = N * N
	local links: { [number]: { number } } = {}
	local function link(a: number, b: number)
		links[a] = links[a] or {}
		links[b] = links[b] or {}
		table.insert(links[a], b)
		table.insert(links[b], a)
	end
	local total = 0
	for f = 0, layout.floors - 1 do
		local data = layout.floorData[f]
		for c = 0, cellsPerFloor - 1 do
			if not data.void[c] then
				total += 1
			end
		end
		for key in data.open do
			link(f * cellsPerFloor + key // KEY, f * cellsPerFloor + key % KEY)
		end
	end
	for _, ramp in layout.ramps do
		link(ramp.floor * cellsPerFloor + ramp.cells[4], (ramp.floor + 1) * cellsPerFloor + ramp.cells[5])
	end

	local start = (N // 2) + (N // 2) * N
	local seen = { [start] = true }
	local queue, head, count = { start }, 1, 1
	while head <= #queue do
		local node = queue[head]
		head += 1
		for _, neighbor in links[node] or {} do
			if not seen[neighbor] then
				seen[neighbor] = true
				count += 1
				table.insert(queue, neighbor)
			end
		end
	end
	return count == total, count, total
end

return MazeLayout
