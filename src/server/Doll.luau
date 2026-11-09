-- Turns every character into a cute stitched plush doll, about 3 studs tall: a burlap felt body with
-- white seams, buttons, a knee patch and a zipper in their player color. The head stays the player's
-- own (face, skin, hair and hats), just a little bigger for cute proportions.
-- When a doll is popped it goes completely floppy: every joint turns into a loose ball-and-socket
-- so the arms, legs and head tumble around (a ragdoll) instead of falling off.
--
-- LOOK: players can keep their own Roblox avatar instead (the LOOK button; the "Look" attribute is
-- "doll" or "avatar", saved with their progress). Switching in the lobby respawns them right away; during
-- a round the new look waits until they next respawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)

local Doll = {}

local lastSwitch: { [Player]: number } = {}

local function attach(part: BasePart, to: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
	part.Parent = to
end

-- Swap every motor joint for a loose ball-and-socket joint.
local function ragdoll(character: Model)
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			local a0 = Instance.new("Attachment")
			a0.CFrame = joint.C0
			a0.Parent = joint.Part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = joint.C1
			a1.Parent = joint.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			socket.UpperAngle = 70
			socket.Parent = joint.Parent
			joint.Enabled = false
		end
	end
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = true
		end
	end
end

local function setUpCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid or not Config.Doll.Ragdoll then
		return
	end
	humanoid.BreakJointsOnDeath = false
	humanoid.Died:Connect(function()
		ragdoll(character)
	end)
end

-- A short row of white "thread" dashes down one side of a body part.
local function seam(part: BasePart, side: number)
	local dashes = 3
	for i = 1, dashes do
		local y = -part.Size.Y / 2 + part.Size.Y * (i - 0.5) / dashes
		local dash = Instance.new("Part")
		dash.Name = "Stitch"
		dash.Size = Vector3.new(0.05, part.Size.Y / (dashes * 2), 0.07)
		dash.CFrame = part.CFrame * CFrame.new(side * (part.Size.X / 2 + 0.02), y, 0)
		dash.Material = Enum.Material.Fabric
		dash.Color = Config.Colors.Paper
		attach(dash, part)
	end
end

local function decoration(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, to: BasePart, round: boolean?)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	if round then
		part.Shape = Enum.PartType.Cylinder
	end
	attach(part, to)
	return part
end

-- Cute proportions: normal height, a slightly bigger head and a chubbier body.
local function cuteProportions(humanoid: Humanoid)
	local scales = { HeadScale = 1.2, BodyWidthScale = 1.05, BodyDepthScale = 1.05 } -- normal height, a slightly bigger head
	for name, value in scales do
		local scale = humanoid:FindFirstChild(name)
		if scale and scale:IsA("NumberValue") then
			scale.Value = value
		end
	end
end

local function dress(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if player:GetAttribute("Look") == "avatar" then
		-- Their own avatar, as it is; just the same movement as everyone else.
		character:SetAttribute("DressedAs", "avatar")
		if humanoid then
			humanoid.UseJumpPower = false
			humanoid.JumpHeight = Config.Doll.JumpHeight
			humanoid.WalkSpeed = Config.Doll.WalkSpeed
		end
		return
	end
	character:SetAttribute("DressedAs", "doll")
	if humanoid then
		cuteProportions(humanoid)
	end

	-- Shrink to sack-doll size, so everything below is sized to the small body.
	if Config.Doll.Scale ~= 1 then
		character:ScaleTo(Config.Doll.Scale)
	end

	-- Set after scaling so nothing rescales them: normal-feeling movement for a doll this size.
	if humanoid then
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = Config.Doll.JumpHeight
		humanoid.WalkSpeed = Config.Doll.WalkSpeed
	end

	-- Clothes come off so the plush body shows. Hats, hair and the face stay: the head is still you.
	if Config.Doll.RemoveClothing then
		for _, item in character:GetChildren() do
			if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
				item:Destroy()
			end
		end
	end

	-- Soft burlap felt body; the head keeps your own skin color.
	local felt = Config.Colors.Burlap
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.TorsoColor3 = felt
		bodyColors.LeftArmColor3 = felt
		bodyColors.RightArmColor3 = felt
		bodyColors.LeftLegColor3 = felt
		bodyColors.RightLegColor3 = felt
	end
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "Head" then
			part.Material = Enum.Material.Fabric
			part.Color = felt
		end
	end

	-- Stitched seams down the outside of the arms and legs, and both sides of the torso.
	for _, name in { "LeftUpperArm", "LeftLowerArm", "LeftUpperLeg", "LeftLowerLeg" } do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			seam(part, -1)
		end
	end
	for _, name in { "RightUpperArm", "RightLowerArm", "RightUpperLeg", "RightLowerLeg" } do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			seam(part, 1)
		end
	end

	local color = player:GetAttribute("Color") or Config.Colors.Gold
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		seam(torso, -1)
		seam(torso, 1)
		local front = torso.CFrame * CFrame.new(0, 0, -torso.Size.Z / 2 - 0.04)

		-- Zipper down the middle in your player color.
		decoration("Zipper", Vector3.new(0.22, torso.Size.Y * 0.85, 0.08), front, color, Enum.Material.Metal, torso)
		decoration("ZipperPull", Vector3.new(0.35, 0.45, 0.1), front * CFrame.new(0, torso.Size.Y * 0.3, -0.06), Config.Colors.Gold, Enum.Material.Metal, torso)

		-- Two big round buttons beside it.
		for i, y in { 0.15, -0.2 } do
			local spot = front * CFrame.new(torso.Size.X * 0.25, torso.Size.Y * y, -0.03) * CFrame.Angles(0, math.rad(90), 0)
			decoration(`Button{i}`, Vector3.new(0.08, 0.32, 0.32), spot, Config.Colors.WoodDark, Enum.Material.SmoothPlastic, torso, true)
		end
	end

	-- A little flashlight strapped to the right shoulder, pointing forward. Everyone can see it; your own
	-- beam shines out of its lens (client/Flashlight.luau looks for "ShoulderLampLens").
	if torso and torso:IsA("BasePart") then
		local mount = torso.CFrame * CFrame.new(torso.Size.X / 2 - 0.15, torso.Size.Y / 2 + 0.2, -0.1)
		decoration("ShoulderLampStrap", Vector3.new(0.5, 0.12, torso.Size.Z + 0.1), mount * CFrame.new(0, -0.15, 0.1), Config.Colors.Ink, Enum.Material.Fabric, torso)
		local body = mount * CFrame.Angles(0, math.rad(90), 0) -- cylinder's long side points forward
		decoration("ShoulderLamp", Vector3.new(0.7, 0.32, 0.32), body, Color3.fromRGB(60, 60, 66), Enum.Material.Metal, torso, true)
		local lens = decoration("ShoulderLampLens", Vector3.new(0.06, 0.36, 0.36), body * CFrame.new(0.37, 0, 0), Color3.fromRGB(255, 238, 205), Enum.Material.Neon, torso, true)
		lens.CastShadow = false
	end

	-- A felt patch on one knee, sewn on with a cross stitch.
	local leg = character:FindFirstChild("LeftLowerLeg")
	if leg and leg:IsA("BasePart") then
		local patchSpot = leg.CFrame * CFrame.new(0, leg.Size.Y * 0.2, -leg.Size.Z / 2 - 0.03)
		decoration("Patch", Vector3.new(leg.Size.X * 0.7, leg.Size.X * 0.7, 0.05), patchSpot, color, Enum.Material.Fabric, leg)
		for _, angle in { 45, -45 } do
			decoration("CrossStitch", Vector3.new(0.04, leg.Size.X * 0.5, 0.06), patchSpot * CFrame.new(0, 0, -0.03) * CFrame.Angles(0, 0, math.rad(angle)), Config.Colors.Paper, Enum.Material.Fabric, leg)
		end
	end
end

function Doll.start()
	if not Config.Doll.Enabled then
		return
	end
	local function watch(player: Player)
		player.CharacterAdded:Connect(setUpCharacter)
		if player.Character then
			task.spawn(setUpCharacter, player.Character)
		end
		player.CharacterAppearanceLoaded:Connect(function(character)
			dress(player, character)
		end)
		-- The look changed (the LOOK button, or their save just loaded): show it now if they're in the lobby.
		player:GetAttributeChangedSignal("Look"):Connect(function()
			local character = player.Character
			local dressedAs = character and character:GetAttribute("DressedAs")
			if dressedAs and dressedAs ~= player:GetAttribute("Look") and not player:GetAttribute("InRound") then
				player:LoadCharacterAsync()
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	Remotes.SetLook.OnServerEvent:Connect(function(player: Player, look: any)
		if look ~= "doll" and look ~= "avatar" then
			return
		end
		local now = os.clock()
		if lastSwitch[player] and now - lastSwitch[player] < 3 then
			return
		end
		lastSwitch[player] = now
		player:SetAttribute("Look", look)
		if player:GetAttribute("InRound") then
			Remotes.fire(player, "Announce", { text = "Your new look shows up after this round!", color = Config.Colors.Gold })
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSwitch[player] = nil
	end)
end

return Doll
