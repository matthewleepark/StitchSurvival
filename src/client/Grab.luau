-- Hold E (R1 on a gamepad, or the Grab button on mobile) to grab whatever is in front of you:
-- walls, crates, foam blocks. You stick to it with a duct-tape "thwack", hang on while the yarn
-- creaks, and let go with a rubber-band flick. Pressing jump while hanging launches you off.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Audio = require(script.Parent.Audio)

local player = Players.LocalPlayer

local Grab = {}

local weld: WeldConstraint? = nil
local creak: Sound? = nil
local watchTarget: RBXScriptConnection? = nil

local function findTarget(character: Model, root: BasePart): BasePart?
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local best, bestDistance = nil, math.huge
	local reach = root.CFrame * CFrame.new(0, 0.5, -1.8)
	for _, part in workspace:GetPartBoundsInBox(reach, Vector3.new(3.5, 5, 3), params) do
		local isCharacter = part:FindFirstAncestorOfClass("Model") and part:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid")
		if part.CanCollide and part.Name ~= "Boundary" and not part:IsA("Terrain") and not isCharacter then
			local distance = (part.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = part, distance
			end
		end
	end
	return best
end

local function release(launch: boolean?)
	if not weld then
		return
	end
	weld:Destroy()
	weld = nil
	if watchTarget then
		watchTarget:Disconnect()
		watchTarget = nil
	end
	if creak then
		creak:Stop()
		creak:Destroy()
		creak = nil
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		Audio.play("GrabRelease", root)
		if launch then
			root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 50, 0)
		end
	end
end

local function grab()
	if weld then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or humanoid.Health <= 0 or not root or root.Anchored then
		return
	end

	local target = findTarget(character, root)
	if not target then
		return
	end

	local constraint = Instance.new("WeldConstraint")
	constraint.Name = "GrabWeld"
	constraint.Part0 = root
	constraint.Part1 = target
	constraint.Parent = root
	weld = constraint

	Audio.play("GrabTack", root)
	local sound = Audio.create("GrabCreak")
	if sound then
		sound.Looped = true
		sound.Parent = root
		sound:Play()
		creak = sound
	end

	-- Let go automatically if what we're holding gets blown up or removed.
	watchTarget = target.AncestryChanged:Connect(function(_, parent)
		if not parent then
			release()
		end
	end)
end

function Grab.start()
	ContextActionService:BindAction("Grab", function(_, state)
		if state == Enum.UserInputState.Begin then
			grab()
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			release()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonR1)
	ContextActionService:SetTitle("Grab", "Grab")

	UserInputService.JumpRequest:Connect(function()
		if weld then
			release(true)
		end
	end)

	player.CharacterAdded:Connect(function(character)
		release()
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			release()
		end)
	end)
end

return Grab
