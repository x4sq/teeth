--!strict
local cfg = require("../src/shared/Config/GameConfig")
local PlayerDataModel = require("../src/shared/Core/PlayerDataModel")

return {
	["defaults give every tool level 1 and the default decor and colours"] = function()
		local d = PlayerDataModel.defaults(cfg)
		for _, tool in cfg.toolOrder do
			assert(d.toolLevels[tool] == 1, tool)
		end
		assert(d.tier == 0 and d.cash == 0 and d.goals.index == 1, "bad base")
		assert(d.customize.decor.DecorFloor1 == "Plant", "default plant missing")
		assert(d.customize.colors.Wall == "#CBE7EA", "default wall colour missing")
	end,

	["migrating nil, strings and numbers returns clean defaults"] = function()
		for _, junk in { 0, "save", true } do
			local d = PlayerDataModel.migrate(junk, cfg)
			assert(d.cash == 0 and d.tier == 0, "not defaults")
		end
		assert(PlayerDataModel.migrate(nil, cfg).goals.index == 1, "nil")
	end,

	["negative, nan and absurd numbers are repaired"] = function()
		local d =
			PlayerDataModel.migrate({ cash = -50, tier = 99, dentists = 500, treated = 0 / 0 }, cfg)
		assert(d.cash == 0, "negative cash")
		assert(d.tier == 3, "tier not clamped")
		assert(d.dentists == cfg.tiers[3].maxDentists, "dentists not clamped to the tier")
		assert(d.treated == 0, "nan treated")
		assert(PlayerDataModel.migrate({ cash = 1e300 }, cfg).cash <= 1e15, "cash cap")
	end,

	["tool levels are clamped to 1..max and missing ones default"] = function()
		local d = PlayerDataModel.migrate({ toolLevels = { Spatula = 999, Floss = -4 } }, cfg)
		assert(d.toolLevels.Spatula == cfg.maxToolLevel, "no upper clamp")
		assert(d.toolLevels.Floss == 1, "no lower clamp")
		assert(d.toolLevels.Toothbrush == 1, "missing tool")
	end,

	["unknown keys are dropped and bad customisation is discarded"] = function()
		local d = PlayerDataModel.migrate({
			hacked = true,
			customize = {
				colors = { Wall = "#abcdef", Floor = "nope" },
				decor = { DecorFloor1 = "GoldBar", DecorWall1 = "Clock" },
				owned = { Clock = true, junk = 5 },
			},
		}, cfg)
		assert((d :: any).hacked == nil, "unknown key kept")
		assert(d.customize.colors.Wall == "#ABCDEF", "hex not uppercased")
		assert(d.customize.colors.Floor == cfg.defaultColors.Floor, "bad colour kept")
		assert(
			d.customize.decor.DecorFloor1 == nil and d.customize.decor.DecorWall1 == "Clock",
			"decor repair"
		)
		assert(d.customize.owned.Clock == true and d.customize.owned.junk == nil, "owned repair")
	end,

	["valid data survives a round trip unchanged"] = function()
		local d = PlayerDataModel.defaults(cfg)
		d.cash, d.tier, d.dentists = 12345, 2, 3
		d.toolLevels.Spatula = 4
		local again = PlayerDataModel.migrate(d, cfg)
		assert(
			again.cash == 12345
				and again.tier == 2
				and again.dentists == 3
				and again.toolLevels.Spatula == 4,
			"lost data"
		)
	end,

	["purchase receipts are kept and junk receipts are dropped"] = function()
		local raw: any = { receipts = { ["abc"] = true, ["bad"] = 5, [1] = true } }
		local d = PlayerDataModel.migrate(raw, cfg)
		assert(d.receipts.abc == true, "valid receipt lost")
		assert(d.receipts.bad == nil and d.receipts[1 :: any] == nil, "junk receipt kept")
	end,

	["the receipt list is bounded"] = function()
		local raw: any = { receipts = {} }
		for i = 1, 300 do
			raw.receipts["id" .. i] = true
		end
		local n = 0
		for _ in PlayerDataModel.migrate(raw, cfg).receipts do
			n += 1
		end
		assert(n <= 100, "receipts unbounded: " .. n)
	end,
}
