--!strict
-- Goals - the ordered goal ladder shown on the HUD. Pure: state in, state out.

local Goals = {}

local RANK: { [string]: number } = { Common = 1, Rare = 2, VIP = 3, Zombie = 4 }

export type State = { index: number, progress: number, done: number }

--- The goal definition for `index` (1-based). Past the authored list, goals become "Treat N patients".
function Goals.def(index: number, cfg: any): any
	local list = cfg.goals
	if index <= #list then
		return list[index]
	end
	local k = index - #list
	local target = 10 + 10 * k
	return {
		text = `Treat {target} patients`,
		kind = "treated",
		target = target,
		reward = 1000 + 1000 * k,
	}
end

--- Apply one event. Returns the SAME table when the event is irrelevant.
function Goals.progress(state: State, event: any, cfg: any): State
	local def = Goals.def(state.index, cfg)
	if event.kind ~= def.kind then
		return state
	end
	if def.rarity and (RANK[event.rarity or "Common"] or 1) < RANK[def.rarity] then
		return state
	end
	if def.tool and event.tool ~= def.tool then
		return state
	end
	if def.tier and (event.tier or 0) < def.tier then
		return state
	end
	local amount = event.amount or 1
	if amount ~= amount or amount <= 0 then
		return state
	end
	return {
		index = state.index,
		progress = math.min(def.target, state.progress + amount),
		done = state.done,
	}
end

function Goals.completed(state: State, cfg: any): boolean
	return state.progress >= Goals.def(state.index, cfg).target
end

--- Move to the next goal (call after paying the reward).
function Goals.advance(state: State): State
	return { index = state.index + 1, progress = 0, done = state.done + 1 }
end

--- Goals about owning something are met the moment they appear if the player already has it.
function Goals.alreadyDone(def: any, data: { tier: number, dentists: number }): boolean
	if def.kind == "expand" and def.tier then
		return data.tier >= def.tier
	end
	if def.kind == "hire" then
		return data.dentists >= 1
	end
	return false
end

return Goals
