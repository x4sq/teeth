--!strict
local cfg = require("../src/shared/Config/GameConfig")
local Goals = require("../src/shared/Core/Goals")

local function at(index: number, progress: number?)
	return { index = index, progress = progress or 0, done = index - 1 }
end

return {
	["'Treat 3 patients' completes on the third and never over-counts"] = function()
		local s = at(1)
		for _ = 1, 3 do
			s = Goals.progress(s, { kind = "treated", rarity = "Common" }, cfg)
		end
		assert(Goals.completed(s, cfg), "not complete after 3")
		s = Goals.progress(s, { kind = "treated" }, cfg)
		assert(s.progress == 3, "over-counted to " .. s.progress)
	end,

	["unrelated events return the very same state"] = function()
		local s = at(1)
		assert(Goals.progress(s, { kind = "hire" }, cfg) == s, "hire changed the treat goal")
	end,

	["the 'Rare patient' goal ignores Common and counts Rare or better"] = function()
		local s = at(4)
		assert(
			Goals.progress(s, { kind = "treated", rarity = "Common" }, cfg) == s,
			"common counted"
		)
		assert(
			Goals.completed(Goals.progress(s, { kind = "treated", rarity = "VIP" }, cfg), cfg),
			"vip not counted"
		)
	end,

	["the upgrade goal only counts the Spatula"] = function()
		local s = at(2)
		assert(Goals.progress(s, { kind = "upgrade", tool = "Floss" }, cfg) == s, "floss counted")
		assert(
			Goals.completed(Goals.progress(s, { kind = "upgrade", tool = "Spatula" }, cfg), cfg),
			"spatula ignored"
		)
	end,

	["an expand goal needs the right tier"] = function()
		local s = at(5)
		assert(
			Goals.progress(s, { kind = "expand", tier = 0 }, cfg) == s,
			"tier 0 counted for tier 1 goal"
		)
		assert(
			Goals.completed(Goals.progress(s, { kind = "expand", tier = 1 }, cfg), cfg),
			"tier 1 ignored"
		)
	end,

	["zero, negative and nan amounts change nothing"] = function()
		local s = at(1)
		for _, a in { 0, -3, 0 / 0 } do
			assert(
				Goals.progress(s, { kind = "treated", amount = a }, cfg) == s,
				"amount " .. tostring(a)
			)
		end
	end,

	["advance moves to the next goal and counts the finished one"] = function()
		local n = Goals.advance(at(3, 3))
		assert(n.index == 4 and n.progress == 0 and n.done == 3, "bad advance")
	end,

	["goals past the authored list become bigger 'Treat N patients' goals"] = function()
		local last = #cfg.goals
		local a, b = Goals.def(last + 1, cfg), Goals.def(last + 2, cfg)
		assert(
			a.kind == "treated" and b.target > a.target and b.reward > a.reward,
			"ladder does not grow"
		)
	end,

	["owning-type goals are already met by a player who has the thing"] = function()
		local expandDef = Goals.def(5, cfg)
		assert(
			Goals.alreadyDone(expandDef, { tier = 1, dentists = 0 }) == true,
			"tier 1 owner not recognised"
		)
		assert(
			Goals.alreadyDone(expandDef, { tier = 0, dentists = 0 }) == false,
			"tier 0 recognised"
		)
		assert(
			Goals.alreadyDone(Goals.def(6, cfg), { tier = 0, dentists = 1 }) == true,
			"dentist owner not recognised"
		)
	end,
}
