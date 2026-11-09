--!strict
-- ProgressService - everything about a player's money and progression: cash, tool upgrades, hired
-- dentists (and what they earn while you're away), the goal ladder, the playtime reward, and syncing
-- the resulting state to the client. All rules live in Core; this file is the glue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local ClinicTiers = require(ReplicatedStorage.Shared.Core.ClinicTiers)
local Goals = require(ReplicatedStorage.Shared.Core.Goals)
local Staff = require(ReplicatedStorage.Shared.Core.Staff)
local UpgradeCost = require(ReplicatedStorage.Shared.Core.UpgradeCost)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)

local MAX_CASH = 1e15
local STAFF_TICK = 5

local ProgressService = Knit.CreateService({ Name = "ProgressService" })

function ProgressService:KnitInit()
	self._dirty = {} :: { [Player]: boolean }
	self._boostUntil = {} :: { [Player]: number }
	self._doubleCash = {} :: { [Player]: boolean }
	self._limiter = RateLimit.new(4, 6)
	self._sync = Net.server("State_Sync")
	self._announce = Net.server("Announce")
	self._upgrade = Net.server("Upgrade_Buy")
	self._hire = Net.server("Staff_Hire")
	self._claim = Net.server("Reward_Claim")
end

local function staffRate(data: any): number
	return GameConfig.staffCashPerSecond * (1 + 0.5 * data.tier)
end

function ProgressService:_data(player: Player): any?
	return Knit.GetService("DataService"):Get(player)
end

function ProgressService:Announce(player: Player, text: string, kind: string?)
	self._announce:FireClient(player, text, kind or "info")
end

function ProgressService:MarkDirty(player: Player)
	self._dirty[player] = true
end

-- ---- cash -----------------------------------------------------------------------------------

--- Add cash (whole numbers only). `amount` is used as given: callers apply multipliers.
function ProgressService:AddCash(player: Player, amount: number)
	local data = self:_data(player)
	if not data or amount ~= amount or amount <= 0 then
		return
	end
	data.cash = math.min(MAX_CASH, data.cash + math.floor(amount))
	self:MarkDirty(player)
end

function ProgressService:SpendCash(player: Player, amount: number): boolean
	local data = self:_data(player)
	if not data or amount ~= amount or amount < 0 or data.cash < amount then
		return false
	end
	data.cash -= math.floor(amount)
	self:MarkDirty(player)
	return true
end

--- 2x from the game pass, 2x from an active boost; they stack.
function ProgressService:GetMultiplier(player: Player): number
	local m = 1
	if self._doubleCash[player] then
		m *= 2
	end
	if (self._boostUntil[player] or 0) > os.time() then
		m *= 2
	end
	return m
end

function ProgressService:SetDoubleCash(player: Player, owned: boolean)
	self._doubleCash[player] = owned
	self:MarkDirty(player)
end

function ProgressService:AddBoost(player: Player, seconds: number)
	local base = math.max(self._boostUntil[player] or 0, os.time())
	self._boostUntil[player] = base + seconds
	self:MarkDirty(player)
end

-- ---- goals ----------------------------------------------------------------------------------

--- Feed a game event to the goal ladder; pays and advances when a goal completes.
function ProgressService:Record(player: Player, event: any)
	local data = self:_data(player)
	if not data then
		return
	end
	local before = data.goals
	local after = Goals.progress(before, event, GameConfig)
	if after == before then
		return
	end
	data.goals = after
	-- finishing a goal can immediately satisfy the next ("own X") goals, so loop
	for _ = 1, 5 do
		if not Goals.completed(data.goals, GameConfig) then
			break
		end
		local def = Goals.def(data.goals.index, GameConfig)
		self:AddCash(player, def.reward)
		self:Announce(player, `Goal complete! {def.text}  +${def.reward}`, "goal")
		data.goals = Goals.advance(data.goals)
		local nextDef = Goals.def(data.goals.index, GameConfig)
		if Goals.alreadyDone(nextDef, data) then
			data.goals.progress = nextDef.target
		end
	end
	self:MarkDirty(player)
end

-- ---- upgrades and staff -----------------------------------------------------------------------

function ProgressService:BuyUpgrade(player: Player, tool: any)
	local data = self:_data(player)
	if not data or type(tool) ~= "string" or not table.find(GameConfig.toolOrder, tool) then
		return
	end
	if tool == "Pliers" and not ClinicTiers.pliersUnlocked(data.tier, GameConfig) then
		self:Announce(
			player,
			"Pliers unlock with your 2nd chair. Expand your clinic first!",
			"warn"
		)
		return
	end
	local cost = UpgradeCost.toolCost(tool, data.toolLevels[tool], GameConfig)
	if cost == nil then
		self:Announce(player, `{GameConfig.toolNames[tool]} is at max level.`, "info")
		return
	end
	if not self:SpendCash(player, cost) then
		self:Announce(player, "Not enough cash for that upgrade.", "warn")
		return
	end
	data.toolLevels[tool] += 1
	self:Record(player, { kind = "upgrade", tool = tool })
	self:Announce(
		player,
		`{GameConfig.toolNames[tool]} is now level {data.toolLevels[tool]}!`,
		"good"
	)
	self:MarkDirty(player)
end

function ProgressService:Hire(player: Player)
	local data = self:_data(player)
	if not data then
		return
	end
	if data.dentists >= ClinicTiers.get(data.tier, GameConfig).maxDentists then
		self:Announce(
			player,
			"Your clinic can't fit more dentists. Expand it to hire more.",
			"warn"
		)
		return
	end
	if not self:SpendCash(player, UpgradeCost.hireCost(data.dentists, GameConfig)) then
		self:Announce(player, "Not enough cash to hire a dentist.", "warn")
		return
	end
	data.dentists += 1
	self:Record(player, { kind = "hire" })
	self:Announce(player, "You hired a dentist! They'll earn cash even while you're away.", "good")
	self:MarkDirty(player)
end

function ProgressService:ClaimPlaytime(player: Player)
	local data = self:_data(player)
	if not data then
		return
	end
	local now = os.time()
	if now - data.lastPlaytimeClaim < GameConfig.playtimeRewardSeconds then
		return
	end
	local reward = GameConfig.playtimeRewardBase * (data.tier + 1)
	data.lastPlaytimeClaim = now
	self:AddCash(player, reward)
	self:Announce(player, `Playtime reward!  +${reward}`, "good")
	self:MarkDirty(player)
end

-- ---- state sync -------------------------------------------------------------------------------

function ProgressService:BuildState(player: Player): any?
	local data = self:_data(player)
	if not data then
		return nil
	end
	local tierDef = ClinicTiers.get(data.tier, GameConfig)
	local nextTier = GameConfig.tiers[data.tier + 1]
	local toolCosts = {}
	for _, tool in GameConfig.toolOrder do
		toolCosts[tool] = UpgradeCost.toolCost(tool, data.toolLevels[tool], GameConfig) or false
	end
	local def = Goals.def(data.goals.index, GameConfig)
	local products = {}
	for key, id in GameConfig.products do
		products[key] = id > 0
	end
	return {
		cash = data.cash,
		tier = data.tier,
		tierName = tierDef.name,
		chairs = tierDef.chairs,
		nextTierName = if nextTier then nextTier.name else nil,
		nextTierCost = if nextTier then nextTier.cost else nil,
		dentists = data.dentists,
		maxDentists = tierDef.maxDentists,
		hireCost = UpgradeCost.hireCost(data.dentists, GameConfig),
		toolLevels = data.toolLevels,
		toolCosts = toolCosts,
		pliersUnlocked = ClinicTiers.pliersUnlocked(data.tier, GameConfig),
		goal = {
			text = def.text,
			progress = data.goals.progress,
			target = def.target,
			reward = def.reward,
		},
		goalsDone = data.goals.done,
		treated = data.treated,
		playtimeIn = math.max(
			0,
			GameConfig.playtimeRewardSeconds - (os.time() - data.lastPlaytimeClaim)
		),
		multiplier = self:GetMultiplier(player),
		boostLeft = math.max(0, (self._boostUntil[player] or 0) - os.time()),
		customize = data.customize,
		products = products,
		persistent = Knit.GetService("DataService"):IsPersistent(player),
	}
end

function ProgressService:Push(player: Player)
	local state = self:BuildState(player)
	if state then
		self._sync:FireClient(player, state)
	end
end

function ProgressService:KnitStart()
	local dataService = Knit.GetService("DataService")

	dataService.Loaded:Connect(function(player, data)
		-- dentists earned while the owner was away
		if data.lastSeen > 0 and data.dentists > 0 then
			local earned = Staff.earnings(
				os.time() - data.lastSeen,
				data.dentists,
				staffRate(data),
				GameConfig.staffCapSeconds
			)
			if earned > 0 then
				self:AddCash(player, earned)
				self:Announce(
					player,
					`Welcome back! Your dentists earned ${earned} while you were away.`,
					"good"
				)
			end
		end
		data.lastSeen = os.time()
		local def = Goals.def(data.goals.index, GameConfig)
		if Goals.alreadyDone(def, data) then
			data.goals.progress = def.target
		end
		self:Push(player)
	end)

	dataService.Leaving:Connect(function(player)
		self._dirty[player] = nil
		self._boostUntil[player] = nil
		self._doubleCash[player] = nil
		self._limiter:forget(player)
	end)

	-- client requests: rate-limited, then validated by the method they call
	self._upgrade.OnServerEvent:Connect(function(player, tool)
		if self._limiter:take(player, os.clock()) then
			self:BuyUpgrade(player, tool)
		end
	end)
	self._hire.OnServerEvent:Connect(function(player)
		if self._limiter:take(player, os.clock()) then
			self:Hire(player)
		end
	end)
	self._claim.OnServerEvent:Connect(function(player, id)
		if id == "playtime" and self._limiter:take(player, os.clock()) then
			self:ClaimPlaytime(player)
		end
	end)

	-- coalesce state pushes: at most ~5 per second per player
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player in self._dirty do
				self._dirty[player] = nil
				if player.Parent == Players then
					self:Push(player)
				end
			end
		end
	end)

	-- hired dentists earn while you play too; also refreshes the playtime countdown
	task.spawn(function()
		while true do
			task.wait(STAFF_TICK)
			for _, player in Players:GetPlayers() do
				local data = self:_data(player)
				if data then
					data.lastSeen = os.time()
					if data.dentists > 0 then
						self:AddCash(
							player,
							Staff.earnings(
								STAFF_TICK,
								data.dentists,
								staffRate(data),
								GameConfig.staffCapSeconds
							)
						)
					end
					self:MarkDirty(player)
				end
			end
		end
	end)
end

return ProgressService
