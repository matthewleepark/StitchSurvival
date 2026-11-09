-- Hunt rounds, your side of it (Killer Hotel and Hide & Seek): your own role (the server only ever tells you
-- YOUR role), the "innocents / hiders left" count, and what you can throw:
--   * KILLER (Killer Hotel): click or tap anywhere to throw a bomb there (or the bomb key / BOMB button),
--     with a timer over each bomb you throw. Innocents never get a bomb timer: only the killer is sent it.
--   * HIDER (Hide & Seek): once you've picked up a piece of debris, click or tap anywhere to throw it there
--     (or the throw key / THROW button). One throw a round.
--   * SEEKER (Hide & Seek): your screen is covered while you count, and shows when you're stunned.
--
-- Effects handled here: Role {role = "killer" | "innocent" | "seeker" | "hider" | "none", seconds, bombs, max},
-- KillerBombs {count, max}, BombTimer {bomb, fuse}, Debris {state = "holding" | "used" | "none", name},
-- Blindfold {seconds}, HidePhase {seconds}, SeekerOut, Stunned {seconds}.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local Colors = Config.Colors
local FONT = Enum.Font.FredokaOne
local BOMB_ACTION = "DropBomb"
local THROW_ACTION = "ThrowDebris"
local KILLER_RED = Color3.fromRGB(196, 48, 48)
local INNOCENT_GREEN = Color3.fromRGB(88, 160, 96)
local HIDER_PURPLE = Color3.fromRGB(140, 90, 210)

-- What each role's banner and tag say.
local ROLES = {
	killer = {
		title = "YOU ARE THE KILLER",
		tag = "KILLER",
		color = KILLER_RED,
		dark = true,
		text = function()
			return `Click or tap anywhere to THROW a bomb there (or press {Config.KillerHotel.dropKey.Name}). Catch everyone before time runs out!`
		end,
	},
	innocent = {
		title = "YOU ARE AN INNOCENT",
		tag = "INNOCENT",
		color = INNOCENT_GREEN,
		text = function()
			return "Hide, run, and listen for ticking. Survive until the timer ends!"
		end,
	},
	seeker = {
		title = "YOU ARE THE SEEKER",
		tag = "SEEKER",
		color = KILLER_RED,
		dark = true,
		text = function()
			return "Count while everyone hides, then find them all! Search wardrobes, and watch out for flying junk."
		end,
	},
	hider = {
		title = "YOU ARE A HIDER",
		tag = "HIDER",
		color = HIDER_PURPLE,
		text = function()
			return `HIDE! Wardrobes, rooms, anywhere. Pick up one piece of junk and throw it at the seeker to stun them!`
		end,
	},
}

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
local cover: Frame -- the seeker's blindfold / stunned screen
local coverTitle: TextLabel
local coverCount: TextLabel
local hideBar: Frame -- the hiders' "HIDE!" countdown
local hideLabel: TextLabel
local bombCount = 0
local bombMax = 0
local debrisState = "none"
local dropBomb: RemoteEvent
local throwDebris: RemoteEvent
local countdownToken = 0

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
		ZIndex = 5,
	}, gui)
	new("UISizeConstraint", { MaxSize = Vector2.new(560, 150) }, banner)
	banner.Size = UDim2.new(0.92, 0, 0, 150)
	bannerTitle = label({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.04, 0.06),
		Size = UDim2.fromScale(0.92, 0.55),
		Font = FONT,
		TextScaled = true,
		Text = "",
		TextColor3 = Colors.Ink,
		ZIndex = 5,
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
		ZIndex = 5,
	}, banner)

	-- A small tag on the left that stays up for the round: your role, bombs or debris, who's left.
	-- (Just below the middle: clear of the health ribbon and the admin button above it, and of the menu below.)
	tag = paperBox({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 10),
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

	-- The seeker's covered screen (while counting, and while stunned).
	cover = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 6, 10),
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 3,
	}, gui)
	coverTitle = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.new(0.8, 0, 0, 60),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = Colors.Paper,
		Text = "",
		ZIndex = 4,
	}, cover)
	coverCount = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(240, 140),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = KILLER_RED,
		Text = "",
		ZIndex = 4,
	}, cover)
	new("UIStroke", { Thickness = 4, Color = Colors.Paper }, coverCount)

	-- The hiders' countdown bar along the top.
	hideBar = paperBox({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(420, 54),
		BackgroundColor3 = HIDER_PURPLE,
		Visible = false,
	}, gui)
	hideLabel = label({
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = FONT,
		TextScaled = true,
		TextColor3 = Colors.Paper,
		Text = "",
	}, hideBar)
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, hideLabel)
end

local function refreshTag()
	local info = ROLES[role]
	if not info then
		tag.Visible = false
		return
	end
	tag.Visible = true
	tagRole.Text = info.tag
	tagRole.TextColor3 = info.color
	local lines = {}
	if role == "killer" then
		table.insert(lines, `Bombs {bombCount}/{bombMax}`)
	elseif role == "hider" then
		table.insert(lines, if debrisState == "holding" then "Click to THROW!" elseif debrisState == "used" then "Throw used" else "Find junk to throw")
	end
	local left = ReplicatedStorage:GetAttribute("InnocentsLeft")
	if left ~= nil then
		local who = if role == "seeker" or role == "hider" then "Hiders" else "Innocents"
		table.insert(lines, `{who} left: {left}`)
	end
	tagInfo.Text = table.concat(lines, "  |  ")
	tag.Size = UDim2.fromOffset(if #lines > 1 then 300 else 220, 74)
end

-- Where on the map a point on the screen is looking at (your own body doesn't count).
local function aimAt(ray: Ray): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	return if hit then hit.Position else ray.Origin + ray.Direction * 200
end

-- Throw whatever you have (a bomb, or a piece of debris) toward where this screen ray points.
local function throwAt(ray: Ray)
	if not player.Character then
		return
	end
	if role == "killer" and bombCount > 0 then
		dropBomb:FireServer(aimAt(ray))
	elseif role == "hider" and debrisState == "holding" then
		throwDebris:FireServer(aimAt(ray))
	end
end

-- The bomb / throw key, gamepad button or on-screen button: at the mouse if there is one, else the middle.
local function throwFromKey()
	local camera = workspace.CurrentCamera
	local point = if UserInputService.MouseEnabled then UserInputService:GetMouseLocation() else camera.ViewportSize / 2
	throwAt(camera:ViewportPointToRay(point.X, point.Y))
end

local function onThrowAction(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		throwFromKey()
	end
	return Enum.ContextActionResult.Sink
end

local function refreshBindings()
	ContextActionService:UnbindAction(BOMB_ACTION)
	ContextActionService:UnbindAction(THROW_ACTION)
	if role == "killer" then
		ContextActionService:BindAction(BOMB_ACTION, onThrowAction, true, Config.KillerHotel.dropKey, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle(BOMB_ACTION, "BOMB")
	elseif role == "hider" and debrisState == "holding" then
		ContextActionService:BindAction(THROW_ACTION, onThrowAction, true, Config.HideAndSeek.throwKey, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle(THROW_ACTION, "THROW")
	end
end

local function showBanner(title: string, sub: string, color: Color3, dark: boolean, seconds: number)
	banner.BackgroundColor3 = if dark then color else Colors.Paper
	bannerTitle.Text = title
	bannerTitle.TextColor3 = if dark then Colors.Paper else color
	bannerSub.Text = sub
	bannerSub.TextColor3 = if dark then Colors.Paper else Colors.Ink
	banner.Visible = true
	banner.Position = UDim2.fromScale(0.5, 0.22)
	TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.3) }):Play()
	local shownTitle = title
	task.delay(seconds, function()
		if bannerTitle.Text == shownTitle and banner.Visible then
			banner.Visible = false
		end
	end)
end

local function showRoleBanner(seconds: number)
	local info = ROLES[role]
	if info then
		showBanner(info.title, info.text(), info.color, info.dark == true, seconds)
	end
end

-- Counts down `seconds` on a label, then calls done (unless a newer countdown took over).
local function countdown(seconds: number, onTick: (number) -> (), done: () -> ())
	countdownToken += 1
	local token = countdownToken
	task.spawn(function()
		local endsAt = os.clock() + seconds
		while countdownToken == token do
			local left = math.ceil(endsAt - os.clock())
			if left <= 0 then
				break
			end
			onTick(left)
			task.wait(0.1)
		end
		if countdownToken == token then
			done()
		end
	end)
end

local function hideOverlays()
	countdownToken += 1
	cover.Visible = false
	hideBar.Visible = false
end

-- A countdown over a bomb you threw. Only the killer ever receives this.
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

local function setRole(newRole: string)
	role = newRole
	if role == "none" then
		banner.Visible = false
		debrisState = "none"
		hideOverlays()
	end
	refreshBindings()
	refreshTag()
end

function Roles.handle(kind: string, data)
	if kind == "Role" then
		bombCount = data.bombs or 0
		bombMax = data.max or 0
		if data.role ~= "none" then
			debrisState = "none"
		end
		setRole(data.role)
		if role ~= "none" then
			showRoleBanner(data.seconds or 5)
		end
	elseif kind == "KillerBombs" then
		bombCount = data.count
		bombMax = data.max
		refreshTag()
	elseif kind == "BombTimer" then
		if role == "killer" then
			showBombTimer(data.bomb, data.fuse)
		end
	elseif kind == "Debris" then
		debrisState = data.state
		refreshBindings()
		refreshTag()
		if data.state == "holding" then
			local how = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
				then "Tap where to throw it"
				else `Click where to throw it (or press {Config.HideAndSeek.throwKey.Name})`
			showBanner(`GOT A {string.upper(data.name or "PIECE")}!`, `{how}. Hit the seeker to stun them!`, HIDER_PURPLE, true, 3)
		end
	elseif kind == "Blindfold" then
		-- You're the seeker: eyes covered while everyone hides.
		cover.Visible = true
		cover.BackgroundTransparency = 0
		coverTitle.Text = "Cover your eyes and count! Everyone is hiding..."
		countdown(data.seconds, function(left)
			coverCount.Text = tostring(left)
		end, function()
			cover.Visible = false
		end)
	elseif kind == "HidePhase" then
		hideBar.Visible = true
		countdown(data.seconds, function(left)
			hideLabel.Text = `\u{1F648} HIDE! The seeker comes out in {left}`
		end, function()
			hideBar.Visible = false
		end)
	elseif kind == "SeekerOut" then
		hideOverlays()
		if role == "seeker" then
			showBanner("GO FIND THEM!", "Get close to a hider to catch them. Search the wardrobes!", KILLER_RED, true, 3)
		elseif role == "hider" then
			showBanner("READY OR NOT...", "Here comes the seeker! Look for the red glow.", KILLER_RED, true, 3)
		end
	elseif kind == "Stunned" then
		cover.Visible = true
		cover.BackgroundTransparency = 0.45
		coverTitle.Text = "\u{1F4AB} STUNNED! \u{1F4AB}"
		countdown(data.seconds, function(left)
			coverCount.Text = tostring(left)
		end, function()
			cover.Visible = false
		end)
	end
end

function Roles.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	dropBomb = remotes:WaitForChild("DropBomb")
	throwDebris = remotes:WaitForChild("ThrowDebris")
	build()
	-- Killer or hider with something to throw: click anywhere (not on a button) to throw it at that spot...
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			local point = UserInputService:GetMouseLocation()
			throwAt(workspace.CurrentCamera:ViewportPointToRay(point.X, point.Y))
		end
	end)
	-- ...or tap anywhere on a phone or tablet (taps, not camera drags).
	UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
		if not processedByUI then
			throwAt(workspace.CurrentCamera:ScreenPointToRay(position.X, position.Y))
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal("InnocentsLeft"):Connect(refreshTag)
	-- If the round ends some other way (an admin ends it, the level is torn down), drop the role too.
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = ReplicatedStorage:GetAttribute("Phase")
		if role ~= "none" and (phase == "Intermission" or phase == "Loading") then
			setRole("none")
		end
	end)
	-- Popped: no more throwing, and nothing left covering the screen.
	player.CharacterAdded:Connect(function()
		if debrisState == "holding" then
			debrisState = "none"
			refreshBindings()
			refreshTag()
		end
		hideOverlays()
	end)
end

return Roles
