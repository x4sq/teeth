--!strict
local RateLimit = require("../src/shared/Core/RateLimit")

return {
	["a burst of 5 passes and the 6th at the same instant is refused"] = function()
		local rl = RateLimit.new(10, 5)
		for i = 1, 5 do
			assert(rl:take("p", 0) == true, "take " .. i .. " refused")
		end
		assert(rl:take("p", 0) == false, "6th accepted")
	end,

	["tokens refill over time"] = function()
		local rl = RateLimit.new(10, 5)
		for _ = 1, 5 do
			rl:take("p", 0)
		end
		assert(rl:take("p", 0.05) == false, "refilled too early")
		assert(rl:take("p", 0.1) == true, "did not refill after 0.1s")
	end,

	["a flood of 50 in one instant lets through only the burst"] = function()
		local rl = RateLimit.new(10, 6)
		local passed = 0
		for _ = 1, 50 do
			if rl:take("p", 3) then
				passed += 1
			end
		end
		assert(passed == 6, "passed " .. passed)
	end,

	["keys are independent and can be forgotten"] = function()
		local rl = RateLimit.new(1, 1)
		assert(rl:take("a", 0) and rl:take("b", 0), "separate keys share a bucket")
		assert(rl:take("a", 0) == false, "a should be empty")
		rl:forget("a")
		assert(rl:take("a", 0) == true, "forget did not reset")
	end,

	["a clock that goes backwards never mints tokens"] = function()
		local rl = RateLimit.new(10, 1)
		assert(rl:take("p", 100) == true, "first")
		assert(rl:take("p", 50) == false, "time travel gave a token")
	end,
}
