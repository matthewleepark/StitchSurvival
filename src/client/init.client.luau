-- Client entry point: side-on camera, depth layers, HUD, and effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Effects = require(script.Effects)
local Hud = require(script.Hud)
local Layers = require(script.Layers)
local StageCamera = require(script.StageCamera)

StageCamera.start()
Hud.start()
Effects.start()
task.spawn(Layers.start) -- waits for the default control script to load

local remotes = ReplicatedStorage:WaitForChild("Remotes")
remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind: string, data)
	Effects.handle(kind, data)
	Hud.handle(kind, data)
end)
