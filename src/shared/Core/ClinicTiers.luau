--!strict
-- ClinicTiers - building tiers: how many chairs, what each costs, what it unlocks. Pure.

local ClinicTiers = {}

local MAX_TIER = 3

function ClinicTiers.get(tier: number, cfg: any): any
	return cfg.tiers[math.clamp(math.floor(tier), 0, MAX_TIER)]
end

function ClinicTiers.pliersUnlocked(tier: number, cfg: any): boolean
	return ClinicTiers.get(tier, cfg).chairs >= cfg.pliersUnlockChairs
end

--- Can a player with `data.tier` and `data.cash` buy the next tier? Returns ok, reason.
function ClinicTiers.canExpand(data: { tier: number, cash: number }, cfg: any): (boolean, string?)
	if data.tier >= MAX_TIER then
		return false, "max tier"
	end
	local nextTier = cfg.tiers[data.tier + 1]
	if data.cash < nextTier.cost then
		return false, "not enough cash"
	end
	return true, nil
end

return ClinicTiers
