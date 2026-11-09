--!strict
-- StateController - the client's one copy of what the server says about this player, plus the
-- remotes. Every other controller reads from here and sends requests through `Send`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Net = require(ReplicatedStorage.Shared.Net)

local StateController = Knit.CreateController({ Name = "StateController" })

local EVENTS: { Net.EventName } = {
	"Treat_Clean",
	"Treat_Submit",
	"Treat_Close",
	"Upgrade_Buy",
	"Clinic_Expand",
	"Clinic_Customize",
	"Staff_Hire",
	"Reward_Claim",
	"Shop_Buy",
}

function StateController:KnitInit()
	self.State = nil :: any
	self.Chairs = {} :: { any }
	self.SpawnIn = nil :: number?
	self.Changed = Signal.new() -- (state)
	self.ChairsChanged = Signal.new() -- (chairs)
	self.TimerChanged = Signal.new() -- (seconds)
	self.Announced = Signal.new() -- (text, kind)
	self.TreatOpen = Signal.new() -- (payload)
	self.TreatFeedback = Signal.new() -- (payload)
	self.TreatResult = Signal.new() -- (payload)
	self.TreatClosed = Signal.new() -- (sessionId)
	self._remotes = {} :: { [string]: RemoteEvent }
end

function StateController:Send(name: Net.EventName, ...: any)
	local remote = self._remotes[name]
	if remote then
		remote:FireServer(...)
	end
end

function StateController:KnitStart()
	for _, name in EVENTS do
		local remote = Net.client(name)
		if remote then
			self._remotes[name] = remote
		end
	end

	local function bind(name: Net.EventName, handler: (...any) -> ())
		local remote = Net.client(name)
		if remote then
			remote.OnClientEvent:Connect(handler)
		end
	end
	bind("State_Sync", function(state)
		self.State = state
		self.Changed:Fire(state)
	end)
	bind("Chairs_Sync", function(chairs)
		self.Chairs = chairs
		self.ChairsChanged:Fire(chairs)
	end)
	bind("Spawn_Timer", function(seconds)
		self.SpawnIn = seconds
		self.TimerChanged:Fire(seconds)
	end)
	bind("Announce", function(text, kind)
		self.Announced:Fire(text, kind)
	end)
	bind("Treat_Open", function(payload)
		self.TreatOpen:Fire(payload)
	end)
	bind("Treat_Feedback", function(payload)
		self.TreatFeedback:Fire(payload)
	end)
	bind("Treat_Result", function(payload)
		self.TreatResult:Fire(payload)
	end)
	bind("Treat_Closed", function(sessionId)
		self.TreatClosed:Fire(sessionId)
	end)
end

return StateController
