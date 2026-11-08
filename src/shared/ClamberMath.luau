-- Can this part be clambered onto from here, and where would you end up? The client uses it to pick what to
-- ask for, and the server uses the very same rules to decide whether to allow it.
--
-- `feetOffset` is how far the middle of the character (HumanoidRootPart) is above their feet.
-- `settings` is Config.KillerHotel.parkour.

local ClamberMath = {}

local INSET = 0.8 -- stand this far in from the edge

export type Result = {
	rise: number, -- studs from the feet up to the top
	nearest: Vector3, -- the closest spot on the top surface
	target: Vector3, -- where the HumanoidRootPart ends up
	distance: number, -- flat distance to the nearest spot
}

function ClamberMath.evaluate(part: BasePart, rootPosition: Vector3, feetOffset: number, settings): Result?
	if part.CFrame.UpVector.Y < 0.95 then
		return nil -- only things that sit flat
	end
	local half = part.Size / 2
	local topY = part.Position.Y + half.Y
	local rise = topY - (rootPosition.Y - feetOffset)
	if rise < settings.minLedge or rise > settings.reach then
		return nil
	end

	local localPosition = part.CFrame:PointToObjectSpace(rootPosition)
	local limitX, limitZ = math.max(half.X - INSET, 0), math.max(half.Z - INSET, 0)
	local nearest = part.CFrame:PointToWorldSpace(Vector3.new(math.clamp(localPosition.X, -limitX, limitX), half.Y, math.clamp(localPosition.Z, -limitZ, limitZ)))
	local distance = Vector3.new(nearest.X - rootPosition.X, 0, nearest.Z - rootPosition.Z).Magnitude
	if distance > settings.maxDistance then
		return nil
	end
	return { rise = rise, nearest = nearest, target = nearest + Vector3.new(0, feetOffset + 0.1, 0), distance = distance }
end

return ClamberMath
