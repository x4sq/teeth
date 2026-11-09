--!strict
-- Rng - a tiny deterministic xorshift32 generator with the same method names as Roblox's `Random`.
-- Core modules use this instead of `Random` so they run (and test) identically under Lune and in Studio.

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { s: number }, Rng))

function Rng.new(seed: number): Rng
	local s = 0
	if seed == seed and seed ~= math.huge and seed ~= -math.huge then
		s = math.floor(math.abs(seed)) % 4294967296
	end
	if s == 0 then
		s = 0x9E3779B9
	end
	return setmetatable({ s = s }, Rng)
end

--- Next float in [0, 1).
function Rng.NextNumber(self: Rng): number
	local x = self.s
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.s = x
	return x / 4294967296
end

--- Integer in [lo, hi] inclusive.
function Rng.NextInteger(self: Rng, lo: number, hi: number): number
	if hi < lo then
		lo, hi = hi, lo
	end
	return lo + math.floor(Rng.NextNumber(self) * (hi - lo + 1))
end

return Rng
