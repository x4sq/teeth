--!strict
-- PlayerDataModel - the shape of saved data, its defaults, and a migration that repairs anything
-- missing or out of range. Pure. Whatever comes out of a DataStore goes through `migrate` first.

local PlayerDataModel = {}

local VERSION = 1
local MAX_CASH = 1e15

local function num(v: any, fallback: number, lo: number, hi: number): number
	if type(v) ~= "number" or v ~= v then
		return fallback
	end
	return math.clamp(v, lo, hi)
end

function PlayerDataModel.defaults(cfg: any): any
	local levels = {}
	for _, tool in cfg.toolOrder do
		levels[tool] = 1
	end
	local decor = table.clone(cfg.defaultDecor)
	local colors = table.clone(cfg.defaultColors)
	return {
		version = VERSION,
		cash = 0,
		toolLevels = levels,
		tier = 0,
		dentists = 0,
		treated = 0,
		goals = { index = 1, progress = 0, done = 0 },
		customize = { colors = colors, decor = decor, owned = {} },
		lastSeen = 0,
		lastPlaytimeClaim = 0,
		receipts = {},
	}
end

--- Repair arbitrary saved data into valid PlayerData. Unknown keys are dropped; bad values reset.
function PlayerDataModel.migrate(raw: any, cfg: any): any
	local out = PlayerDataModel.defaults(cfg)
	if type(raw) ~= "table" then
		return out
	end
	out.cash = math.floor(num(raw.cash, 0, 0, MAX_CASH))
	out.tier = math.floor(num(raw.tier, 0, 0, 3))
	out.dentists = math.floor(num(raw.dentists, 0, 0, cfg.tiers[out.tier].maxDentists))
	out.treated = math.floor(num(raw.treated, 0, 0, 1e9))
	out.lastSeen = num(raw.lastSeen, 0, 0, 1e12)
	out.lastPlaytimeClaim = num(raw.lastPlaytimeClaim, 0, 0, 1e12)
	if type(raw.receipts) == "table" then
		local kept = 0
		for id, v in raw.receipts do
			if v == true and type(id) == "string" and #id <= 64 and kept < 100 then
				out.receipts[id] = true
				kept += 1
			end
		end
	end
	if type(raw.toolLevels) == "table" then
		for _, tool in cfg.toolOrder do
			out.toolLevels[tool] = math.floor(num(raw.toolLevels[tool], 1, 1, cfg.maxToolLevel))
		end
	end
	if type(raw.goals) == "table" then
		out.goals = {
			index = math.floor(num(raw.goals.index, 1, 1, 1e6)),
			progress = math.floor(num(raw.goals.progress, 0, 0, 1e9)),
			done = math.floor(num(raw.goals.done, 0, 0, 1e6)),
		}
	end
	if type(raw.customize) == "table" then
		local c = raw.customize
		if type(c.colors) == "table" then
			for _, slot in cfg.colorSlots do
				local hex = c.colors[slot]
				if type(hex) == "string" and string.match(hex, "^#%x%x%x%x%x%x$") then
					out.customize.colors[slot] = hex:upper()
				end
			end
		end
		if type(c.decor) == "table" then
			out.customize.decor = {}
			for _, slot in cfg.decorSlots do
				local id = c.decor[slot]
				if type(id) == "string" and cfg.decor[id] then
					out.customize.decor[slot] = id
				end
			end
		end
		if type(c.owned) == "table" then
			for key, v in c.owned do
				if v == true and type(key) == "string" and #key <= 32 then
					out.customize.owned[key] = true
				end
			end
		end
	end
	return out
end

return PlayerDataModel
