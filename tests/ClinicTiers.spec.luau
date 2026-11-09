--!strict
local cfg = require("../src/shared/Config/GameConfig")
local ClinicTiers = require("../src/shared/Core/ClinicTiers")

return {
	["tiers 0 to 3 have 1, 3, 5 and 8 chairs"] = function()
		local want = { [0] = 1, [1] = 3, [2] = 5, [3] = 8 }
		for tier, chairs in want do
			assert(ClinicTiers.get(tier, cfg).chairs == chairs, "tier " .. tier)
		end
	end,

	["out-of-range tiers clamp instead of erroring"] = function()
		assert(ClinicTiers.get(-4, cfg).chairs == 1, "low clamp")
		assert(ClinicTiers.get(99, cfg).chairs == 8, "high clamp")
	end,

	["pliers unlock once there are 2 or more chairs"] = function()
		assert(ClinicTiers.pliersUnlocked(0, cfg) == false, "tier 0 has 1 chair")
		assert(ClinicTiers.pliersUnlocked(1, cfg) == true, "tier 1 has 3 chairs")
	end,

	["expansion needs cash and stops at the top tier"] = function()
		local ok, why = ClinicTiers.canExpand({ tier = 0, cash = cfg.tiers[1].cost - 1 }, cfg)
		assert(ok == false and why == "not enough cash", "short cash allowed")
		ok = ClinicTiers.canExpand({ tier = 0, cash = cfg.tiers[1].cost }, cfg)
		assert(ok == true, "exact cash refused")
		ok, why = ClinicTiers.canExpand({ tier = 3, cash = 1e12 }, cfg)
		assert(ok == false and why == "max tier", "expanded past the top")
	end,
}
