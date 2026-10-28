-- Client entry point: title screen, side-on camera, depth layers, HUD, audio and effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require(script.Audio)
local CharacterAudio = require(script.CharacterAudio)
local Danger = require(script.Danger)
local Effects = require(script.Effects)
local Grab = require(script.Grab)
local Hud = require(script.Hud)
local Layers = require(script.Layers)
local StageCamera = require(script.StageCamera)
local TitleScreen = require(script.TitleScreen)

StageCamera.start()
Audio.start()
Hud.start()
Effects.start()
CharacterAudio.start()
Danger.start()
Grab.start()
task.spawn(Layers.start) -- waits for the default control script to load

TitleScreen.show(function()
	Audio.beginGame()
end)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind: string, data)
	Effects.handle(kind, data)
	Hud.handle(kind, data)
end)
