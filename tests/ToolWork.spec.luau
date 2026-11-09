local ToolWork = require("../src/shared/Core/ToolWork")
local GameConfig = require("../src/shared/Config/GameConfig")
local cfg = GameConfig.minigame

return {
	["all 16 teeth and 14 gaps sit inside the stage, upper row above lower"] = function()
		for id = 1, 16 do
			local x, y = ToolWork.toothCentre(id)
			assert(x > ToolWork.TOOTH_W / 2 and x < ToolWork.STAGE_W - ToolWork.TOOTH_W / 2)
			assert(y > 0 and y < ToolWork.STAGE_H)
		end
		local _, upperY = ToolWork.toothCentre(1)
		local _, lowerY = ToolWork.toothCentre(9)
		assert(upperY < lowerY)
		for g = 1, 14 do
			local x, y = ToolWork.gapCentre(g)
			local left = if g <= 7 then g else g + 1
			local lx, ly = ToolWork.toothCentre(left)
			local rx = ToolWork.toothCentre(left + 1)
			assert(x > lx and x < rx and y == ly, "gap sits between its two teeth")
		end
	end,
	["neighbouring teeth do not overlap"] = function()
		local a = ToolWork.toothCentre(1)
		local b = ToolWork.toothCentre(2)
		assert(b - a >= ToolWork.TOOTH_W)
	end,
	["floss only works up and down"] = function()
		assert(ToolWork.advance("debris", true, 500, 0, 0, 1, cfg) == 0)
		assert(ToolWork.advance("debris", true, 0, -50, 0, 1, cfg) > 0)
	end,
	["a rotten tooth pulls out of its gum and can be pushed back"] = function()
		assert(ToolWork.advance("rot", true, 0, 30, 0, 1, cfg) > 0, "upper teeth pull down")
		assert(ToolWork.advance("rot", false, 0, -30, 0, 1, cfg) > 0, "lower teeth pull up")
		assert(ToolWork.advance("rot", true, 0, -30, 0, 1, cfg) < 0)
	end,
	["filling takes holding time, not movement"] = function()
		assert(ToolWork.advance("chip", true, 900, 900, 0, 1, cfg) == 0)
		local p = ToolWork.advance("chip", true, 0, 0, cfg.fillSeconds, 1, cfg)
		assert(math.abs(p - 1) < 1e-9)
	end,
	["tool level speeds work up, within the cap, and bad levels count as level 1"] = function()
		assert(ToolWork.speed(1, cfg) == 1)
		assert(ToolWork.speed(3, cfg) > ToolWork.speed(2, cfg))
		assert(ToolWork.speed(1e9, cfg) == cfg.maxSpeed)
		assert(ToolWork.speed(nil, cfg) == 1 and ToolWork.speed(0 / 0, cfg) == 1)
		assert(ToolWork.speed(-5, cfg) == 1)
	end,
	["the pointer must be on the problem"] = function()
		local x, y = ToolWork.toothCentre(4)
		assert(ToolWork.inReach("dirt", x, y, x + 10, y - 10))
		assert(not ToolWork.inReach("dirt", x, y, x + 200, y))
		local gx, gy = ToolWork.gapCentre(4)
		assert(ToolWork.inReach("debris", gx, gy, gx, gy + 30))
		assert(not ToolWork.inReach("debris", gx, gy, gx + 25, gy), "the gap is narrow")
	end,
}
