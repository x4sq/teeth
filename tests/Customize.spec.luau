--!strict
local cfg = require("../src/shared/Config/GameConfig")
local Customize = require("../src/shared/Core/Customize")

local function bad(payload: any, owned: any?, expect: string?)
	local ok, why = Customize.validate(payload, owned or {}, cfg)
	assert(ok == false, "accepted: " .. tostring(why))
	if expect then
		assert(why == expect, `wanted "{expect}", got "{why}"`)
	end
end

return {
	["a normal colour and decor change is accepted"] = function()
		local ok, why = Customize.validate({
			colors = { Wall = "#F7D6E0" },
			decor = { DecorFloor2 = "WaterCooler", DecorWall2 = "Clock" },
		}, {}, cfg)
		assert(ok, tostring(why))
	end,

	["an empty payload and clearing a slot are fine"] = function()
		assert(Customize.validate({}, {}, cfg), "empty")
		assert(Customize.validate({ decor = { DecorFloor1 = "" } }, {}, cfg), "clear slot")
	end,

	["non-tables and unknown fields are rejected"] = function()
		for _, junk in { 1, "x", true, 0 / 0 } do
			bad(junk, nil, "payload must be a table")
		end
		bad({ cash = 999999 }, nil, "unknown field")
	end,

	["unknown slots and unknown items are rejected"] = function()
		bad({ colors = { Ceiling = "#FFFFFF" } }, nil, "unknown color slot")
		bad({ decor = { DecorFloor9 = "Plant" } }, nil, "unknown decor slot")
		bad({ decor = { DecorFloor1 = "GoldBar" } }, nil, "unknown decor item")
	end,

	["colours must be #RRGGBB and a known swatch"] = function()
		bad({ colors = { Wall = "red" } }, nil, "color must be #RRGGBB")
		bad({ colors = { Wall = "#12345" } }, nil, "color must be #RRGGBB")
		bad({ colors = { Wall = "#123456" } }, nil, "unknown swatch")
		bad({ colors = { Wall = 16711680 } }, nil, "color must be #RRGGBB")
	end,

	["a floor item cannot go on a wall slot, or the reverse"] = function()
		bad({ decor = { DecorWall1 = "Plant" } }, nil, "item does not fit that slot")
		bad({ decor = { DecorFloor1 = "Poster" } }, nil, "item does not fit that slot")
	end,

	["oversized strings and tables are rejected"] = function()
		bad(
			{ decor = { DecorFloor1 = string.rep("a", 200) } },
			nil,
			"decor id must be a short string"
		)
		local many = {}
		for i = 1, 40 do
			many["DecorFloor" .. i] = "Plant"
		end
		bad({ decor = many })
	end,

	["purchases lists only newly needed paid items and sums their cost"] = function()
		local payload = {
			colors = { Wall = "#F7D6E0", Floor = "#FFFFFF" },
			decor = { DecorFloor2 = "WaterCooler", DecorFloor1 = "Plant" },
		}
		local ids, total = Customize.purchases(payload, {}, cfg)
		assert(#ids == 2 and total == 300 + 400, `ids {#ids}, total {total}`)
		ids, total = Customize.purchases(payload, { ["#F7D6E0"] = true, WaterCooler = true }, cfg)
		assert(#ids == 0 and total == 0, "owned items charged again")
	end,
}
