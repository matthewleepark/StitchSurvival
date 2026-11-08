-- Swings the Killer Hotel doors. The server only keeps each door's state (open, locked, pounded on) as
-- attributes on a model tagged "KillerDoor"; every client animates the swing itself so it is smooth.
--
-- A door swings OUT of its room on a spring: opening is a kick (a burst of speed that overshoots and
-- bounces back), closing is a smooth, firm shut. A pound from the killer makes a locked door shudder.
-- The door has no collision while it is moving, so it can never trap anyone. If a bomb or the killer
-- rips it loose (its parts are no longer anchored) physics takes over and this stops animating it.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "KillerDoor"

-- Springs: angle is in radians, 0 = shut.
local OPEN_STIFFNESS, OPEN_DAMPING, KICK_SPEED = 300, 15, 10
local SHUT_STIFFNESS, SHUT_DAMPING = 150, 2 * math.sqrt(150)
local POUND_JOLT = 1.8

type Door = {
	model: Model,
	panel: BasePart,
	closedPivot: CFrame,
	hinge: Vector3,
	sign: number,
	openAngle: number,
	angle: number,
	velocity: number,
	target: number,
	moving: boolean,
	pounds: number,
}

local Doors = {}

local doors: { [Model]: Door } = {}
local moving: { [Model]: boolean } = {}

local function apply(door: Door)
	local turn = CFrame.new(door.hinge) * CFrame.Angles(0, door.sign * door.angle, 0) * CFrame.new(-door.hinge)
	door.model:PivotTo(turn * door.closedPivot)
end

local function wake(door: Door, passThrough: boolean)
	if not door.moving then
		door.moving = true
		if passThrough then
			door.panel.CanCollide = false -- no collision while it swings, so it can never trap anyone
		end
	end
	moving[door.model] = true
end

local function forget(model: Model)
	doors[model] = nil
	moving[model] = nil
end

local function setOpen(door: Door, open: boolean, kick: boolean)
	door.target = if open then door.openAngle else 0
	if open and kick then
		door.velocity = KICK_SPEED
	end
	wake(door, true)
end

local function attach(model: Model, panel: BasePart, hinge: Vector3)
	local door: Door = {
		model = model,
		panel = panel,
		closedPivot = model:GetPivot(),
		hinge = hinge,
		sign = model:GetAttribute("Sign") or 1,
		openAngle = model:GetAttribute("OpenAngle") or math.rad(100),
		angle = 0,
		velocity = 0,
		target = 0,
		moving = false,
		pounds = model:GetAttribute("Pound") or 0,
	}
	doors[model] = door

	-- Joined while it was already open: put it there without a kick.
	if model:GetAttribute("Open") then
		door.angle = door.openAngle
		door.target = door.openAngle
		apply(door)
	end

	model:GetAttributeChangedSignal("Open"):Connect(function()
		setOpen(door, model:GetAttribute("Open") == true, true)
	end)
	-- Torn loose by a bomb or the killer: it is solid again right now (a collision turned off here would
	-- make it fall through the floor on this client) and physics takes over.
	panel:GetPropertyChangedSignal("Anchored"):Connect(function()
		if not panel.Anchored then
			panel.CanCollide = true
			forget(model)
		end
	end)
	model:GetAttributeChangedSignal("Pound"):Connect(function()
		local pounds = model:GetAttribute("Pound") or 0
		if pounds ~= door.pounds then
			door.pounds = pounds
			if door.target == 0 then
				door.velocity += POUND_JOLT -- a shudder against the lock (it stays solid)
				wake(door, false)
			end
		end
	end)
end

-- The tag can arrive before the door's parts do, so wait for the panel (and for the model's pivot, which is
-- its PrimaryPart's) before reading anything.
local pending: { [Model]: boolean } = {}
local function track(model: Model)
	if doors[model] or pending[model] then
		return
	end
	pending[model] = true
	task.spawn(function()
		local panel = model:WaitForChild("Panel", 10) :: BasePart?
		local waited = 0
		while panel and model.PrimaryPart ~= panel and waited < 5 do
			waited += task.wait(0.1)
		end
		pending[model] = nil
		local hinge = model:GetAttribute("Hinge")
		if panel and typeof(hinge) == "Vector3" and model:IsDescendantOf(workspace) then
			attach(model, panel, hinge)
		end
	end)
end

function Doors.start()
	for _, model in CollectionService:GetTagged(TAG) do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(forget)

	RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 1 / 30)
		for model in moving do
			local door = doors[model]
			if not door then
				moving[model] = nil
			elseif not door.panel.Anchored or not door.panel.Parent then
				door.panel.CanCollide = true
				forget(model) -- torn loose: physics has it now
			else
				local opening = door.target > 0
				local stiffness = if opening then OPEN_STIFFNESS else SHUT_STIFFNESS
				local damping = if opening then OPEN_DAMPING else SHUT_DAMPING
				for _ = 1, 2 do
					local step = dt / 2
					local acceleration = -stiffness * (door.angle - door.target) - damping * door.velocity
					door.velocity += acceleration * step
					door.angle += door.velocity * step
				end
				-- Never swing back through the frame, and never fling wide open.
				if door.angle < 0 then
					door.angle = 0
					door.velocity = math.max(door.velocity, 0)
				elseif door.angle > door.openAngle * 1.25 then
					door.angle = door.openAngle * 1.25
					door.velocity = math.min(door.velocity, 0)
				end
				if math.abs(door.angle - door.target) < 0.002 and math.abs(door.velocity) < 0.03 then
					door.angle = door.target
					door.velocity = 0
					door.moving = false
					door.panel.CanCollide = true
					moving[model] = nil
				end
				apply(door)
			end
		end
	end)
end

return Doors
