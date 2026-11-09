--!strict
-- DataService - loads and saves each player's PlayerData through ProfileStore (session-locked).
--
-- Rules it keeps:
--   * Whatever comes out of the DataStore is repaired by PlayerDataModel.migrate before anyone sees it.
--   * A failed load NEVER kicks the player and NEVER writes default data over a real save: the player
--     gets an in-memory ("ephemeral") profile that is simply not saved, and is told so.
--   * In Studio without API access ProfileStore switches to its own in-memory mock, so nothing special is needed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataModel = require(ReplicatedStorage.Shared.Core.PlayerDataModel)
local ProfileStore = require(script.Parent.Parent.ProfileStore)

local DataService = Knit.CreateService({ Name = "DataService" })

local function replaceContents(target: any, source: any)
	for key in target do
		target[key] = nil
	end
	for key, value in source do
		target[key] = value
	end
end

function DataService:KnitInit()
	self.Loaded = Signal.new() -- (player, data)
	self.Leaving = Signal.new() -- (player, data), fired before the session ends
	self._store = ProfileStore.New(GameConfig.sessionKey, PlayerDataModel.defaults(GameConfig))
	self._profiles = {} :: { [Player]: any }
	self._announce = Net.server("Announce")
end

--- The player's live data table, or nil until it has loaded.
function DataService:Get(player: Player): any?
	local profile = self._profiles[player]
	return if profile then profile.Data else nil
end

--- True when this player's progress is being saved (false for an ephemeral profile).
function DataService:IsPersistent(player: Player): boolean
	local profile = self._profiles[player]
	return profile ~= nil and profile.ephemeral ~= true
end

--- Run `fn(data)` safely. Returns false if there is no data or `fn` errored.
function DataService:Update(player: Player, fn: (any) -> ()): boolean
	local data = self:Get(player)
	if not data then
		return false
	end
	local ok, err = pcall(fn, data)
	if not ok then
		warn(`[DataService] update for {player.Name} failed: {err}`)
	end
	return ok
end

function DataService:WaitForData(player: Player, timeout: number): any?
	local deadline = os.clock() + timeout
	while self:Get(player) == nil and player.Parent == Players and os.clock() < deadline do
		task.wait(0.1)
	end
	return self:Get(player)
end

function DataService:_load(player: Player)
	local profile = self._store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if player.Parent ~= Players then
		if profile then
			profile:EndSession()
		end
		return
	end
	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		replaceContents(profile.Data, PlayerDataModel.migrate(profile.Data, GameConfig))
		profile.OnSessionEnd:Connect(function()
			self._profiles[player] = nil
			player:Kick("Your save was opened on another server. Please rejoin.")
		end)
		self._profiles[player] = profile
	else
		warn(`[DataService] could not load a profile for {player.Name}; using an unsaved session`)
		self._profiles[player] = { Data = PlayerDataModel.defaults(GameConfig), ephemeral = true }
		self._announce:FireClient(
			player,
			"We couldn't load your save, so progress won't be saved this session.",
			"warn"
		)
	end
	self.Loaded:Fire(player, (self._profiles[player] :: any).Data)
end

function DataService:KnitStart()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			self:_load(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_load(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		local profile = self._profiles[player]
		if not profile then
			return
		end
		profile.Data.lastSeen = os.time()
		self.Leaving:Fire(player, profile.Data)
		self._profiles[player] = nil
		if profile.ephemeral ~= true then
			profile:EndSession()
		end
	end)
end

return DataService
