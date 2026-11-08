-- Killer Hotel, your side of it: your own role (the server only ever tells you YOUR role), the
-- "innocents left" count, and, if you are the killer, throwing bombs (click or tap anywhere, or the bomb
-- key / BOMB button) and a timer over each bomb you throw.
-- Innocents never get a bomb timer: the server only sends "BombTimer" to the killer.
--
-- Effects handled here: Role {role = "killer" | "innocent" | "none", seconds, bombs, max},
-- KillerBombs {count, max}, BombTimer {bomb, fuse}.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local Colors = Config.Colors
local FONT = Enum.Font.FredokaOne
local ACTION = "DropBomb"
local KILLER_RED = Color3.fromRGB(196, 48, 48)
local INNOCENT_GREEN = Color3.fromRGB(88, 160, 96)

local Roles = {}

local player = Players.LocalPlayer
local role = "none"
local gui: ScreenGui
local banner: Frame
local bannerTitle: TextLabel
local bannerSub: TextLabel
local tag: Frame
local tagRole: TextLabel
local tagInfo: TextLabel
local bombCount = 0
local bombMax = 0
local dropBomb: RemoteEvent

local function new(className: string, props, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function paperBox(props, parent: Instance): Frame
	local frame = new("Frame", props, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, frame)
	new("UIStroke", { Thickness = 3, Color = Colors.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	return frame
end

local function label(props, parent: Instance): TextLabel
	return new("TextLabel", table.clone(props), parent)
end

local function build()
	gui = new("ScreenGui", { Name = "Roles", ResetOnSpawn = false, DisplayOrder = 40, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))

	-- The big "you are ..." banner.
	banner = paperBox({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(560, 150),
		BackgroundColor3 = Colors.Paper,
		Visible = false,
	}, gui)
	bannerTitle = label({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.04, 0.06),
		Size = UDim2.fromScale(0.92, 0.55),
		Font = FONT,
		TextScaled = true,
		Text = "",
		TextColor3 = Colors.Ink,
	}, banner)
	bannerSub = label({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.04, 0.62),
		Size = UDim2.fromScale(0.92, 0.3),
		Font = FONT,
		TextScaled = true,
		TextWrapped = true,
		Text = "",
		TextColor3 = Colors.Ink,
	}, banner)

	-- A small tag on the left that stays up for the round: your role, bombs, innocents left.
	tag = paperBox({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, -70),
		Size = UDim2.fromOffset(190, 74),
		BackgroundColor3 = Colors.Paper,
		Visible = false,
	}, gui)
	tagRole = label({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 34),
		Font = FONT,
		TextSize = 28,
		Text = "",
		TextColor3 = Colors.Ink,
	}, tag)
	tagInfo = label({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 38),
		Size = UDim2.new(1, -16, 0, 30),
		Font = FONT,
		TextSize = 18,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Ink,
	}, tag)
end

local function refreshTag()
	if role == "none" then
		tag.Visible = false
		return
	end
	tag.Visible = true
	local left = ReplicatedStorage:GetAttribute("InnocentsLeft")
	local lines = {}
	if role == "killer" then
		tagRole.Text = "KILLER"
		tagRole.TextColor3 = KILLER_RED
		table.insert(lines, `Bombs {bombCount}/{bombMax}`)
	else
		tagRole.Text = "INNOCENT"
		tagRole.TextColor3 = INNOCENT_GREEN
	end
	if left ~= nil then
		table.insert(lines, `Innocents left: {left}`)
	end
	tagInfo.Text = table.concat(lines, "  |  ")
	tag.Size = UDim2.fromOffset(if role == "killer" and left ~= nil then 290 else 220, 74)
end

local function keyName(): string
	return Config.KillerHotel.dropKey.Name
end

-- Where on the map a point on the screen is looking at (your own body doesn't count). The server
-- throws the bomb toward it.
local function aimAt(ray: Ray): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	return if hit then hit.Position else ray.Origin + ray.Direction * 200
end

local function throwBomb(ray: Ray)
	if role == "killer" and bombCount > 0 and player.Character then
		dropBomb:FireServer(aimAt(ray))
	end
end

-- The bomb key / gamepad / BOMB button: at the mouse if there is one, otherwise the middle of the screen.
local function throwFromKey()
	local camera = workspace.CurrentCamera
	local point = if UserInputService.MouseEnabled
		then UserInputService:GetMouseLocation()
		else camera.ViewportSize / 2
	throwBomb(camera:ViewportPointToRay(point.X, point.Y))
end

local function unbindBomb()
	ContextActionService:UnbindAction(ACTION)
end

local function bindBomb()
	ContextActionService:BindAction(ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			throwFromKey()
		end
		return Enum.ContextActionResult.Sink
	end, true, Config.KillerHotel.dropKey, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle(ACTION, "BOMB")
end

local function showBanner(seconds: number)
	local killer = role == "killer"
	banner.BackgroundColor3 = if killer then KILLER_RED else Colors.Paper
	bannerTitle.Text = if killer then "YOU ARE THE KILLER" else "YOU ARE AN INNOCENT"
	bannerTitle.TextColor3 = if killer then Colors.Paper else INNOCENT_GREEN
	bannerSub.Text = if killer
		then `Click or tap anywhere to THROW a bomb there (or press {keyName()}). Catch everyone before time runs out!`
		else "Hide, run, and listen for ticking. Survive until the timer ends!"
	bannerSub.TextColor3 = if killer then Colors.Paper else Colors.Ink
	banner.Visible = true
	banner.Position = UDim2.fromScale(0.5, 0.22)
	TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.3) }):Play()
	local shown = banner
	task.delay(seconds, function()
		if shown == banner and banner.Visible then
			banner.Visible = false
		end
	end)
end

-- A countdown over a bomb you dropped. Only the killer ever receives this.
local function showBombTimer(bomb: BasePart?, fuse: number)
	if not bomb or not bomb.Parent then
		return
	end
	local billboard = new("BillboardGui", {
		Size = UDim2.fromOffset(80, 50),
		StudsOffset = Vector3.new(0, 4, 0),
		AlwaysOnTop = true,
	}, bomb)
	local number = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = FONT,
		TextSize = 40,
		TextColor3 = Colors.Paper,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = KILLER_RED,
	}, billboard)
	local endsAt = os.clock() + fuse
	task.spawn(function()
		while billboard.Parent do
			number.Text = tostring(math.max(0, math.ceil(endsAt - os.clock())))
			task.wait(0.1)
		end
	end)
end

function Roles.handle(kind: string, data)
	if kind == "Role" then
		role = data.role
		if role == "none" then
			banner.Visible = false
			unbindBomb()
		else
			bombCount = data.bombs or 0
			bombMax = data.max or 0
			showBanner(data.seconds or 5)
			if role == "killer" then
				bindBomb()
			else
				unbindBomb()
			end
		end
		refreshTag()
	elseif kind == "KillerBombs" then
		bombCount = data.count
		bombMax = data.max
		refreshTag()
	elseif kind == "BombTimer" then
		if role == "killer" then
			showBombTimer(data.bomb, data.fuse)
		end
	end
end

function Roles.start()
	dropBomb = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DropBomb")
	build()
	-- Killer: click anywhere (not on a button) to throw a bomb at that spot...
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			local point = UserInputService:GetMouseLocation()
			throwBomb(workspace.CurrentCamera:ViewportPointToRay(point.X, point.Y))
		end
	end)
	-- ...or tap anywhere on a phone or tablet (taps, not camera drags).
	UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
		if not processedByUI then
			throwBomb(workspace.CurrentCamera:ScreenPointToRay(position.X, position.Y))
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal("InnocentsLeft"):Connect(refreshTag)
	-- If the round ends some other way (an admin ends it, the level is torn down), drop the role too.
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = ReplicatedStorage:GetAttribute("Phase")
		if role ~= "none" and (phase == "Intermission" or phase == "Loading") then
			role = "none"
			banner.Visible = false
			unbindBomb()
			refreshTag()
		end
	end)
end

return Roles
