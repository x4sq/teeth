--!strict
local cfg = require("../src/shared/Config/GameConfig")
local Payout = require("../src/shared/Core/Payout")

local RARITIES = { "Common", "Rare", "VIP", "Zombie" }
local KINDS = { "dirt", "debris", "chip", "rot" }

return {
	["payouts are whole, finite and never negative"] = function()
		for level = 1, 50 do
			for _, rarity in RARITIES do
				for _, kind in KINDS do
					local v = Payout.perIssue(kind, level, rarity, cfg)
					assert(
						v == v and v ~= math.huge and v >= 0 and v % 1 == 0,
						`{kind}/{rarity}/L{level} = {v}`
					)
				end
			end
		end
	end,

	["a Common level-1 toothbrush tooth pays the observed $20"] = function()
		assert(Payout.perIssue("dirt", 1, "Common", cfg) == 20, "expected 20")
	end,

	["rarer patients always pay more"] = function()
		for _, kind in KINDS do
			local c = Payout.perIssue(kind, 1, "Common", cfg)
			local r = Payout.perIssue(kind, 1, "Rare", cfg)
			local v = Payout.perIssue(kind, 1, "VIP", cfg)
			local z = Payout.perIssue(kind, 1, "Zombie", cfg)
			assert(c < r and r < v and v < z, "order broken for " .. kind)
		end
	end,

	["a higher tool level never pays less"] = function()
		for level = 1, 49 do
			assert(
				Payout.perIssue("chip", level + 1, "Rare", cfg)
					>= Payout.perIssue("chip", level, "Rare", cfg),
				"dropped at " .. level
			)
		end
	end,

	["nan or sub-1 tool levels are treated as level 1"] = function()
		local base = Payout.perIssue("dirt", 1, "Common", cfg)
		assert(Payout.perIssue("dirt", 0 / 0, "Common", cfg) == base, "nan level")
		assert(Payout.perIssue("dirt", -5, "Common", cfg) == base, "negative level")
	end,

	["a perfect submit pays more than a partial one, and an empty mouth pays nothing"] = function()
		local mouth = { issues = { { kind = "dirt" }, { kind = "chip" }, { kind = "debris" } } }
		assert(
			Payout.submit(mouth, "Common", true, cfg) > Payout.submit(mouth, "Common", false, cfg),
			"perfect not better"
		)
		assert(Payout.submit({ issues = {} }, "Zombie", true, cfg) == 0, "empty mouth paid")
	end,
}
