--!strict
local Staff = require("../src/shared/Core/Staff")

return {
	["no dentists, no time or no rate earns nothing"] = function()
		assert(Staff.earnings(100, 0, 4, 1000) == 0, "0 dentists")
		assert(Staff.earnings(0, 2, 4, 1000) == 0, "0 time")
		assert(Staff.earnings(100, 2, 0, 1000) == 0, "0 rate")
	end,

	["negative or nan input earns nothing"] = function()
		assert(Staff.earnings(-50, 2, 4, 1000) == 0, "negative elapsed")
		assert(Staff.earnings(0 / 0, 2, 4, 1000) == 0, "nan elapsed")
		assert(Staff.earnings(50, 0 / 0, 4, 1000) == 0, "nan dentists")
	end,

	["below the cap it is dentists x rate x elapsed"] = function()
		assert(Staff.earnings(100, 2, 4, 1000) == 800, "expected 800")
	end,

	["a long absence is clamped to the cap"] = function()
		assert(Staff.earnings(10 ^ 9, 2, 4, 1000) == 8000, "cap not applied")
		assert(Staff.earnings(1000, 2, 4, 1000) == Staff.earnings(5000, 2, 4, 1000), "cap boundary")
	end,
}
