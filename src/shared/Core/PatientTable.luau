--!strict
-- PatientTable - which patient arrives next, and how long until they do. Pure.

local PatientTable = {}

local ORDER = { "Common", "Rare", "VIP", "Zombie" }

--- Weighted roll. `luck` (0..1) shifts weight toward rarer patients but never removes Common.
function PatientTable.roll(rng: { NextNumber: (any) -> number }, luck: number, cfg: any): string
	local l = if luck ~= luck then 0 else math.clamp(luck, 0, 1)
	local weights: { [string]: number } = {}
	local total = 0
	for _, rarity in ORDER do
		local w = math.max(0, cfg.rarityWeights[rarity] * (1 + l * cfg.luckShift[rarity]))
		weights[rarity] = w
		total += w
	end
	local pick = rng:NextNumber() * total
	for _, rarity in ORDER do
		pick -= weights[rarity]
		if pick < 0 then
			return rarity
		end
	end
	return "Common"
end

--- Seconds between patient spawns for a clinic tier; faster as the clinic grows, never below the floor.
function PatientTable.spawnDelay(tier: number, cfg: any): number
	return math.max(cfg.minSpawnDelay, cfg.spawnDelay - tier * cfg.spawnDelayStepPerTier)
end

return PatientTable
