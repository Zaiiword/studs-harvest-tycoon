--!strict
-- Rythme des Rebirths (A70) : lune run tests/tools/pacing.luau
-- Affiche, pour un joueur prudent (sans Pet) et pour un joueur « réel » (Pets, cadeaux, Retour Base), l'instant de
-- chaque palier, de chaque machine et des premiers Rebirths.
local EconomySim = require("../helpers/EconomySim")
local Formulas = require("../../src/shared/domain/Formulas")

local function show(name: string, profile: EconomySim.Profile)
	local result = EconomySim.career(profile, 4, 40 * 3600)
	print(`== {name}`)
	for index, run in result.runs do
		local tiers = {}
		for tier = 2, 7 do
			table.insert(
				tiers,
				if run.tierAt[tier] then string.format("T%d %.0f", tier, run.tierAt[tier] / 60) else `T{tier} -`
			)
		end
		print(
			string.format(
				"Rebirth %d (%s $) : %.0f min de plus, total %.0f min | %s | étage %s",
				index,
				tostring(Formulas.rebirthCost(index - 1)),
				run.seconds / 60,
				run.endedAt / 60,
				table.concat(tiers, ", "),
				if run.upperAt then string.format("%.0f", run.upperAt / 60) else "-"
			)
		)
	end
end

show("Prudent, sans Pet", EconomySim.CAREFUL)
show("Occasionnel : quelques Pets", EconomySim.CASUAL)
show("Réel : Pets, cadeaux, Retour Base", EconomySim.REAL)
