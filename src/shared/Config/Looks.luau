--!strict
-- Looks - how each kind of patient is dressed. Roblox-only (uses Color3), so it has no Lune spec;
-- it is exercised by the Studio playtest. Colours only: no accessory or clothing asset ids to go stale.

local Looks = {}

export type Look = {
	label: string,
	nameTag: Color3,
	skin: { Color3 },
	shirt: { Color3 },
	pants: { Color3 },
}

local SKIN = {
	Color3.fromRGB(255, 220, 190),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(190, 137, 98),
	Color3.fromRGB(124, 84, 58),
}

Looks.ByRarity = {
	Common = {
		label = "COMMON",
		nameTag = Color3.fromRGB(235, 245, 248),
		skin = SKIN,
		shirt = {
			Color3.fromRGB(88, 140, 215),
			Color3.fromRGB(230, 120, 98),
			Color3.fromRGB(120, 190, 130),
			Color3.fromRGB(240, 200, 90),
		},
		pants = { Color3.fromRGB(60, 70, 96), Color3.fromRGB(88, 88, 96) },
	},
	Rare = {
		label = "RARE",
		nameTag = Color3.fromRGB(120, 190, 255),
		skin = SKIN,
		shirt = { Color3.fromRGB(70, 110, 230), Color3.fromRGB(110, 90, 220) },
		pants = { Color3.fromRGB(30, 40, 80) },
	},
	VIP = {
		label = "VIP",
		nameTag = Color3.fromRGB(255, 215, 90),
		skin = { Color3.fromRGB(246, 208, 120) }, -- gold
		shirt = { Color3.fromRGB(240, 190, 60) },
		pants = { Color3.fromRGB(50, 44, 30) },
	},
	Zombie = {
		label = "ZOMBIE",
		nameTag = Color3.fromRGB(140, 220, 110),
		skin = { Color3.fromRGB(122, 158, 90) },
		shirt = { Color3.fromRGB(70, 62, 52) },
		pants = { Color3.fromRGB(48, 44, 40) },
	},
} :: { [string]: Look }

--- A HumanoidDescription dressed for `rarity`; `rng` is anything with NextInteger.
function Looks.describe(
	rarity: string,
	rng: { NextInteger: (any, number, number) -> number }
): HumanoidDescription
	local look = Looks.ByRarity[rarity] or Looks.ByRarity.Common
	local function pick(list: { Color3 }): Color3
		return list[rng:NextInteger(1, #list)]
	end
	local skin, shirt, pants = pick(look.skin), pick(look.shirt), pick(look.pants)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
	desc.TorsoColor, desc.LeftLegColor, desc.RightLegColor = shirt, pants, pants
	return desc
end

return Looks
