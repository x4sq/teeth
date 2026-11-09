--!strict
-- FxController - sound effects. Sounds use Roblox's built-in client sounds (rbxasset://), so there are
-- no asset ids to expire. A sound that fails to load is simply silent. To use richer audio, find ids
-- with the `roblox-sfx` skill and replace the paths below; nothing else needs to change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local FxController = Knit.CreateController({ Name = "FxController" })

local BANK: { [string]: { id: string, volume: number } } = {
	click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5 },
	cash = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6 },
	scrub = { id = "rbxasset://sounds/swoosh.wav", volume = 0.25 },
	good = { id = "rbxasset://sounds/victory.wav", volume = 0.5 },
	warn = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.5 },
	alert = { id = "rbxasset://sounds/bass.wav", volume = 0.6 },
}

function FxController:KnitInit()
	self.Muted = false
	self._sounds = {} :: { [string]: Sound }
end

--- Play a named sound (see BANK). Safe to call from anywhere, any number of times.
function FxController:Play(name: string)
	if self.Muted then
		return
	end
	local entry = BANK[name]
	if not entry then
		return
	end
	local sound = self._sounds[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "Fx_" .. name
		sound.SoundId = entry.id
		sound.Volume = entry.volume
		sound.Parent = SoundService
		self._sounds[name] = sound
	end
	sound.TimePosition = 0
	sound:Play()
end

return FxController
