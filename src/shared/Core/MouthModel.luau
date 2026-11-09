--!strict
-- MouthModel - the patient's mouth: which teeth have which problem, and the rules for fixing them.
-- Pure: no Instances. `cfg` is GameConfig, passed in so this runs under Lune.

local MouthModel = {}

export type Issue = { toothId: number, kind: string, cleaned: boolean }
export type Mouth = { seed: number, teeth: number, issues: { Issue } }
-- Anything with these two methods works: Core/Rng, or Roblox's Random.
export type Rng = { NextInteger: (any, number, number) -> number, NextNumber: (any) -> number }

local TOOL_FOR: { [string]: string } =
	{ dirt = "Toothbrush", debris = "Floss", chip = "Spatula", rot = "Pliers" }

local function shuffled(n: number, rng: Rng): { number }
	local pool = table.create(n)
	for i = 1, n do
		pool[i] = i
	end
	for i = n, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	return pool
end

--- Build a mouth for `rarity` using `rng` (seed is only recorded, for debugging and replays).
--- `pliersUnlocked` gates "rot" issues. Teeth carry dirt/chip/rot (one issue per tooth);
--- debris sits in a gap between neighbouring teeth of the same row: 16 teeth = 2 rows of 8 = 14 gaps
--- (gaps 1..7 are the upper row, 8..14 the lower row).
function MouthModel.generate(
	rng: Rng,
	seed: number,
	rarity: string,
	pliersUnlocked: boolean,
	cfg: any
): Mouth
	local profile = cfg.mouthProfiles[rarity] or cfg.mouthProfiles.Common
	local teeth = cfg.teethPerMouth
	local issues: { Issue } = {}

	local toothPool = shuffled(teeth, rng)
	local cursor = 0
	for _, kind in { "dirt", "chip", "rot" } do
		local range = profile[kind]
		local n = rng:NextInteger(range[1], range[2])
		if kind == "rot" and not pliersUnlocked then
			n = 0
		end
		for _ = 1, n do
			if cursor < teeth then
				cursor += 1
				table.insert(issues, { toothId = toothPool[cursor], kind = kind, cleaned = false })
			end
		end
	end

	local gaps = teeth - 2
	local gapPool = shuffled(gaps, rng)
	local debris = rng:NextInteger(profile.debris[1], profile.debris[2])
	for i = 1, math.min(debris, gaps) do
		table.insert(issues, { toothId = gapPool[i], kind = "debris", cleaned = false })
	end

	if #issues == 0 then
		table.insert(issues, { toothId = toothPool[1], kind = "dirt", cleaned = false })
	end
	return { seed = seed, teeth = teeth, issues = issues }
end

--- Try to clean issue `index` with `tool`. Returns ok, reason.
function MouthModel.clean(mouth: Mouth, index: any, tool: any): (boolean, string?)
	if type(index) ~= "number" or index ~= index or index % 1 ~= 0 then
		return false, "bad index"
	end
	local issue = mouth.issues[index]
	if issue == nil then
		return false, "bad index"
	end
	if issue.cleaned then
		return false, "already cleaned"
	end
	if TOOL_FOR[issue.kind] ~= tool then
		return false, "wrong tool"
	end
	issue.cleaned = true
	return true, nil
end

--- 0..1; a mouth with nothing wrong counts as fully clean.
function MouthModel.cleanedFraction(mouth: Mouth): number
	local total = #mouth.issues
	if total == 0 then
		return 1
	end
	local done = 0
	for _, issue in mouth.issues do
		if issue.cleaned then
			done += 1
		end
	end
	return done / total
end

function MouthModel.canSubmit(mouth: Mouth, threshold: number): boolean
	return MouthModel.cleanedFraction(mouth) >= threshold
end

--- How many issues each tool still has to fix: { Toothbrush = 5, Floss = 1, ... }
function MouthModel.remaining(mouth: Mouth): { [string]: number }
	local out: { [string]: number } = { Toothbrush = 0, Floss = 0, Spatula = 0, Pliers = 0 }
	for _, issue in mouth.issues do
		if not issue.cleaned then
			local tool = TOOL_FOR[issue.kind]
			out[tool] += 1
		end
	end
	return out
end

MouthModel.ToolFor = TOOL_FOR

return MouthModel
