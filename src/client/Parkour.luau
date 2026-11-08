-- Killer Hotel parkour, your side: the run key, the stamina bar, and the clamber.
--
--   * RUN: hold the run key (Shift, gamepad left stick click, or the RUN button on touch). We only tell the
--     server whether it is held; the server decides your speed and your stamina.
--   * CLAMBER: press jump next to a climbable thing (tagged "Climbable") and we ask the server to let you
--     clamber onto it. If it says yes (a "ClamberGo" effect, with where you end up and how long it takes) we
--     play the move: you are carried up and over to the spot. The killer's takes longer.
--
-- The controls only exist while the server has given you a stamina bar, which it does during a Killer Hotel
-- round (the "Stamina" attribute on you). Shift would normally toggle Roblox's shift-lock, so we take it first.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local ClamberMath = require(ReplicatedStorage.Shared.ClamberMath)
local Grab = require(script.Parent.Grab)

local Colors = Config.Colors
local P = Config.KillerHotel.parkour
local player = Players.LocalPlayer
local ACTION = "Sprint"

local Parkour = {}

local active = false
local clambering = false
local lastRequest = 0
local gui: ScreenGui
local bar: Frame
local fill: Frame
local label: TextLabel
local sprintEvent: RemoteEvent
local clamberEvent: RemoteEvent

local function new(className: string, props, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function build()
	gui = new("ScreenGui", { Name = "Parkour", ResetOnSpawn = false, DisplayOrder = 39, Enabled = false }, player:WaitForChild("PlayerGui"))
	bar = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(240, 20),
		BackgroundColor3 = Colors.Paper,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, bar)
	new("UIStroke", { Thickness = 3, Color = Colors.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, bar)
	fill = new("Frame", {
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundColor3 = Color3.fromRGB(88, 160, 96),
		BorderSizePixel = 0,
	}, bar)
	new("UICorner", { CornerRadius = UDim.new(0, 7) }, fill)
	label = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -2),
		Size = UDim2.fromOffset(240, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 14,
		TextColor3 = Colors.Paper,
		TextStrokeTransparency = 0.3,
		TextStrokeColor3 = Colors.Ink,
		Text = "",
	}, bar)
end

local function refreshBar()
	local stamina = player:GetAttribute("Stamina")
	if stamina == nil then
		return
	end
	local exhausted = player:GetAttribute("Exhausted") == true
	fill.Size = UDim2.new(math.clamp(stamina, 0, 1), -6, 1, -6)
	fill.BackgroundColor3 = if exhausted then Colors.Warning else Color3.fromRGB(88, 160, 96)
	label.Text = if exhausted then "OUT OF BREATH" else ""
end

-- Run -----------------------------------------------------------------------------------------------

local function onSprint(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		sprintEvent:FireServer(true)
	else
		sprintEvent:FireServer(false) -- released, or the action was cancelled
	end
	return Enum.ContextActionResult.Sink -- so Shift does not also toggle shift-lock
end

-- Clamber -------------------------------------------------------------------------------------------

local function characterParts()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

local function tryClamber()
	if not active or clambering or Grab.isHolding() or os.clock() - lastRequest < P.clamberCooldown then
		return
	end
	local humanoid, root = characterParts()
	if not humanoid or not root then
		return
	end
	local feet = humanoid.HipHeight + root.Size.Y / 2
	local direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if humanoid.MoveDirection.Magnitude > 0.1 then
		direction = humanoid.MoveDirection
	end

	-- The nearest climbable thing in front of us.
	local best, bestDistance = nil, math.huge
	for _, part in CollectionService:GetTagged("Climbable") do
		if part:IsA("BasePart") and part.Anchored and (part.Position - root.Position).Magnitude < 20 then
			local result = ClamberMath.evaluate(part, root.Position, feet, P)
			if result then
				local toward = Vector3.new(result.nearest.X - root.Position.X, 0, result.nearest.Z - root.Position.Z)
				local facing = toward.Magnitude < 1.2 or toward.Unit:Dot(direction.Unit) > 0.2
				if facing and result.distance < bestDistance then
					best, bestDistance = part, result.distance
				end
			end
		end
	end
	if best then
		lastRequest = os.clock()
		clamberEvent:FireServer(best)
	end
end

-- The server said yes: carry the character up and over to `target`.
local function playClamber(target: Vector3, duration: number)
	local humanoid, root = characterParts()
	if not humanoid or not root or clambering then
		return
	end
	clambering = true
	local start = root.Position
	local flat = Vector3.new(target.X - start.X, 0, target.Z - start.Z)
	local facing = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
	humanoid.PlatformStand = true

	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local u = math.min(elapsed / duration, 1)
		-- Up first (a quick pull), then forward onto the top.
		local up = 1 - (1 - math.min(u / 0.65, 1)) ^ 2
		local over = math.max(0, (u - 0.3) / 0.7)
		over = over * over * (3 - 2 * over)
		local position = Vector3.new(start.X + (target.X - start.X) * over, start.Y + (target.Y - start.Y) * up, start.Z + (target.Z - start.Z) * over)
		if not root.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			clambering = false
			return
		end
		root.CFrame = CFrame.lookAt(position, position + facing)
		root.AssemblyLinearVelocity = Vector3.zero
		if u >= 1 then
			connection:Disconnect()
			humanoid.PlatformStand = false
			root.AssemblyLinearVelocity = Vector3.zero
			clambering = false
		end
	end)
end

-- Turning it all on and off with the round ------------------------------------------------------

local function setActive(on: boolean)
	if on == active then
		return
	end
	active = on
	gui.Enabled = on
	if on then
		ContextActionService:BindActionAtPriority(ACTION, onSprint, true, Enum.ContextActionPriority.High.Value, P.runKey, Enum.KeyCode.ButtonL3)
		ContextActionService:SetTitle(ACTION, "RUN")
		refreshBar()
	else
		ContextActionService:UnbindAction(ACTION)
	end
end

function Parkour.handle(kind: string, data)
	if kind == "ClamberGo" then
		playClamber(data.target, data.duration)
	end
end

function Parkour.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	sprintEvent = remotes:WaitForChild("Sprint")
	clamberEvent = remotes:WaitForChild("Clamber")
	build()

	local function update()
		setActive(player:GetAttribute("Stamina") ~= nil)
		if active then
			refreshBar()
		end
	end
	player:GetAttributeChangedSignal("Stamina"):Connect(update)
	player:GetAttributeChangedSignal("Exhausted"):Connect(refreshBar)
	update()

	UserInputService.JumpRequest:Connect(tryClamber)
end

return Parkour
