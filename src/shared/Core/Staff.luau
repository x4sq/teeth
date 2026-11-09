--!strict
-- Staff - what hired dentists earn while the owner is away. Pure.

local Staff = {}

--- Cash earned over `elapsedSeconds`, capped at `capSeconds` of work. Bad input earns nothing.
function Staff.earnings(
	elapsedSeconds: number,
	dentists: number,
	ratePerDentist: number,
	capSeconds: number
): number
	if
		elapsedSeconds ~= elapsedSeconds
		or dentists ~= dentists
		or ratePerDentist ~= ratePerDentist
	then
		return 0
	end
	if elapsedSeconds <= 0 or dentists <= 0 or ratePerDentist <= 0 then
		return 0
	end
	return math.floor(dentists * ratePerDentist * math.min(elapsedSeconds, capSeconds))
end

return Staff
