-- The Bomb Hotel CHAOS MODE shark: one huge, battle-scarred flying great white per chaos round.
-- A red crack glows on an outer wall first, then the shark appears and has to CHEW its way in, one
-- block at a time. Inside, it flops slowly around the hotel on its own wandering path (it doesn't
-- chase anyone), biting through any wall, floor or pillar in its way and chomping whoever it hits.
--
-- Its body is the shared low-poly great white from SharkModel.luau, built at Config.Chaos.sharkScale.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Craft = require(script.Parent.Parent.Craft)
local Remotes = require(script.Parent.Parent.Remotes)
local Util = require(script.Parent.Parent.Util)
local Bombs = require(script.Parent.Bombs)
local SharkModel = require(script.Parent.SharkModel)

local FlyingShark = {}

local DUST = Color3.fromRGB(42, 48, 60) -- the puff it leaves when it vanishes
local BITE_RANGE = 6

local NO_COLLIDE = { CanCollide = false, CanQuery = false, CanTouch = false }

-- The chaos shark: a red crack warns where it'll come in, it chews its way through the outer wall,
-- then it flies around the hotel on its own wandering path until the round ends, chewing through
-- anything in its way and chomping anyone it runs into. It doesn't chase people.
function FlyingShark.attack(stage, ctx)
	local settings = Config.Chaos
	local S = settings.sharkScale
	local O, halfW, halfD = stage.origin, stage.width / 2, stage.depth / 2

	-- Pick a random spot on a random outer wall to come in through.
	local sides = {
		{ normal = Vector3.new(-1, 0, 0), wall = O.X - halfW },
		{ normal = Vector3.new(1, 0, 0), wall = O.X + halfW },
		{ normal = Vector3.new(0, 0, -1), wall = O.Z - halfD },
		{ normal = Vector3.new(0, 0, 1), wall = O.Z + halfD },
	}
	local side = sides[math.random(1, #sides)]
	local height = O.Y + math.random(6, stage.roofY - 8)
	local entry = if side.normal.X ~= 0
		then Vector3.new(side.wall, height, O.Z + math.random(-30, 30))
		else Vector3.new(O.X + math.random(-30, 30), height, side.wall)

	-- The warning: a big jagged red crack glowing on the inside of the wall.
	local crack = Instance.new("Model")
	crack.Name = "WallCrack"
	local facing = CFrame.lookAt(entry - side.normal * 0.4, entry - side.normal * 2)
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		local length = (3 + math.random() * 3) * S
		local piece = Craft.block(crack, facing * CFrame.Angles(0, 0, angle) * CFrame.new(0, length / 2, 0), Vector3.new(0.4, length, 0.1), Color3.fromRGB(255, 40, 30), Enum.Material.Neon, NO_COLLIDE)
		piece.CastShadow = false
	end
	crack.Parent = stage.model
	Util.soundAt("WallCrack", entry)
	Remotes.fireAll("Rumble", { position = entry })
	task.wait(settings.warning)
	crack:Destroy()
	if stage.frozen or not stage.model.Parent or not ctx.isActive() then
		return
	end

	-- It appears just outside the wall, facing in.
	local shark = SharkModel.new(S, "ChaosShark", stage.model)
	local model = shark.model
	Craft.tag(model, "Hazard") -- the Spooky Sense passive shows it through walls
	local position = entry + side.normal * 9 * S
	local heading = -side.normal
	local bitten: { [Player]: boolean } = {}
	local clock, chewTimer = 0, 0
	Util.soundAt("SharkRoar", entry)

	-- Wandering: fly toward a random spot inside the hotel, then pick another one.
	local function randomSpot(): Vector3
		return Vector3.new(
			O.X + math.random(-(halfW - 10), halfW - 10),
			O.Y + math.random(5, stage.roofY - 6),
			O.Z + math.random(-(halfD - 10), halfD - 10)
		)
	end
	local goal = entry - side.normal * 30 -- first, straight in through the hole it makes

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { stage.breakables }

	local finished = false
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if stage.frozen or not model.Parent or not ctx.isActive() then
			finished = true
			connection:Disconnect()
			if model.Parent and not stage.frozen then
				Remotes.fireAll("Poof", { position = position, color = DUST })
				model:Destroy()
			end
			return
		end
		clock += dt
		chewTimer -= dt

		-- Reached the spot it was heading for? Pick a new one somewhere else.
		if (goal - position).Magnitude < 6 * S then
			goal = randomSpot()
		end
		heading = heading:Lerp((goal - position).Unit, math.min(1, dt * 0.8)).Unit

		-- Anything breakable right in front of its mouth has to be chewed through first.
		local mouthAhead = position + heading * 7 * S
		local blocking = nil
		for _, part in workspace:GetPartBoundsInRadius(mouthAhead, 3.5 * S, params) do
			if part:GetAttribute("Breakable") and part.Anchored then
				blocking = part
				break
			end
		end
		local open
		if blocking then
			-- CHOMP: one block at a time, with a short pause between bites.
			open = (math.sin(clock * 14) + 1) / 2 * 0.7
			if chewTimer <= 0 then
				chewTimer = settings.sharkChew
				Util.playSound("Chomp", shark.root)
				Bombs.breakBlock(stage, blocking, position)
			end
		else
			open = (math.sin(clock * 7) + 1) / 2 * 0.55
			position += heading * settings.sharkSpeed * dt
		end

		-- Pose: flopping back and forth (rolling, wiggling and bobbing) as it flies.
		local roll = math.sin(clock * 5) * 0.4
		local wiggle = math.sin(clock * 7) * 0.22
		local bob = Vector3.new(0, math.sin(clock * 3) * 0.6 * S, 0)
		local rootFrame = CFrame.lookAt(position + bob, position + bob + heading) * CFrame.Angles(0, math.rad(90) + wiggle, 0) * CFrame.Angles(roll, 0, 0)
		shark:pose(rootFrame, open, math.sin(clock * 7 - 0.9) * 0.45)

		-- Chomp anyone it runs into (each player only once per round).
		local mouth = shark:mouthPosition()
		for _, player in Players:GetPlayers() do
			local humanoid = Util.aliveHumanoid(player)
			local playerRoot = Util.rootPart(player)
			if humanoid and playerRoot and not bitten[player] and (playerRoot.Position - mouth).Magnitude < BITE_RANGE * S then
				bitten[player] = true
				Util.playSound("Chomp", shark.root)
				if Util.kill(humanoid) then
					Remotes.fire(player, "Jumpscare", {}) -- the victim's screen only
				end
			end
		end
	end)

	while not finished do
		task.wait(0.2)
	end
end

return FlyingShark
