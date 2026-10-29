-- Works out which stage (the Pod or a level) a position is in, using the layout in Config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Stage = { name: string, origin: Vector3, width: number, depth: number, height: number, waterDepth: number? }

local Stages = {}

local all: { Stage } = {
	{ name = "Pod", origin = Config.Pod.origin, width = Config.Pod.width, depth = Config.Pod.depth, height = Config.Pod.height },
}
for _, def in Config.Levels do
	table.insert(all, {
		name = def.name,
		origin = def.origin,
		width = def.width,
		depth = def.depth,
		height = def.height,
		waterDepth = (def :: any).waterDepth,
	})
end

function Stages.find(position: Vector3): Stage?
	for _, stage in all do
		local offset = position - stage.origin
		if math.abs(offset.X) <= stage.width / 2 + 10 and math.abs(offset.Z) <= stage.depth / 2 + 10 and offset.Y > -80 and offset.Y < stage.height + 80 then
			return stage
		end
	end
	return nil
end

return Stages
