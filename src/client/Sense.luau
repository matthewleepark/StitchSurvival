-- The Spooky Sense passive: while you have it equipped, every bomb and shark (anything the server
-- tagged "Hazard") glows with a red outline you can see through walls and floors. Only you see it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local Sense = {}

local glows: { [Instance]: Highlight } = {}

local function hasSense(): boolean
	return Config.passive(player:GetAttribute("Gear") :: string?, "sense") == true
end

local function show(hazard: Instance)
	if glows[hazard] or not hasSense() then
		return
	end
	local glow = Instance.new("Highlight")
	glow.Name = "SpookySense"
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.FillColor = Color3.fromRGB(255, 40, 40)
	glow.FillTransparency = 0.75
	glow.OutlineColor = Color3.fromRGB(255, 90, 90)
	glow.Adornee = hazard
	glow.Parent = hazard
	glows[hazard] = glow
end

local function hide(hazard: Instance)
	local glow = glows[hazard]
	if glow then
		glow:Destroy()
		glows[hazard] = nil
	end
end

local function refresh()
	if hasSense() then
		for _, hazard in CollectionService:GetTagged("Hazard") do
			show(hazard)
		end
	else
		for hazard in glows do
			hide(hazard)
		end
	end
end

function Sense.start()
	CollectionService:GetInstanceAddedSignal("Hazard"):Connect(show)
	CollectionService:GetInstanceRemovedSignal("Hazard"):Connect(hide)
	player:GetAttributeChangedSignal("Gear"):Connect(refresh)
	refresh()
end

return Sense
