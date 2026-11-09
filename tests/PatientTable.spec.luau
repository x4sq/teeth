--!strict
local cfg = require("../src/shared/Config/GameConfig")
local Rng = require("../src/shared/Core/Rng")
local PatientTable = require("../src/shared/Core/PatientTable")

local function shares(luck: number, n: number)
	local rng = Rng.new(7)
	local counts: { [string]: number } = { Common = 0, Rare = 0, VIP = 0, Zombie = 0 }
	for _ = 1, n do
		local r = PatientTable.roll(rng, luck, cfg)
		counts[r] += 1
	end
	return counts
end

return {
	["the same seed rolls the same patients"] = function()
		local a, b = Rng.new(11), Rng.new(11)
		for _ = 1, 200 do
			assert(PatientTable.roll(a, 0, cfg) == PatientTable.roll(b, 0, cfg), "diverged")
		end
	end,

	["at zero luck Common dominates and Zombie is rare"] = function()
		local c = shares(0, 10000)
		assert(c.Common / 10000 > 0.75, "common share " .. c.Common / 10000)
		assert(c.Zombie / 10000 < 0.05, "zombie share " .. c.Zombie / 10000)
		assert(c.Zombie > 0, "zombie must still be reachable")
	end,

	["luck raises the rarer share but Common never disappears"] = function()
		local lo, hi = shares(0, 10000), shares(1, 10000)
		local function rare(c: { [string]: number })
			return c.Rare + c.VIP + c.Zombie
		end
		assert(rare(hi) > rare(lo), "luck did nothing")
		assert(hi.Common > 0, "common vanished at max luck")
	end,

	["nan luck behaves like zero luck"] = function()
		local a, b = Rng.new(5), Rng.new(5)
		for _ = 1, 100 do
			assert(
				PatientTable.roll(a, 0 / 0, cfg) == PatientTable.roll(b, 0, cfg),
				"nan luck differs"
			)
		end
	end,

	["spawn delay starts at 30 s, only shrinks with tier, and has a floor"] = function()
		assert(PatientTable.spawnDelay(0, cfg) == 30, "tier 0 should be 30")
		for tier = 0, 20 do
			assert(
				PatientTable.spawnDelay(tier + 1, cfg) <= PatientTable.spawnDelay(tier, cfg),
				"grew at tier " .. tier
			)
			assert(PatientTable.spawnDelay(tier, cfg) >= cfg.minSpawnDelay, "below floor")
		end
	end,
}
