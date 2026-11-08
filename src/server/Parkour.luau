-- Killer Hotel parkour, decided on the server: running (with a stamina bar) and clambering onto climbable
-- things. Clients only send intents: "I am holding the run key" (Sprint) and "I want to clamber onto this
-- part" (Clamber). Everything else is here.
--
--   * RUN: while the run key is held, you are moving, and you have stamina, walking speed is multiplied by
--     Config.KillerHotel.parkour.runMultiplier. The bar empties over runSeconds, refills over regenSeconds
--     after a short delay, and an empty bar means "exhausted": no running until it is back to exhaustedUntil.
--     The killer walks and runs killerWalkMultiplier faster than everyone else.
--   * CLAMBER: allowed only for parts tagged "Climbable" whose top is between minLedge and reach studs above
--     your feet, within maxDistance, with nothing solid in the way or above, enough stamina, and not too soon
--     after the last one (rules in shared/ClamberMath.luau). If allowed, the server tells that client to
--     play the move (a "ClamberGo" effect) and, once it should be done, makes sure you ended up on top. The
--     killer takes killerClamberMultiplier times longer.
--
-- Only runs during a Killer Hotel round. Each player's stamina is the "Stamina" attribute (0 to 1) so the
-- client can draw the bar; it is cleared when the round is over.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ClamberMath = require(ReplicatedStorage.Shared.ClamberMath)
local Remotes = require(script.Parent.Remotes)
local RoundControl = require(script.Parent.RoundControl)
local Util = require(script.Parent.Util)

local P = Config.KillerHotel.parkour
local TICK = 0.1

local Parkour = {}

type State = {
	want: boolean, -- is the run key held?
	stamina: number,
	exhausted: boolean,
	lastUse: number, -- when stamina was last spent
	lastClamber: number,
	clamberUntil: number,
	shown: number, -- the stamina value last sent out
}

local states: { [Player]: State } = {}

-- The running Killer Hotel stage, but only while the round is actually being played.
local function activeStage()
	local stage = RoundControl.stage
	if RoundControl.levelName == "KillerHotel" and stage and not stage.frozen and ReplicatedStorage:GetAttribute("Phase") == "Playing" then
		return stage
	end
	return nil
end

local function inRound(stage, player: Player): boolean
	return player == stage.killer or stage.innocents[player] == true
end

local function baseSpeed(humanoid: Humanoid): number
	return humanoid:GetAttribute("BaseWalkSpeed") or Config.Doll.WalkSpeed
end

local function feetOffset(humanoid: Humanoid, root: BasePart): number
	return humanoid.HipHeight + root.Size.Y / 2
end

-- Puts a player's speed and bar back to normal (the round is over, or they left).
local function release(player: Player)
	states[player] = nil
	player:SetAttribute("Stamina", nil)
	player:SetAttribute("Exhausted", nil)
	local humanoid = Util.aliveHumanoid(player)
	if humanoid then
		humanoid.WalkSpeed = baseSpeed(humanoid)
	end
end

local function step(player: Player, stage, dt: number)
	local humanoid = Util.aliveHumanoid(player)
	local root = Util.rootPart(player)
	if not humanoid or not root then
		return
	end
	local now = os.clock()
	local state = states[player]
	if not state then
		state = { want = false, stamina = 1, exhausted = false, lastUse = 0, lastClamber = 0, clamberUntil = 0, shown = -1 }
		states[player] = state
	end

	local moving = Util.flatten(root.AssemblyLinearVelocity).Magnitude > 3
	local running = state.want and moving and not state.exhausted and state.stamina > 0 and now >= state.clamberUntil and not stage.hiding[player]
	if running then
		state.stamina = math.max(0, state.stamina - dt / P.runSeconds)
		state.lastUse = now
		if state.stamina <= 0 then
			state.exhausted = true
		end
	elseif now - state.lastUse >= P.regenDelay then
		state.stamina = math.min(1, state.stamina + dt / P.regenSeconds)
	end
	if state.exhausted and state.stamina >= P.exhaustedUntil then
		state.exhausted = false
	end

	local speed = baseSpeed(humanoid) * (if player == stage.killer then P.killerWalkMultiplier else 1) * (if running then P.runMultiplier else 1)
	if math.abs(humanoid.WalkSpeed - speed) > 0.01 then
		humanoid.WalkSpeed = speed -- only written when it changes, so the client's own tweaks (Grab) are not fought
	end

	if math.abs(state.stamina - state.shown) >= 0.02 or state.stamina == 0 or state.stamina == 1 then
		state.shown = state.stamina
		player:SetAttribute("Stamina", math.floor(state.stamina * 100 + 0.5) / 100)
	end
	if player:GetAttribute("Exhausted") ~= state.exhausted then
		player:SetAttribute("Exhausted", state.exhausted)
	end
end

local function tryClamber(player: Player, part: any)
	local stage = activeStage()
	local state = states[player]
	if not stage or not state or not inRound(stage, player) or typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return
	end
	local humanoid = Util.aliveHumanoid(player)
	local root = Util.rootPart(player)
	if not humanoid or not root or stage.hiding[player] then
		return
	end
	local now = os.clock()
	if now - state.lastClamber < P.clamberCooldown or now < state.clamberUntil or state.stamina < P.clamberCost then
		return
	end
	if not CollectionService:HasTag(part, "Climbable") or not part:IsDescendantOf(stage.model) or not part.Anchored then
		return
	end
	local result = ClamberMath.evaluate(part, root.Position, feetOffset(humanoid, root), P)
	if not result then
		return
	end

	-- Nothing solid between you and the edge (no clambering through a wall), and room to stand on top.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local chest = root.Position + Vector3.new(0, 1, 0)
	local toEdge = Vector3.new(result.nearest.X - chest.X, 0, result.nearest.Z - chest.Z)
	if toEdge.Magnitude > 0.2 then
		local hit = workspace:Raycast(chest, toEdge, params)
		if hit and hit.Instance ~= part and not CollectionService:HasTag(hit.Instance, "Climbable") then
			return
		end
	end
	if workspace:Raycast(result.nearest + Vector3.new(0, 0.3, 0), Vector3.new(0, 5.2, 0), params) then
		return
	end

	local duration = (P.clamberSeconds + P.clamberSecondsPerStud * result.rise) * (if player == stage.killer then P.killerClamberMultiplier else 1)
	state.stamina = math.max(0, state.stamina - P.clamberCost)
	state.lastUse = now
	state.lastClamber = now
	state.clamberUntil = now + duration + 0.3
	Util.playSound("Clamber", root)
	Remotes.fire(player, "ClamberGo", { target = result.target, duration = duration })

	-- Once it should be over, make sure they ended up on top (a laggy or cheating client is put there).
	task.delay(duration + 0.5, function()
		local nowRoot = Util.rootPart(player)
		if nowRoot and Util.aliveHumanoid(player) and (nowRoot.Position - result.target).Magnitude > 5 and not stage.frozen then
			nowRoot.AssemblyLinearVelocity = Vector3.zero
			nowRoot.CFrame = CFrame.new(result.target)
		end
	end)
end

function Parkour.start()
	Remotes.Sprint.OnServerEvent:Connect(function(player: Player, on: any)
		local stage = activeStage()
		if not stage or not inRound(stage, player) or typeof(on) ~= "boolean" then
			return
		end
		local state = states[player]
		if state then
			state.want = on
		else
			states[player] = { want = on, stamina = 1, exhausted = false, lastUse = 0, lastClamber = 0, clamberUntil = 0, shown = -1 }
		end
	end)
	Remotes.Clamber.OnServerEvent:Connect(tryClamber)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	task.spawn(function()
		while true do
			local stage = activeStage()
			if stage then
				for _, player in Players:GetPlayers() do
					if inRound(stage, player) then
						step(player, stage, TICK)
					end
				end
			elseif next(states) then
				for player in table.clone(states) do
					release(player)
				end
			end
			task.wait(TICK)
		end
	end)
end

return Parkour
