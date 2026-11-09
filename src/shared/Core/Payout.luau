--!strict
-- Payout - how much each cleaned issue and each submitted treatment is worth. Pure.

local Payout = {}

local function level(toolLevel: number): number
	if toolLevel ~= toolLevel or toolLevel < 1 then
		return 1
	end
	return math.floor(toolLevel)
end

--- Cash for one cleaned issue.
function Payout.perIssue(kind: string, toolLevel: number, rarity: string, cfg: any): number
	local base = cfg.basePay[kind] or 0
	local multiplier = cfg.rarityMultiplier[rarity] or 1
	local value = base * (1 + cfg.toolPayPerLevel * (level(toolLevel) - 1)) * multiplier
	return math.max(0, math.floor(value + 0.5))
end

--- Bonus paid on Submit: a fraction of the summed base pay, larger when every issue was cleaned.
function Payout.submit(
	mouth: { issues: { { kind: string } } },
	rarity: string,
	perfect: boolean,
	cfg: any
): number
	local sum = 0
	for _, issue in mouth.issues do
		sum += cfg.basePay[issue.kind] or 0
	end
	local fraction = if perfect then cfg.perfectBonus else cfg.partialBonus
	return math.max(0, math.floor(sum * (cfg.rarityMultiplier[rarity] or 1) * fraction + 0.5))
end

return Payout
