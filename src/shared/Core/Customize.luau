--!strict
-- Customize - validating what the player asks to change about their clinic. Pure.
-- Payload shape: { colors = { [slot]: "#RRGGBB" }, decor = { [decorSlot]: decorId | "" } }
-- `owned` is { [decorId or "#RRGGBB"]: true } for things already bought.

local Customize = {}

local HEX = "^#%x%x%x%x%x%x$"
local MAX_STRING = 32

local function isString(v: any): boolean
	return type(v) == "string" and #v <= MAX_STRING
end

local function swatch(hex: string, cfg: any): any?
	local upper = hex:upper()
	for _, s in cfg.colorPalette do
		if s.hex:upper() == upper then
			return s
		end
	end
	return nil
end

local function contains(list: { string }, value: string): boolean
	return table.find(list, value) ~= nil
end

--- True if the payload is well formed and only uses things the player may use (free or owned or buyable).
--- Buying is a separate step (`purchases`); this only rejects malformed or unknown input.
function Customize.validate(
	payload: any,
	_owned: { [string]: boolean }, -- ownership is settled by `purchases`, not here
	cfg: any
): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "payload must be a table"
	end
	for key in payload do
		if key ~= "colors" and key ~= "decor" then
			return false, "unknown field"
		end
	end
	local colors = payload.colors
	if colors ~= nil then
		if type(colors) ~= "table" then
			return false, "colors must be a table"
		end
		local count = 0
		for slot, hex in colors do
			count += 1
			if count > #cfg.colorSlots then
				return false, "too many colors"
			end
			if not isString(slot) or not contains(cfg.colorSlots, slot) then
				return false, "unknown color slot"
			end
			if not isString(hex) or not string.match(hex, HEX) then
				return false, "color must be #RRGGBB"
			end
			if swatch(hex, cfg) == nil then
				return false, "unknown swatch"
			end
		end
	end
	local decor = payload.decor
	if decor ~= nil then
		if type(decor) ~= "table" then
			return false, "decor must be a table"
		end
		local count = 0
		for slot, id in decor do
			count += 1
			if count > cfg.maxDecorSlots then
				return false, "too many decor entries"
			end
			if not isString(slot) or not contains(cfg.decorSlots, slot) then
				return false, "unknown decor slot"
			end
			if not isString(id) then
				return false, "decor id must be a short string"
			end
			if id ~= "" then
				local item = cfg.decor[id]
				if item == nil then
					return false, "unknown decor item"
				end
				local wantsFloor = slot:sub(1, 10) == "DecorFloor"
				if (item.kind == "floor") ~= wantsFloor then
					return false, "item does not fit that slot"
				end
			end
		end
	end
	return true, nil
end

--- What this payload would cost: ids newly needing purchase, and the total. Call after `validate`.
function Customize.purchases(
	payload: any,
	owned: { [string]: boolean },
	cfg: any
): ({ string }, number)
	local ids: { string } = {}
	local total = 0
	for _, hex in payload.colors or {} do
		local key = hex:upper()
		local s = swatch(hex, cfg)
		if s and s.cost > 0 and not owned[key] and not table.find(ids, key) then
			table.insert(ids, key)
			total += s.cost
		end
	end
	for _, id in payload.decor or {} do
		local item = id ~= "" and cfg.decor[id] or nil
		if item and item.cost > 0 and not owned[id] and not table.find(ids, id) then
			table.insert(ids, id)
			total += item.cost
		end
	end
	return ids, total
end

return Customize
