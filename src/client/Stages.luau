-- Works out which stage (the Pod or a level) a position is in, using the layout in Config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Stage = { name: string, origin: Vector3, width: number, height: number }

local Stages = {}

local all: { Stage } = {
	{ name = "Pod", origin = Config.Pod.origin, width = Config.Pod.width, height = Config.Pod.height },
}
for _, def in Config.Levels do
	table.insert(all, { name = def.name, origin = def.origin, width = def.width, height = def.height })
end

function Stages.find(position: Vector3): Stage?
	for _, stage in all do
		local offset = position - stage.origin
		if math.abs(offset.X) <= stage.width / 2 + 10 and math.abs(offset.Z) <= 40 and offset.Y > -80 and offset.Y < stage.height + 80 then
			return stage
		end
	end
	return nil
end

return Stages
