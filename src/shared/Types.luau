--!strict
-- Types - the shared vocabulary. Plain data only; no behaviour here.

export type ToolId = "Toothbrush" | "Floss" | "Spatula" | "Pliers"
export type IssueKind = "dirt" | "debris" | "chip" | "rot"
export type Rarity = "Common" | "Rare" | "VIP" | "Zombie"

export type Issue = { toothId: number, kind: IssueKind, cleaned: boolean }
export type Mouth = { seed: number, teeth: number, issues: { Issue } }

export type GoalEvent = {
	kind: string, -- "treated" | "chip" | "upgrade" | "expand" | "hire" | "customize"
	amount: number?,
	rarity: Rarity?,
	tool: ToolId?,
	tier: number?,
}
export type GoalDef = {
	text: string,
	kind: string,
	target: number,
	reward: number,
	rarity: Rarity?, -- "at least this rare"
	tool: ToolId?,
	tier: number?,
}
export type GoalState = { index: number, progress: number, done: number }

export type CustomizeState = {
	colors: { [string]: string }, -- slot -> "#RRGGBB"
	decor: { [string]: string }, -- decor slot -> decor id
	owned: { [string]: boolean }, -- decor ids and colour swatches bought
}

export type PlayerData = {
	version: number,
	cash: number,
	toolLevels: { [string]: number },
	tier: number,
	dentists: number,
	treated: number,
	goals: GoalState,
	customize: CustomizeState,
	lastSeen: number,
	lastPlaytimeClaim: number,
	receipts: { [string]: boolean }, -- Robux purchase ids already granted (idempotency)
}

local Types = {}

-- the tool that fixes each kind of issue
Types.ToolForIssue = {
	dirt = "Toothbrush",
	debris = "Floss",
	chip = "Spatula",
	rot = "Pliers",
} :: { [string]: string }

Types.RarityRank = { Common = 1, Rare = 2, VIP = 3, Zombie = 4 } :: { [string]: number }

return Types
