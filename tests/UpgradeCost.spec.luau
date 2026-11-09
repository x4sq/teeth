--!strict
local cfg = require("../src/shared/Config/GameConfig")
local UpgradeCost = require("../src/shared/Core/UpgradeCost")

return {
	["tool costs are whole numbers that strictly increase until the cap"] = function()
		for _, tool in cfg.toolOrder do
			local prev = 0
			for level = 1, cfg.maxToolLevel - 1 do
				local c = UpgradeCost.toolCost(tool, level, cfg)
				assert(c ~= nil and c % 1 == 0 and c > prev, `{tool} L{level}: {c}`)
				prev = c :: number
			end
		end
	end,

	["there is nothing to buy at the level cap, or for an unknown tool"] = function()
		assert(UpgradeCost.toolCost("Spatula", cfg.maxToolLevel, cfg) == nil, "cap not enforced")
		assert(UpgradeCost.toolCost("Laser", 1, cfg) == nil, "unknown tool priced")
		assert(UpgradeCost.toolCost("Spatula", 0 / 0, cfg) == nil, "nan level priced")
	end,

	["the Filler's second upgrade lands near the observed few thousand"] = function()
		local c = UpgradeCost.toolCost("Spatula", 2, cfg) :: number
		assert(c >= 1500 and c <= 6000, "got " .. c)
	end,

	["hiring gets more expensive with each dentist"] = function()
		assert(
			UpgradeCost.hireCost(1, cfg) > UpgradeCost.hireCost(0, cfg),
			"second hire not dearer"
		)
		assert(
			UpgradeCost.hireCost(-3, cfg) == UpgradeCost.hireCost(0, cfg),
			"negative owned not clamped"
		)
	end,

	["canBuy needs a price and enough cash"] = function()
		assert(UpgradeCost.canBuy(100, 100) == true, "exact cash")
		assert(UpgradeCost.canBuy(99, 100) == false, "short cash")
		assert(UpgradeCost.canBuy(1e9, nil) == false, "no price")
	end,
}
