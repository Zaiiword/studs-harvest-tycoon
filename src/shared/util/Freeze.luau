--!strict
-- Gel profond des tables de config (docs/CLEAN_CODE.md §2) : toute écriture accidentelle lève une erreur.

local Freeze = {}

function Freeze.deep<T>(value: T): T
	if type(value) ~= "table" or table.isfrozen(value :: any) then
		return value
	end
	for _, child in value :: any do
		Freeze.deep(child)
	end
	return table.freeze(value :: any) :: any
end

return Freeze
