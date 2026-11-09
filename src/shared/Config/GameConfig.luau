--!strict
-- GameConfig - every tunable in the game, in one place.
--
-- A number that a designer might want to change must live here, never inline in
-- a Service or Controller. A balance pass is a data edit.
-- Observed in the reference game (see docs/superpowers/specs): submit button grey at 71 %,
-- green at 83 %; a common patient pays about $20 per cleaned tooth; Zombie patient = 30 s timer.

local GameConfig = {
	MaxPlayers = 6,
	PlotCount = 6,

	-- Treatment
	submitThreshold = 0.80,
	perfectBonus = 0.35, -- of the summed per-issue pay, when every issue is cleaned
	partialBonus = 0.10, -- when submitted between threshold and 100 %
	zombieSeconds = 30,
	patientWaitSeconds = 120, -- a seated patient leaves if nobody treats them
	minSecondsBetweenCleans = 0.08, -- server-side plausibility floor (also rate-limited)
	cleanRate = { perSecond = 10, burst = 6 },
	-- How much hand work each problem takes at tool level 1 (see Core/ToolWork).
	minigame = {
		scrubPixels = 420, -- brush travel over one dirty tooth
		flossPixels = 260, -- up-and-down floss travel in one gap (about three passes)
		fillSeconds = 1.4, -- holding the filler on a chip
		pullPixels = 90, -- dragging a rotten tooth out of the gum
		speedPerLevel = 0.12, -- each tool level works this much faster
		maxSpeed = 2.5,
	},

	basePay = { dirt = 20, debris = 24, chip = 40, rot = 60 },
	rarityMultiplier = { Common = 1, Rare = 3, VIP = 6, Zombie = 20 },
	toolPayPerLevel = 0.5, -- each tool level adds this fraction to the base pay

	-- Mouth generation: {min, max} issues of each kind per rarity
	teethPerMouth = 16,
	mouthProfiles = {
		Common = { dirt = { 3, 5 }, debris = { 0, 2 }, chip = { 0, 1 }, rot = { 0, 0 } },
		Rare = { dirt = { 5, 7 }, debris = { 1, 3 }, chip = { 1, 2 }, rot = { 0, 1 } },
		VIP = { dirt = { 6, 8 }, debris = { 2, 4 }, chip = { 1, 2 }, rot = { 0, 1 } },
		Zombie = { dirt = { 8, 10 }, debris = { 5, 7 }, chip = { 1, 2 }, rot = { 1, 2 } },
	},

	-- Patients
	rarityWeights = { Common = 80, Rare = 14, VIP = 5, Zombie = 1 },
	luckShift = { Common = -0.5, Rare = 2, VIP = 3, Zombie = 4 }, -- weight *= 1 + luck * shift
	spawnDelay = 30,
	spawnDelayStepPerTier = 5,
	minSpawnDelay = 8,
	walkSpeed = 12,

	-- Tools
	toolOrder = { "Toothbrush", "Floss", "Spatula", "Pliers" },
	toolNames = {
		Toothbrush = "Toothbrush",
		Floss = "Floss",
		Spatula = "Filler Spatula",
		Pliers = "Pliers",
	},
	toolBaseCost = { Toothbrush = 300, Floss = 500, Spatula = 600, Pliers = 1200 },
	toolCostGrowth = 3.5,
	maxToolLevel = 10,

	-- Clinic tiers (index 0..3)
	tiers = {
		[0] = { name = "Starter Clinic", chairs = 1, cost = 0, maxDentists = 1 },
		[1] = { name = "Family Practice", chairs = 3, cost = 2500, maxDentists = 3 },
		[2] = { name = "Dental Center", chairs = 5, cost = 25000, maxDentists = 5 },
		[3] = { name = "Dental Tower", chairs = 8, cost = 250000, maxDentists = 8 },
	},
	pliersUnlockChairs = 2, -- "Unlocks at Chair 2"

	-- Staff
	hireBaseCost = 1500,
	hireCostGrowth = 2.2,
	staffCashPerSecond = 4, -- per dentist, at a Common patient rate; scales with tier
	staffCapSeconds = 8 * 60 * 60,

	-- Rewards
	playtimeRewardSeconds = 600,
	playtimeRewardBase = 500,

	-- Goals, in order. After the last one the list repeats with rewards scaled up.
	goals = {
		{ text = "Treat 3 patients", kind = "treated", target = 3, reward = 600 },
		{
			text = "Upgrade your Filler",
			kind = "upgrade",
			target = 1,
			reward = 300,
			tool = "Spatula",
		},
		{ text = "Fix 3 chipped teeth", kind = "chip", target = 3, reward = 400 },
		{
			text = "Treat a Rare patient",
			kind = "treated",
			target = 1,
			reward = 500,
			rarity = "Rare",
		},
		{
			text = "Expand to the Family Practice",
			kind = "expand",
			target = 1,
			reward = 1500,
			tier = 1,
		},
		{ text = "Hire a dentist", kind = "hire", target = 1, reward = 800 },
		{
			text = "Cure a Zombie patient",
			kind = "treated",
			target = 1,
			reward = 2000,
			rarity = "Zombie",
		},
		{ text = "Customize your clinic", kind = "customize", target = 1, reward = 2000 },
		{ text = "Treat 25 patients", kind = "treated", target = 25, reward = 5000 },
		{ text = "Reach the Dental Center", kind = "expand", target = 1, reward = 20000, tier = 2 },
	},
	goalRepeatScale = 1.6,

	-- Customization
	colorSlots = { "Floor", "Wall", "Trim", "Upholstery", "DeskBody", "Door" },
	colorPalette = {
		-- hex swatches, free ones first; cost 0 = free
		{ hex = "#ECF3F6", cost = 0, name = "Porcelain" },
		{ hex = "#CBE7EA", cost = 0, name = "Mint" },
		{ hex = "#FFFFFF", cost = 0, name = "Cloud" },
		{ hex = "#F7D6E0", cost = 300, name = "Blush" },
		{ hex = "#FFE8A3", cost = 300, name = "Butter" },
		{ hex = "#B8D8F8", cost = 300, name = "Sky" },
		{ hex = "#C9F0C2", cost = 300, name = "Pistachio" },
		{ hex = "#2EAAB5", cost = 0, name = "Teal" },
		{ hex = "#1C707C", cost = 0, name = "Deep teal" },
		{ hex = "#FF7A6B", cost = 500, name = "Coral" },
		{ hex = "#8E6BD8", cost = 500, name = "Violet" },
		{ hex = "#3A4450", cost = 500, name = "Slate" },
		{ hex = "#E9B949", cost = 800, name = "Gold" },
	},
	defaultColors = {
		Floor = "#ECF3F6",
		Wall = "#CBE7EA",
		Trim = "#1C707C",
		Upholstery = "#2EAAB5",
		DeskBody = "#1C707C",
		Door = "#1C707C",
	},
	maxDecorSlots = 8,
	decorSlots = {
		"DecorFloor1",
		"DecorFloor2",
		"DecorFloor3",
		"DecorFloor4",
		"DecorWall1",
		"DecorWall2",
		"DecorWall3",
		"DecorWall4",
	},
	decor = {
		Plant = { name = "Potted Plant", kind = "floor", cost = 0 },
		WaterCooler = { name = "Water Cooler", kind = "floor", cost = 400 },
		ToothStatue = { name = "Tooth Statue", kind = "floor", cost = 1500 },
		Shelf = { name = "Shelf", kind = "floor", cost = 250 },
		Poster = { name = "Smile Poster", kind = "wall", cost = 0 },
		Clock = { name = "Wall Clock", kind = "wall", cost = 200 },
		Banner = { name = "Teal Banner", kind = "wall", cost = 350 },
		Diploma = { name = "Diploma", kind = "wall", cost = 600 },
	},
	defaultDecor = { DecorFloor1 = "Plant", DecorWall1 = "Poster" },

	-- Robux products. 0 = not created yet, so the matching shop button shows "Soon".
	-- Create these in the Creator Dashboard, then put the real ids here.
	products = {
		DoubleCashPass = 0, -- game pass: permanent 2x cash
		InstantClean = 0, -- developer product: finish the open treatment now
		CashBoost10m = 0, -- developer product: 2x cash for 10 minutes
		StarterBundle = 0, -- developer product: cash + a free upgrade
	},
	cashBoostSeconds = 600,
	starterBundleCash = 5000,

	sessionKey = "TeethTycoon_v1",
}

return GameConfig
