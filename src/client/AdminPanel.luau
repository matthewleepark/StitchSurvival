-- Admin panel for testing. Only shows up for players in Config.Admins (the server decides,
-- and checks every command again on its side). Open it with the ADMIN button or F2.
--
-- Flying and speed run here on the client (your own character's movement is yours to control);
-- everything else is sent to the server's Admin module.
--
-- Flying: W A S D moves where the camera is looking, Space goes up, Left Shift or Q goes down.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local TitleScreen = require(script.Parent.TitleScreen)

local Colors = Config.Colors
local FONT = Enum.Font.FredokaOne
local player = Players.LocalPlayer

local AdminPanel = {}

local FLY_SPEED = 60
local SPEEDS = { 16, 32, 64 }

local remote: RemoteEvent

local function send(command: string, argument: any?)
	remote:FireServer(command, argument)
end

-- Flying --------------------------------------------------------------------------------------

local flying = false
local flyParts: { Instance } = {}
local flyConnection: RBXScriptConnection? = nil

local function stopFlying()
	flying = false
	if flyConnection then
		flyConnection:Disconnect()
		flyConnection = nil
	end
	for _, instance in flyParts do
		instance:Destroy()
	end
	table.clear(flyParts)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end
end

local function startFlying()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end
	flying = true
	humanoid.PlatformStand = true

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root
	local upright = Instance.new("AlignOrientation")
	upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	upright.Attachment0 = attachment
	upright.MaxTorque = math.huge
	upright.Responsiveness = 30
	upright.Parent = root
	flyParts = { attachment, velocity, upright }

	flyConnection = RunService.RenderStepped:Connect(function()
		if not root.Parent then
			stopFlying()
			return
		end
		local camera = workspace.CurrentCamera.CFrame
		local direction = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			direction += camera.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			direction -= camera.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			direction += camera.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			direction -= camera.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			direction += Vector3.yAxis
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
			direction -= Vector3.yAxis
		end
		velocity.VectorVelocity = if direction.Magnitude > 0 then direction.Unit * FLY_SPEED else Vector3.zero

		-- Stay upright, facing where the camera faces.
		local flatLook = Vector3.new(camera.LookVector.X, 0, camera.LookVector.Z)
		if flatLook.Magnitude > 0.01 then
			upright.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
		end
	end)
end

-- UI -----------------------------------------------------------------------------------------

local function new(className: string, props, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function build()
	remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminCommand") :: RemoteEvent

	local gui = new("ScreenGui", { Name = "AdminPanel", ResetOnSpawn = false, DisplayOrder = 20 }, player:WaitForChild("PlayerGui"))

	-- On phones the spot under the health ribbon belongs to the passive tag and the menu, so the admin
	-- button sits to the right of the score card instead.
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local toggle = new("TextButton", {
		Position = if touch then UDim2.fromOffset(226, 16) else UDim2.fromOffset(16, 140),
		Size = UDim2.fromOffset(90, 30),
		BackgroundColor3 = Colors.Ink,
		Font = FONT,
		TextSize = 16,
		TextColor3 = Colors.Gold,
		Text = "ADMIN (F2)",
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, toggle)
	TitleScreen.wireButton(toggle)

	local panel = new("Frame", {
		Position = if touch then UDim2.fromOffset(226, 52) else UDim2.fromOffset(16, 178),
		-- Stops above the menu buttons in the bottom-left corner (it scrolls, so it can be short).
		Size = if touch then UDim2.fromOffset(250, 280) else UDim2.new(0, 250, 1, -(178 + 190)),
		BackgroundColor3 = Colors.Paper,
		Visible = false,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)
	new("UIStroke", { Thickness = 3, Color = Colors.Ink }, panel)
	new("UISizeConstraint", { MinSize = Vector2.new(250, 150), MaxSize = Vector2.new(250, 420) }, panel)

	local list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -16),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, panel)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local order = 0
	local function heading(text: string)
		order += 1
		new("TextLabel", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Font = FONT,
			TextSize = 16,
			TextColor3 = Colors.Felt,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = text,
		}, list)
	end
	local function button(text: string, onClick: (TextButton) -> ()): TextButton
		order += 1
		local b = new("TextButton", {
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 30),
			BackgroundColor3 = Colors.Cardboard,
			Font = FONT,
			TextSize = 15,
			TextColor3 = Colors.Ink,
			Text = text,
			AutoButtonColor = false,
		}, list)
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
		new("UIStroke", { Thickness = 1.5, Color = Colors.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		TitleScreen.wireButton(b)
		b.Activated:Connect(function()
			onClick(b)
		end)
		return b
	end

	heading("ROUND")
	button("Start now: random level", function()
		send("StartRound", "Random")
	end)
	for _, def in Config.Levels do
		button(`Start now: {def.title}`, function()
			send("StartRound", def.name)
		end)
	end
	button("Start now: Bomb Hotel CHAOS", function()
		send("StartRound", "BombHotelChaos")
	end)
	button("End this round", function()
		send("EndRound")
	end)

	heading("ME")
	local god = false
	button("God mode: OFF", function(b)
		god = not god
		b.Text = if god then "God mode: ON" else "God mode: OFF"
		b.BackgroundColor3 = if god then Colors.Gold else Colors.Cardboard
		send("God", god)
	end)
	button("Fly: OFF", function(b)
		if flying then
			stopFlying()
		else
			startFlying()
		end
		b.Text = if flying then "Fly: ON (Space up, Shift down)" else "Fly: OFF"
		b.BackgroundColor3 = if flying then Colors.Gold else Colors.Cardboard
	end)
	local speedIndex = 1
	button("Speed: 16", function(b)
		speedIndex = speedIndex % #SPEEDS + 1
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = SPEEDS[speedIndex]
		end
		b.Text = `Speed: {SPEEDS[speedIndex]}`
	end)
	button("Heal", function()
		send("Heal")
	end)
	button("Respawn", function()
		stopFlying()
		send("Respawn")
	end)

	heading("GO TO")
	button("The Pod", function()
		send("Teleport", "Pod")
	end)
	for _, def in Config.Levels do
		button(def.title, function()
			send("Teleport", def.name)
		end)
	end

	heading("TEST STUFF")
	button("Drop a bomb on me", function()
		send("DropBomb")
	end)
	button("Score bubbles around me", function()
		send("Bubbles")
	end)
	button("+100 Stickers", function()
		send("Stickers")
	end)
	button("Send in a shark (Bomb Hotel)", function()
		send("SpawnShark")
	end)

	-- Moderation: type a name (and a reason), then press a button. Bans last on every server.
	heading("PLAYERS")
	local function box(placeholder: string): TextBox
		order += 1
		local input = new("TextBox", {
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 30),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Font = FONT,
			TextSize = 15,
			TextColor3 = Colors.Ink,
			PlaceholderText = placeholder,
			Text = "",
			ClearTextOnFocus = false,
		}, list)
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, input)
		new("UIStroke", { Thickness = 1.5, Color = Colors.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, input)
		return input
	end
	local whoBox = box("Player name")
	local reasonBox = box("Reason (optional)")
	local function moderate(command: string)
		send(command, { target = whoBox.Text, reason = reasonBox.Text })
	end
	local kick = button("Kick", function()
		moderate("Kick")
	end)
	kick.BackgroundColor3 = Color3.fromRGB(230, 170, 90)
	-- Ban asks twice, so a stray tap can't ban anyone.
	local armed = false
	local ban
	ban = button("Ban (every server)", function()
		if not armed then
			armed = true
			ban.Text = "Tap again to BAN"
			task.delay(3, function()
				armed = false
				ban.Text = "Ban (every server)"
			end)
			return
		end
		armed = false
		ban.Text = "Ban (every server)"
		moderate("Ban")
	end)
	ban.BackgroundColor3 = Color3.fromRGB(220, 90, 80)
	button("Unban (exact username)", function()
		moderate("Unban")
	end)

	-- Passives: type a player's name to give to them, or leave it blank for yourself.
	heading("PASSIVES")
	order += 1
	local targetBox = new("TextBox", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 30),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = FONT,
		TextSize = 15,
		TextColor3 = Colors.Ink,
		PlaceholderText = "Give to: me (or type a player's name)",
		Text = "",
		ClearTextOnFocus = false,
	}, list)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, targetBox)
	new("UIStroke", { Thickness = 1.5, Color = Colors.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, targetBox)
	local function target(): string
		return targetBox.Text
	end
	button("Give ALL passives", function()
		send("GiveAllPassives", { target = target() })
	end)
	for _, passive in Config.Gear do
		local b = button(`Give {passive.icon} {passive.name} ({passive.rarity})`, function()
			send("GivePassive", { passive = passive.name, target = target() })
		end)
		b.TextColor3 = Config.RarityColors[passive.rarity]
		b.BackgroundColor3 = Color3.fromRGB(70, 56, 46)
	end
	button("Take passive away", function()
		send("RemovePassive", { target = target() })
	end)

	local function flip()
		panel.Visible = not panel.Visible
	end
	toggle.Activated:Connect(flip)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F2 then
			flip()
		end
	end)

	-- Flying ends when you respawn.
	player.CharacterAdded:Connect(function()
		stopFlying()
	end)
end

function AdminPanel.start()
	if player:GetAttribute("IsAdmin") then
		build()
		return
	end
	local connection
	connection = player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
		if player:GetAttribute("IsAdmin") then
			connection:Disconnect()
			build()
		end
	end)
end

return AdminPanel
