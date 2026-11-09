--!strict
local Rng = require("../src/shared/Core/Rng")

return {
	["same seed gives the same sequence"] = function()
		local a, b = Rng.new(42), Rng.new(42)
		for _ = 1, 50 do
			assert(a:NextNumber() == b:NextNumber(), "sequences diverged")
		end
	end,

	["NextNumber stays in [0, 1)"] = function()
		local r = Rng.new(1)
		for _ = 1, 1000 do
			local v = r:NextNumber()
			assert(v >= 0 and v < 1, "out of range: " .. v)
		end
	end,

	["NextInteger is inclusive and reaches both ends"] = function()
		local r = Rng.new(9)
		local sawLo, sawHi = false, false
		for _ = 1, 500 do
			local v = r:NextInteger(3, 6)
			assert(v >= 3 and v <= 6 and v % 1 == 0, "bad value " .. v)
			sawLo = sawLo or v == 3
			sawHi = sawHi or v == 6
		end
		assert(sawLo and sawHi, "never hit an endpoint")
	end,

	["zero, nan and infinite seeds still produce numbers"] = function()
		for _, seed in { 0, 0 / 0, math.huge, -math.huge } do
			local v = Rng.new(seed):NextNumber()
			assert(v >= 0 and v < 1, "bad output for seed " .. tostring(seed))
		end
	end,
}
