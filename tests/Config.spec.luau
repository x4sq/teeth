--!strict
local cfg = require("../src/shared/Config/GameConfig")
local Types = require("../src/shared/Types")

return {
	["the submit threshold sits between the observed 71% and 83%"] = function()
		assert(
			cfg.submitThreshold > 0.71 and cfg.submitThreshold < 0.83,
			tostring(cfg.submitThreshold)
		)
	end,

	["rarity multipliers rise from Common to Zombie"] = function()
		local m = cfg.rarityMultiplier
		assert(m.Common < m.Rare and m.Rare < m.VIP and m.VIP < m.Zombie, "not increasing")
	end,

	["every issue kind has a tool, a base pay and a mouth-profile range"] = function()
		for _, kind in { "dirt", "debris", "chip", "rot" } do
			assert(Types.ToolForIssue[kind] ~= nil, "no tool for " .. kind)
			assert(cfg.basePay[kind] ~= nil, "no pay for " .. kind)
			for _, rarity in { "Common", "Rare", "VIP", "Zombie" } do
				local r = cfg.mouthProfiles[rarity][kind]
				assert(r and r[1] <= r[2], `bad range {rarity}/{kind}`)
			end
		end
	end,

	["there are 6 plots and tiers 0 to 3 with rising cost and chairs"] = function()
		assert(cfg.PlotCount == 6, "plots")
		for tier = 1, 3 do
			assert(cfg.tiers[tier].cost > cfg.tiers[tier - 1].cost, "cost not rising at " .. tier)
			assert(
				cfg.tiers[tier].chairs > cfg.tiers[tier - 1].chairs,
				"chairs not rising at " .. tier
			)
		end
	end,

	["every decor item has a kind and slots exist for both kinds"] = function()
		for id, item in cfg.decor do
			assert(item.kind == "floor" or item.kind == "wall", id)
		end
		assert(#cfg.decorSlots == cfg.maxDecorSlots, "slot count")
		for slot, id in cfg.defaultDecor do
			assert(cfg.decor[id] and table.find(cfg.decorSlots, slot), "bad default " .. slot)
		end
	end,

	["every default colour is a palette swatch"] = function()
		for slot, hex in cfg.defaultColors do
			local found = false
			for _, s in cfg.colorPalette do
				if s.hex:upper() == hex:upper() then
					found = true
				end
			end
			assert(found, `{slot} default {hex} not in the palette`)
		end
	end,

	["each authored goal has text, a kind, a positive target and reward"] = function()
		for i, g in cfg.goals do
			assert(#g.text > 0 and #g.kind > 0 and g.target > 0 and g.reward > 0, "goal " .. i)
		end
	end,
}
