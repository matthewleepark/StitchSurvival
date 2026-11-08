-- The shark's body, shared by the Shark Survival shark (ClockworkShark.luau) and the Bomb Hotel
-- chaos shark (FlyingShark.luau).
--
-- Look (from the reference art): a low-poly great white built out of real triangles, so it has the
-- flat-faceted surfaces of the low-poly reference. Deep slate-navy back over an off-white belly with a
-- jagged line between them, a heavy head with a cone snout, small dead black eyes with a cold cyan
-- glint, five gill slits glowing cyan, scars on the snout and flanks, a tall dorsal fin with a torn
-- notch, long swept-back pectoral fins and a big crescent tail with jagged trailing edges. The lower
-- jaw is hinged: it drops into a gaping mouth with two rows of teeth top and bottom, red gums, a black
-- throat and a faint cyan glow deep inside.
--
-- How it moves: everything is welded to one invisible Root part. Moving the Root moves the whole
-- shark, and two Motor6D joints open the jaw and swing the tail. So each frame only three things change,
-- no matter how many triangles there are. A finished shark is cached per size and cloned.
--
-- The shark faces +X in its own space (nose at about x = +7.6 at scale 1, tail tip at about x = -10.5).

local ServerStorage = game:GetService("ServerStorage")

local SharkModel = {}
SharkModel.__index = SharkModel

local TOP = Color3.fromRGB(36, 48, 64)
local BELLY = Color3.fromRGB(214, 214, 206)
local GUM = Color3.fromRGB(150, 46, 58)
local THROAT = Color3.fromRGB(10, 14, 20)
local TOOTH = Color3.fromRGB(238, 232, 214)
local TOOTH_BACK = Color3.fromRGB(214, 204, 182)
local SCAR = Color3.fromRGB(150, 156, 160)
local GLOW = Color3.fromRGB(80, 220, 255)
local SKIN = Enum.Material.SmoothPlastic

local SIDES = 8 -- corners around each cross-section
local THICKNESS = 0.08 -- skin thickness of each triangle

-- Cross-sections from nose to tail at scale 1: x position, half height, half width, center height.
local STATIONS = {
	{ x = 6.6, h = 0.9, w = 0.8, cy = 0.25 },
	{ x = 5.2, h = 1.7, w = 1.6, cy = 0.25 },
	{ x = 3.6, h = 2.4, w = 2.2, cy = 0.1 },
	{ x = 1.6, h = 2.8, w = 2.5, cy = 0 },
	{ x = -0.6, h = 2.9, w = 2.5, cy = 0 },
	{ x = -2.8, h = 2.4, w = 2.0, cy = 0 },
	{ x = -4.6, h = 1.6, w = 1.3, cy = 0.05 },
	{ x = -6.2, h = 0.9, w = 0.75, cy = 0.1 },
	{ x = -7.4, h = 0.55, w = 0.45, cy = 0.1 },
}
local NOSE = Vector3.new(7.6, 0.2, 0)
local TAIL_END = Vector3.new(-7.75, 0.1, 0)
local HEAD_STATIONS = 3 -- the first three cross-sections have a separate lower jaw
local JAW_HINGE = Vector3.new(1.6, -0.3, 0)
local TAIL_HINGE_STATION = 7 -- the tail swings from this cross-section back
local MOUTH = Vector3.new(5.8, -0.9, 0) -- where bites are measured from

-- Corner k of a cross-section. Corner 0 is the top, going around through the right side (+Z).
-- The belly half is a little flatter than the back.
local function corner(station, k: number): Vector3
	local angle = k / SIDES * math.pi * 2
	local up = math.cos(angle)
	local height = if up < 0 then station.h * 0.85 else station.h
	return Vector3.new(station.x, station.cy + height * up, station.w * math.sin(angle))
end

-- The body's surface at any point: position and outward direction, for placing eyes, gills and scars.
local function surface(x: number, angle: number): (Vector3, Vector3)
	local a, b = STATIONS[1], STATIONS[#STATIONS]
	for i = 1, #STATIONS - 1 do
		if x <= STATIONS[i].x and x >= STATIONS[i + 1].x then
			a, b = STATIONS[i], STATIONS[i + 1]
		end
	end
	local t = if a.x == b.x then 0 else (a.x - x) / (a.x - b.x)
	local h, w, cy = a.h + (b.h - a.h) * t, a.w + (b.w - a.w) * t, a.cy + (b.cy - a.cy) * t
	local up, side = math.cos(angle), math.sin(angle)
	local point = Vector3.new(x, cy + h * up, w * side)
	local normal = Vector3.new(0, up / h, side / w).Unit
	return point, normal
end

-- Draws a solid triangle a-b-c with two wedges (the standard Roblox triangle trick).
local function triangle(parent: Instance, a: Vector3, b: Vector3, c: Vector3, color: Color3, material: Enum.Material?, glow: boolean?)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab)
	if right.Magnitude < 1e-6 then
		return -- a squashed triangle with no area
	end
	right = right.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	if height < 0.01 then
		return
	end
	for _, half in { { (a + b) / 2, right, back, math.abs(ab:Dot(back)) }, { (a + c) / 2, -right, -back, math.abs(ac:Dot(back)) } } do
		if half[4] > 0.01 then
			local wedge = Instance.new("WedgePart")
			wedge.Size = Vector3.new(THICKNESS, height, half[4])
			wedge.CFrame = CFrame.fromMatrix(half[1], half[2], up, half[3])
			wedge.Color = color
			wedge.Material = material or SKIN
			wedge.Reflectance = if glow then 0 else 0.04 -- a faint wet sheen
			wedge.TopSurface = Enum.SurfaceType.Smooth
			wedge.BottomSurface = Enum.SurfaceType.Smooth
			wedge.CanCollide = false
			wedge.CanQuery = false
			wedge.CanTouch = false
			wedge.Massless = true
			wedge.Anchored = false
			wedge.Parent = parent
		end
	end
end

-- Facets alternate slightly in brightness so the low-poly shape reads clearly in the dark.
local function shade(color: Color3, seed: number): Color3
	local f = 1 + (math.sin(seed * 12.9898) * 0.5) * 0.12
	return Color3.new(math.clamp(color.R * f, 0, 1), math.clamp(color.G * f, 0, 1), math.clamp(color.B * f, 0, 1))
end

-- Dark back or pale belly, decided by how low the face sits on the body.
local function skinColor(a: Vector3, b: Vector3, c: Vector3, centerY: number, seed: number): Color3
	local mid = (a + b + c) / 3
	return shade(if mid.Y < centerY - 0.35 then BELLY else TOP, seed)
end

local function plainPart(parent: Instance, name: string, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	if shape then
		part.Shape = shape
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.Parent = parent
	return part
end

-- Builds one shark at the given scale, at the origin. Returns the model.
local function build(scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Shark"
	local bodyFolder = Instance.new("Folder")
	bodyFolder.Name = "Body"
	bodyFolder.Parent = model
	local jawFolder = Instance.new("Folder")
	jawFolder.Name = "Jaw"
	jawFolder.Parent = model
	local tailFolder = Instance.new("Folder")
	tailFolder.Name = "Tail"
	tailFolder.Parent = model

	local function s(v: Vector3): Vector3
		return v * scale
	end

	-- Rings of corners for every cross-section.
	local rings = {}
	for i, station in STATIONS do
		rings[i] = {}
		for k = 0, SIDES - 1 do
			rings[i][k] = corner(station, k)
		end
	end
	local function isLower(k: number): boolean
		return k >= 2 and k <= 6 -- from the right side, under the belly, round to the left side
	end

	-- Nose cone: the top half belongs to the head, the bottom half to the jaw.
	for k = 0, SIDES - 1 do
		local k2 = (k + 1) % SIDES
		local a, b = rings[1][k], rings[1][k2]
		local lower = isLower(k) and isLower(k2)
		triangle(if lower then jawFolder else bodyFolder, s(NOSE), s(a), s(b), skinColor(NOSE, a, b, STATIONS[1].cy, k), nil)
	end

	-- The hull, section by section.
	for i = 1, #STATIONS - 1 do
		local folder = if i >= TAIL_HINGE_STATION then tailFolder else bodyFolder
		for k = 0, SIDES - 1 do
			local k2 = (k + 1) % SIDES
			local a, b = rings[i][k], rings[i][k2]
			local c, d = rings[i + 1][k], rings[i + 1][k2]
			local target = folder
			if i < HEAD_STATIONS + 1 and isLower(k) and isLower(k2) then
				target = jawFolder -- under the head: the lower jaw
			end
			local seed = i * 10 + k
			triangle(target, s(a), s(b), s(c), skinColor(a, b, c, STATIONS[i].cy, seed))
			triangle(target, s(b), s(d), s(c), skinColor(b, d, c, STATIONS[i].cy, seed + 0.5))
		end
	end

	-- Tail cap.
	local last = #STATIONS
	for k = 0, SIDES - 1 do
		local k2 = (k + 1) % SIDES
		triangle(tailFolder, s(TAIL_END), s(rings[last][k2]), s(rings[last][k]), shade(TOP, k))
	end

	-- Mouth: red gums closing the inside of both jaws, between the left and right mouth corners
	-- (corners 2 and 6), and the teeth along them.
	local rimRight, rimLeft = {}, {}
	table.insert(rimRight, NOSE + Vector3.new(-0.1, -0.15, 0.12))
	table.insert(rimLeft, NOSE + Vector3.new(-0.1, -0.15, -0.12))
	for i = 1, HEAD_STATIONS + 1 do
		table.insert(rimRight, rings[i][2])
		table.insert(rimLeft, rings[i][6])
	end
	for i = 1, #rimRight - 1 do
		-- Roof of the mouth (head) and floor of the mouth (jaw), a hair inside the rim.
		local inset = Vector3.new(0, 0.05, 0)
		triangle(bodyFolder, s(rimRight[i] - inset), s(rimLeft[i] - inset), s(rimRight[i + 1] - inset), GUM)
		triangle(bodyFolder, s(rimLeft[i] - inset), s(rimLeft[i + 1] - inset), s(rimRight[i + 1] - inset), GUM)
		triangle(jawFolder, s(rimRight[i] + inset), s(rimRight[i + 1] + inset), s(rimLeft[i] + inset), GUM)
		triangle(jawFolder, s(rimLeft[i] + inset), s(rimRight[i + 1] + inset), s(rimLeft[i + 1] + inset), GUM)
	end

	-- Teeth: a big front row and a smaller back row, top and bottom, all the way along the rim.
	local function teethAlong(rim, folder: Instance, direction: number)
		for i = 1, #rim - 1 do
			local from, to = rim[i], rim[i + 1]
			local count = math.max(1, math.floor((to - from).Magnitude / 0.55))
			for t = 0, count - 1 do
				local p1 = from:Lerp(to, t / count)
				local p2 = from:Lerp(to, (t + 1) / count)
				local inward = Vector3.new(0, 0, -math.sign(p1.Z + p2.Z) * 0.12)
				for row, settings in { { length = 0.75, inset = 0, color = TOOTH }, { length = 0.45, inset = 0.28, color = TOOTH_BACK } } do
					local offset = inward * (1 + settings.inset * 6) -- the back row sits further inside the mouth
					local base1, base2 = p1 + offset, p2 + offset
					local tip = (base1 + base2) / 2 + Vector3.new(0, direction * settings.length, 0) + inward * 0.6
					-- Every few teeth is longer, so the row looks jagged instead of even.
					if (t + i + row) % 3 == 0 then
						tip += Vector3.new(0, direction * 0.2, 0)
					end
					triangle(folder, s(base1), s(base2), s(tip), settings.color)
				end
			end
		end
	end
	teethAlong(rimRight, bodyFolder, -1)
	teethAlong(rimLeft, bodyFolder, -1)
	teethAlong(rimRight, jawFolder, 1)
	teethAlong(rimLeft, jawFolder, 1)

	-- The throat: a dark cavern behind the teeth, with a cold glow deep inside.
	local throat = plainPart(bodyFolder, "Throat", CFrame.new(s(Vector3.new(2.6, -0.5, 0))), s(Vector3.new(3.2, 3.2, 3.2)), THROAT, SKIN, Enum.PartType.Ball)
	throat.CastShadow = false
	local glow = plainPart(bodyFolder, "ThroatGlow", CFrame.new(s(Vector3.new(1.8, -0.5, 0))), s(Vector3.new(1.2, 1.2, 1.2)), GLOW, Enum.Material.Neon, Enum.PartType.Ball)
	glow.Transparency = 0.35
	local glowLight = Instance.new("PointLight")
	glowLight.Color = GLOW
	glowLight.Range = 6 * scale
	glowLight.Brightness = 0.9
	glowLight.Parent = glow

	-- Eyes: small, glossy and black, set wide on the head, with a tiny cyan glint.
	for _, side in { -1, 1 } do
		local point, normal = surface(4.5, math.rad(if side == 1 then 62 else -62))
		local eye = plainPart(bodyFolder, "Eye", CFrame.lookAt(s(point), s(point + normal)), s(Vector3.new(0.5, 0.5, 0.5)), Color3.fromRGB(6, 6, 8), Enum.Material.Glass, Enum.PartType.Ball)
		eye.Reflectance = 0.35
		plainPart(bodyFolder, "EyeGlint", CFrame.new(s(point + normal * 0.2 + Vector3.new(0.08, 0.06, 0))), s(Vector3.new(0.12, 0.12, 0.12)), GLOW, Enum.Material.Neon, Enum.PartType.Ball)
	end

	-- Gills: five slits on each side, glowing cyan from inside.
	for _, side in { -1, 1 } do
		for g = 0, 4 do
			local x = 2.5 - g * 0.42
			local point, normal = surface(x, math.rad(side * 88))
			local slit = CFrame.lookAt(s(point + normal * 0.02), s(point + normal)) * CFrame.Angles(0, 0, math.rad(8))
			plainPart(bodyFolder, "Gill", slit, s(Vector3.new(0.09, 1.7 - g * 0.12, 0.06)), Color3.fromRGB(8, 10, 14), SKIN)
			local light = plainPart(bodyFolder, "GillGlow", slit * CFrame.new(0, 0, 0.02), s(Vector3.new(0.04, 1.4 - g * 0.12, 0.04)), GLOW, Enum.Material.Neon)
			light.Transparency = 0.25
		end
	end

	-- Scars: pale scratches on the snout and flanks (it has been through a lot).
	local scars = {
		{ x = 5.6, angle = 20, length = 0.9, tilt = 30 },
		{ x = 5.0, angle = -30, length = 0.7, tilt = -20 },
		{ x = 3.4, angle = 45, length = 1.3, tilt = 60 },
		{ x = 0.4, angle = 60, length = 1.8, tilt = 15 },
		{ x = -1.2, angle = -55, length = 1.6, tilt = -25 },
		{ x = -2.6, angle = 35, length = 1.1, tilt = 70 },
		{ x = 1.0, angle = -40, length = 1.2, tilt = 40 },
	}
	for _, scar in scars do
		local point, normal = surface(scar.x, math.rad(scar.angle))
		plainPart(bodyFolder, "Scar", CFrame.lookAt(s(point + normal * 0.03), s(point + normal)) * CFrame.Angles(0, 0, math.rad(scar.tilt)), s(Vector3.new(0.1, scar.length, 0.04)), SCAR, SKIN)
	end

	-- Fins (each a flat solid triangle or two).
	local function fin(folder: Instance, points: { Vector3 })
		for i = 2, #points - 1 do
			triangle(folder, s(points[1]), s(points[i]), s(points[i + 1]), shade(TOP, i + #points))
		end
	end
	-- Tall dorsal fin, with a notch torn out of the back edge and a few jagged spikes.
	fin(bodyFolder, { Vector3.new(2.0, 2.6, 0), Vector3.new(-0.8, 6.9, 0), Vector3.new(-0.9, 5.6, 0) })
	fin(bodyFolder, { Vector3.new(2.0, 2.6, 0), Vector3.new(-0.9, 5.6, 0), Vector3.new(-0.3, 4.9, 0), Vector3.new(-1.1, 4.2, 0), Vector3.new(-1.6, 2.7, 0) })
	fin(bodyFolder, { Vector3.new(-1.1, 4.2, 0), Vector3.new(-1.9, 3.7, 0), Vector3.new(-1.6, 2.7, 0) })
	-- Long pectoral fins, swept back and down.
	for _, side in { -1, 1 } do
		local root1 = Vector3.new(2.4, -1.4, side * 2.1)
		local root2 = Vector3.new(0.6, -1.6, side * 2.2)
		fin(bodyFolder, { root1, Vector3.new(-2.4, -3.6, side * 5.2), root2 })
	end
	-- Small second dorsal and anal fins, on the tail.
	fin(tailFolder, { Vector3.new(-5.0, 1.4, 0), Vector3.new(-6.0, 2.4, 0), Vector3.new(-6.0, 1.0, 0) })
	fin(tailFolder, { Vector3.new(-5.2, -1.1, 0), Vector3.new(-6.2, -1.9, 0), Vector3.new(-6.1, -0.7, 0) })
	-- Crescent tail: a tall top lobe and a shorter bottom lobe, with jagged trailing edges.
	fin(tailFolder, { Vector3.new(-7.0, 0.5, 0), Vector3.new(-8.6, 2.6, 0), Vector3.new(-10.4, 4.6, 0), Vector3.new(-9.4, 2.3, 0), Vector3.new(-9.9, 1.6, 0), Vector3.new(-7.8, 0.1, 0) })
	fin(tailFolder, { Vector3.new(-7.0, -0.2, 0), Vector3.new(-7.8, 0.1, 0), Vector3.new(-9.2, -1.4, 0), Vector3.new(-9.7, -2.9, 0), Vector3.new(-8.4, -2.2, 0) })

	-- The Root everything hangs off, and the two joints.
	local root = plainPart(model, "Root", CFrame.identity, s(Vector3.one), Color3.new(), SKIN)
	root.Transparency = 1
	root.Anchored = true
	root.Massless = false
	model.PrimaryPart = root
	local function joint(name: string, folder: Instance, hinge: Vector3)
		local hingeFrame = CFrame.new(s(hinge))
		local pivot = plainPart(model, name .. "Root", hingeFrame, s(Vector3.one * 0.5), Color3.new(), SKIN)
		pivot.Transparency = 1
		for _, part in folder:GetChildren() do
			if part:IsA("BasePart") then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = pivot
				weld.Part1 = part
				weld.Parent = part
			end
		end
		local motor = Instance.new("Motor6D")
		motor.Name = name .. "Motor"
		motor.Part0 = root
		motor.Part1 = pivot
		motor.C0 = hingeFrame
		motor.C1 = CFrame.identity
		motor.Parent = root
	end
	joint("Jaw", jawFolder, JAW_HINGE)
	joint("Tail", tailFolder, STATIONS[TAIL_HINGE_STATION].x * Vector3.xAxis + Vector3.new(0, STATIONS[TAIL_HINGE_STATION].cy, 0))
	for _, part in bodyFolder:GetChildren() do
		if part:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end

	-- Small details don't need shadows.
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Size.Magnitude < 1.5 * scale then
			part.CastShadow = false
		end
	end
	return model
end

local cache: Folder? = nil
local templates: { [number]: Model } = {}

-- A new shark at this scale (1 = about 15 studs nose to tail fin), parented to `parent`.
function SharkModel.new(scale: number, name: string, parent: Instance)
	local template = templates[scale]
	if not template then
		if not cache then
			local folder = Instance.new("Folder")
			folder.Name = "SharkTemplates"
			folder.Parent = ServerStorage
			cache = folder
		end
		template = build(scale)
		template.Parent = cache
		templates[scale] = template
	end
	local model = template:Clone()
	model.Name = name
	local root = model:FindFirstChild("Root") :: Part
	local self = setmetatable({
		model = model,
		root = root,
		jawMotor = root:FindFirstChild("JawMotor") :: Motor6D,
		tailMotor = root:FindFirstChild("TailMotor") :: Motor6D,
		scale = scale,
	}, SharkModel)
	self.jawHinge = self.jawMotor.C0
	self.tailHinge = self.tailMotor.C0
	self.mouth = MOUTH * scale
	model.Parent = parent
	return self
end

-- Moves the shark (root facing +X), opens the jaw (radians, 0 = shut, about 0.6 = gaping) and
-- swings the tail (radians, side to side).
function SharkModel:pose(cframe: CFrame, jawOpen: number, tailSwing: number)
	self.root.CFrame = cframe
	self.jawMotor.C0 = self.jawHinge * CFrame.Angles(0, 0, -jawOpen)
	self.tailMotor.C0 = self.tailHinge * CFrame.Angles(0, tailSwing, 0)
end

-- Where the mouth is right now, in the world.
function SharkModel:mouthPosition(): Vector3
	return self.root.CFrame * self.mouth
end

function SharkModel:destroy()
	self.model:Destroy()
end

return SharkModel
