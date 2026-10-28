-- Side-on camera like LBP: looks straight at the diorama, follows you smoothly,
-- and never shows past the edges of the stage.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Stages = require(script.Parent.Stages)

local FIELD_OF_VIEW = 40
local MAX_VISIBLE_WIDTH = 80 -- wider stages scroll instead of zooming out, so dolls stay readable
local FOLLOW_SPEED = 5

local StageCamera = {}

local shakeAmount = 0

function StageCamera.shake(amount: number)
	shakeAmount = math.max(shakeAmount, amount)
end

function StageCamera.start()
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local stage: Stages.Stage? = nil
	local focus: Vector3? = nil

	RunService:BindToRenderStep("StageCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			stage = Stages.find(root.Position) or stage
		end
		if not stage then
			return
		end

		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = FIELD_OF_VIEW

		-- Pull back far enough to fit the stage's width (up to a limit).
		local viewport = camera.ViewportSize
		local aspect = viewport.X / math.max(viewport.Y, 1)
		local halfVertical = math.rad(FIELD_OF_VIEW) / 2
		local halfHorizontal = math.atan(math.tan(halfVertical) * aspect)
		local visibleWidth = math.min(stage.width + 8, MAX_VISIBLE_WIDTH)
		local distance = (visibleWidth / 2) / math.tan(halfHorizontal)
		local visibleHeight = 2 * distance * math.tan(halfVertical)

		-- Follow the player, but keep the view inside the stage.
		local origin = stage.origin
		local scrollRange = math.max(0, (stage.width + 8 - visibleWidth) / 2)
		local minY = origin.Y + visibleHeight / 2 - 4
		local maxY = math.max(minY, origin.Y + stage.height - visibleHeight / 2 + 4)
		local x = if root then root.Position.X else origin.X
		local y = if root then root.Position.Y + 4 else minY
		local target = Vector3.new(
			math.clamp(x, origin.X - scrollRange, origin.X + scrollRange),
			math.clamp(y, minY, maxY),
			origin.Z
		)

		-- Snap when teleporting between stages, otherwise glide.
		local current = if focus and (focus - target).Magnitude < 150 then focus:Lerp(target, math.min(1, dt * FOLLOW_SPEED)) else target
		focus = current

		local shake = Vector3.zero
		if shakeAmount > 0.01 then
			shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shakeAmount
			shakeAmount = math.max(0, shakeAmount - dt * 4)
		end

		local lookAt = current + shake
		camera.CFrame = CFrame.lookAt(lookAt + Vector3.new(0, 3, distance), lookAt)
	end)
end

return StageCamera
