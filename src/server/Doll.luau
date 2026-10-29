-- Turns every character into a little knitted burlap doll, about 3 studs tall, with a zipper in
-- their player color. Hats and accessories stay on, like costumes.
-- When a doll is popped it goes completely floppy: every joint turns into a loose ball-and-socket
-- so the arms, legs and head tumble around (a ragdoll) instead of falling off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Doll = {}

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

local function dress(player: Player, character: Model)
	-- Shrink to sack-doll size first, so the zipper is sized to the small torso.
	if Config.Doll.Scale ~= 1 then
		character:ScaleTo(Config.Doll.Scale)
	end

	if Config.Doll.RemoveClothing then
		for _, item in character:GetChildren() do
			if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
				item:Destroy()
			end
		end
	end

	local burlap = Config.Colors.Burlap
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.HeadColor3 = burlap
		bodyColors.TorsoColor3 = burlap
		bodyColors.LeftArmColor3 = burlap
		bodyColors.RightArmColor3 = burlap
		bodyColors.LeftLegColor3 = burlap
		bodyColors.RightLegColor3 = burlap
	end

	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Material = Enum.Material.Fabric
			part.Color = burlap
		end
	end

	-- Zipper down the front of the torso.
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		local color = player:GetAttribute("Color") or Config.Colors.Gold
		local front = torso.CFrame * CFrame.new(0, 0, -torso.Size.Z / 2 - 0.04)

		local zipper = Instance.new("Part")
		zipper.Name = "Zipper"
		zipper.Size = Vector3.new(0.22, torso.Size.Y * 0.85, 0.08)
		zipper.CFrame = front
		zipper.Material = Enum.Material.Metal
		zipper.Color = color
		attach(zipper, torso)

		local pull = Instance.new("Part")
		pull.Name = "ZipperPull"
		pull.Size = Vector3.new(0.35, 0.45, 0.1)
		pull.CFrame = front * CFrame.new(0, torso.Size.Y * 0.3, -0.06)
		pull.Material = Enum.Material.Metal
		pull.Color = Config.Colors.Gold
		attach(pull, torso)
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
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Doll
