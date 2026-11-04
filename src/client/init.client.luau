-- Client entry point: title screen, HUD, audio, effects, flashlight, grabbing and screen shake.
-- The camera is the normal Roblox third-person camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminPanel = require(script.AdminPanel)
local Audio = require(script.Audio)
local CameraShake = require(script.CameraShake)
local CharacterAudio = require(script.CharacterAudio)
local Danger = require(script.Danger)
local Effects = require(script.Effects)
local Flashlight = require(script.Flashlight)
local Grab = require(script.Grab)
local Hud = require(script.Hud)
local TitleScreen = require(script.TitleScreen)

CameraShake.start()
Audio.start()
Hud.start()
Effects.start()
CharacterAudio.start()
Danger.start()
Flashlight.start()
Grab.start()
AdminPanel.start()

TitleScreen.show(function()
	Audio.beginGame()
end)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind: string, data)
	Effects.handle(kind, data)
	Hud.handle(kind, data)
end)
