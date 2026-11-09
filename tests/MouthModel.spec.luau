--!strict
local cfg = require("../src/shared/Config/GameConfig")
local Rng = require("../src/shared/Core/Rng")
local MouthModel = require("../src/shared/Core/MouthModel")

local function gen(seed: number, rarity: string, pliers: boolean)
	return MouthModel.generate(Rng.new(seed), seed, rarity, pliers, cfg)
end

local function fixed(kinds: { string })
	local issues = {}
	for i, kind in kinds do
		table.insert(issues, { toothId = i, kind = kind, cleaned = false })
	end
	return { seed = 0, teeth = 16, issues = issues }
end

return {
	["the same seed builds the same mouth"] = function()
		local a, b = gen(7, "Rare", true), gen(7, "Rare", true)
		assert(#a.issues == #b.issues, "issue counts differ")
		for i, issue in a.issues do
			assert(
				issue.kind == b.issues[i].kind and issue.toothId == b.issues[i].toothId,
				"issue " .. i .. " differs"
			)
		end
	end,

	["every issue points at a real tooth or gap"] = function()
		for seed = 1, 100 do
			for _, rarity in { "Common", "Rare", "VIP", "Zombie" } do
				local m = gen(seed, rarity, true)
				for _, issue in m.issues do
					local max = if issue.kind == "debris" then m.teeth - 2 else m.teeth
					assert(
						issue.toothId >= 1 and issue.toothId <= max,
						`{rarity} seed {seed}: toothId {issue.toothId}`
					)
				end
			end
		end
	end,

	["no tooth carries two problems (dirt, chip, rot)"] = function()
		for seed = 1, 100 do
			local seen: { [number]: boolean } = {}
			for _, issue in gen(seed, "Zombie", true).issues do
				if issue.kind ~= "debris" then
					assert(not seen[issue.toothId], "tooth reused at seed " .. seed)
					seen[issue.toothId] = true
				end
			end
		end
	end,

	["rot never appears while pliers are locked"] = function()
		for seed = 1, 200 do
			for _, issue in gen(seed, "Zombie", false).issues do
				assert(issue.kind ~= "rot", "rot with pliers locked, seed " .. seed)
			end
		end
	end,

	["a zombie mouth is much worse than a common one"] = function()
		for seed = 1, 50 do
			local z, c = #gen(seed, "Zombie", false).issues, #gen(seed, "Common", false).issues
			assert(z >= 14, "zombie only " .. z)
			assert(c >= 1 and c <= 8, "common had " .. c)
		end
	end,

	["clean rejects the wrong tool, repeats and bad indexes"] = function()
		local m = fixed({ "dirt", "debris", "chip" })
		local ok, why = MouthModel.clean(m, 1, "Floss")
		assert(ok == false and why == "wrong tool", "wrong tool accepted")
		ok, why = MouthModel.clean(m, 1, "Toothbrush")
		assert(ok == true, "correct tool refused")
		ok, why = MouthModel.clean(m, 1, "Toothbrush")
		assert(ok == false and why == "already cleaned", "repeat accepted")
		for _, bad in { 0, 4, -1, 1.5, 0 / 0, "1", true } do
			ok, why = MouthModel.clean(m, bad, "Toothbrush")
			assert(ok == false and why == "bad index", "accepted index " .. tostring(bad))
		end
	end,

	["a mouth with nothing wrong counts as fully clean"] = function()
		assert(MouthModel.cleanedFraction({ seed = 0, teeth = 16, issues = {} }) == 1, "expected 1")
	end,

	["submit unlocks between 5/7 and 6/7 at the 0.80 threshold"] = function()
		local m = fixed({ "dirt", "dirt", "dirt", "dirt", "dirt", "debris", "chip" })
		for i = 1, 5 do
			assert(MouthModel.clean(m, i, "Toothbrush"), "clean " .. i)
		end
		assert(MouthModel.canSubmit(m, cfg.submitThreshold) == false, "5/7 = 71% must stay locked")
		assert(MouthModel.clean(m, 6, "Floss"), "floss")
		assert(MouthModel.canSubmit(m, cfg.submitThreshold) == true, "6/7 = 86% must unlock")
	end,

	["remaining counts what each tool still has to fix"] = function()
		local m = fixed({ "dirt", "dirt", "debris", "chip", "rot" })
		MouthModel.clean(m, 1, "Toothbrush")
		local r = MouthModel.remaining(m)
		assert(
			r.Toothbrush == 1 and r.Floss == 1 and r.Spatula == 1 and r.Pliers == 1,
			"wrong counts"
		)
	end,
}
