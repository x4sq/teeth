--!strict
-- ShopService - Robux purchases. Product ids live in GameConfig.products; an id of 0 means "not created
-- yet": the shop shows the item as "Soon" and a request for it is politely refused. Nothing here spends
-- or grants anything until you create the products in the Creator Dashboard and fill in the ids.
--
-- ProcessReceipt is idempotent: a PurchaseId already in the player's saved `receipts` is never granted twice.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)

local ShopService = Knit.CreateService({ Name = "ShopService" })

function ShopService:KnitInit()
	self._buy = Net.server("Shop_Buy")
	self._announce = Net.server("Announce")
	self._limiter = RateLimit.new(1, 3)
	self._keyById = {} :: { [number]: string }
	for key, id in GameConfig.products do
		if id > 0 and key ~= "DoubleCashPass" then
			self._keyById[id] = key
		end
	end
end

--- Give the player what `key` sells. Returns false only if it can't be granted right now.
function ShopService:_grant(player: Player, key: string): boolean
	local progress = Knit.GetService("ProgressService")
	local data = Knit.GetService("DataService"):Get(player)
	if not data then
		return false
	end
	if key == "InstantClean" then
		if not Knit.GetService("TreatmentService"):InstantFinish(player) then
			-- nothing to finish right now: pay the value back as cash instead of losing the purchase
			progress:AddCash(player, 500 * (data.tier + 1))
			progress:Announce(
				player,
				"No treatment was open, so Instant Clean paid out as cash instead.",
				"good"
			)
		end
		return true
	elseif key == "CashBoost10m" then
		progress:AddBoost(player, GameConfig.cashBoostSeconds)
		progress:Announce(player, "2x Cash for 10 minutes!", "good")
		return true
	elseif key == "StarterBundle" then
		progress:AddCash(player, GameConfig.starterBundleCash)
		if data.toolLevels.Spatula < GameConfig.maxToolLevel then
			data.toolLevels.Spatula += 1
		end
		progress:Announce(
			player,
			`Starter Bundle: +${GameConfig.starterBundleCash} and a free Filler upgrade!`,
			"good"
		)
		return true
	end
	return false
end

function ShopService:KnitStart()
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local data = player and Knit.GetService("DataService"):Get(player)
		if not player or not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local purchaseId = tostring(receipt.PurchaseId)
		if data.receipts[purchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local key = self._keyById[receipt.ProductId]
		if not key or not self:_grant(player, key) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		data.receipts[purchaseId] = true
		Knit.GetService("ProgressService"):MarkDirty(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- the permanent 2x cash game pass
	local passId = GameConfig.products.DoubleCashPass
	if passId > 0 then
		Knit.GetService("DataService").Loaded:Connect(function(player)
			local ok, owns = pcall(
				MarketplaceService.UserOwnsGamePassAsync,
				MarketplaceService,
				player.UserId,
				passId
			)
			if ok and owns then
				Knit.GetService("ProgressService"):SetDoubleCash(player, true)
			end
		end)
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(
			function(player, finishedId, purchased)
				if purchased and finishedId == passId then
					Knit.GetService("ProgressService"):SetDoubleCash(player, true)
				end
			end
		)
	end

	self._buy.OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" or #key > 32 or not self._limiter:take(player, os.clock()) then
			return
		end
		local id = (GameConfig.products :: any)[key]
		if type(id) ~= "number" or id <= 0 then
			self._announce:FireClient(player, "That item isn't available yet. Coming soon!", "info")
			return
		end
		if key == "DoubleCashPass" then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._limiter:forget(player)
	end)
end

return ShopService
