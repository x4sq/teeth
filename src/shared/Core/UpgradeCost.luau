--!strict
-- UpgradeCost - what tool upgrades and hires cost. Pure.

local UpgradeCost = {}

--- Cost to take `tool` from `currentLevel` to the next level, or nil at the cap / unknown tool.
function UpgradeCost.toolCost(tool: string, currentLevel: number, cfg: any): number?
	local base = cfg.toolBaseCost[tool]
	if base == nil or currentLevel ~= currentLevel or currentLevel >= cfg.maxToolLevel then
		return nil
	end
	local lvl = math.max(1, math.floor(currentLevel))
	return math.floor(base * cfg.toolCostGrowth ^ (lvl - 1) + 0.5)
end

--- Cost of the next dentist when `owned` are already hired.
function UpgradeCost.hireCost(owned: number, cfg: any): number
	return math.floor(cfg.hireBaseCost * cfg.hireCostGrowth ^ math.max(0, owned) + 0.5)
end

function UpgradeCost.canBuy(cash: number, cost: number?): boolean
	return cost ~= nil and cash >= cost
end

return UpgradeCost
