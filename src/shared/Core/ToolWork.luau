--!strict
-- ToolWork - the hands-on rules of the mouth minigame: where each tooth and gap sits, whether the
-- pointer is on a problem, and how much one movement (or one moment of holding) gets done.
-- Pure numbers, no Instances; `cfg` is GameConfig.minigame. Each tool has its own motion:
--   dirt   (Toothbrush)  scrub in any direction over the tooth
--   debris (Floss)       slide up and down through the gap; sideways movement does nothing
--   chip   (Spatula)     hold still on the tooth while the filling sets
--   rot    (Pliers)      grab the tooth and pull it out of the gum (down for upper teeth, up for lower)

local ToolWork = {}

ToolWork.STAGE_W, ToolWork.STAGE_H = 600, 300
ToolWork.TOOTH_W, ToolWork.TOOTH_H = 54, 70
ToolWork.PER_ROW = 8
local PITCH = 62
local UPPER_Y, LOWER_Y = 92, 208

ToolWork.ToolFor = { dirt = "Toothbrush", debris = "Floss", chip = "Spatula", rot = "Pliers" }

function ToolWork.isUpper(kind: string, id: number): boolean
	return id <= (if kind == "debris" then ToolWork.PER_ROW - 1 else ToolWork.PER_ROW)
end

--- Centre of tooth `id` (1-8 upper row, 9-16 lower row) on the stage.
function ToolWork.toothCentre(id: number): (number, number)
	local upper = id <= ToolWork.PER_ROW
	local i = if upper then id else id - ToolWork.PER_ROW
	local x = ToolWork.STAGE_W / 2 + (i - (ToolWork.PER_ROW + 1) / 2) * PITCH
	return x, if upper then UPPER_Y else LOWER_Y
end

--- Centre of gap `g` (1-7 between upper teeth, 8-14 between lower teeth).
function ToolWork.gapCentre(g: number): (number, number)
	local upper = g <= ToolWork.PER_ROW - 1
	local left = if upper then g else g + 1
	local x, y = ToolWork.toothCentre(left)
	return x + PITCH / 2, y
end

function ToolWork.centre(kind: string, id: number): (number, number)
	if kind == "debris" then
		return ToolWork.gapCentre(id)
	end
	return ToolWork.toothCentre(id)
end

--- Higher tool levels work faster. Never below 1, capped by cfg.maxSpeed.
function ToolWork.speed(level: any, cfg: any): number
	local n = if type(level) == "number" and level == level then level else 1
	return math.clamp(1 + (n - 1) * cfg.speedPerLevel, 1, cfg.maxSpeed)
end

--- Is the pointer (px, py) on the problem centred at (cx, cy)?
function ToolWork.inReach(kind: string, cx: number, cy: number, px: number, py: number): boolean
	local halfW, halfH = ToolWork.TOOTH_W / 2, ToolWork.TOOTH_H / 2
	if kind == "debris" then
		return math.abs(px - cx) <= 18 and math.abs(py - cy) <= halfH + 10
	elseif kind == "dirt" then
		return math.abs(px - cx) <= halfW + 12 and math.abs(py - cy) <= halfH + 12
	end
	return math.abs(px - cx) <= halfW + 4 and math.abs(py - cy) <= halfH + 4
end

--- Progress (a share of 1) made by moving the pointer (dx, dy) or holding for dt seconds.
--- Only "rot" can return a negative number: pushing the tooth back in.
function ToolWork.advance(
	kind: string,
	upper: boolean,
	dx: number,
	dy: number,
	dt: number,
	speed: number,
	cfg: any
): number
	if kind == "dirt" then
		return math.sqrt(dx * dx + dy * dy) / cfg.scrubPixels * speed
	elseif kind == "debris" then
		return math.abs(dy) / cfg.flossPixels * speed
	elseif kind == "chip" then
		return dt / cfg.fillSeconds * speed
	elseif kind == "rot" then
		return (if upper then dy else -dy) / cfg.pullPixels * speed
	end
	return 0
end

return ToolWork
